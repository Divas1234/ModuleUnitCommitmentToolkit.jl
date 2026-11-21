# 调度精度模型离线标定
# 生成训练样本并校准衰减、回归和神经网络模型。

"""
		sample_and_train_loss_models(
			loads::load, winds::wind, units::unit, lines::transmissionline,
			DataCentras::data_centra, config_param::config, stroges::Any, scenarios_prob::Float64,
			hydros::hydro, exec_NT::Int64, min_overlap::Int64, max_overlap::Int64,
			NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64
		)

	Calibrate/fit accuracy loss mapping models on-the-fly by sampling different load levels,
	online unit configurations, and overlap sizes, solving subproblems and calculating relative cost error.
	"""

function sample_and_train_loss_models(loads::load, winds::wind, units::unit, lines::transmissionline, DataCentras::data_centra, config_param::config,
        stroges::Any, scenarios_prob::Float64, hydros::hydro, exec_NT::Int64, min_overlap::Int64,
        max_overlap::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64)
    println("\n" * "="^80)
    println("SAMPLING AND CALIBRATING ACCURACY LOSS MAPPING MODEL...")
    println("="^80)

    # Use Task Local Storage to silence solvers during sampling
    # 训练标签必须明确属于 single 或 clustered formulation。默认沿用在线方法；
    # 如需用单机代理训练聚类方法，必须显式设置 PCM_TRAINING_FORMULATION=single，
    # 其缓存签名将与 clustered 标签完全隔离。
    old_clustered_flag = get(ENV, "PCM_USE_CLUSTERED_UC", "false")
    training_formulation = lowercase(strip(get(ENV, "PCM_TRAINING_FORMULATION",
        lowercase(old_clustered_flag) in ("1", "true", "yes", "on") ? "clustered" : "single")))
    training_formulation in ("single", "clustered") ||
        throw(ArgumentError("PCM_TRAINING_FORMULATION must be single or clustered"))
    ENV["PCM_USE_CLUSTERED_UC"] = training_formulation == "clustered" ? "true" : "false"
    task_local_storage(:is_sampling_running, true)

    ml_training = lowercase(get(ENV, "PCM_OVERLAP_MODE", "ml_prediction")) == "ml_prediction"
    training_mode = lowercase(strip(get(ENV, "PCM_TRAINING_MODE", "sweep")))
    training_mode in ("sweep", "fast_max_overlap") ||
        throw(ArgumentError("Unsupported PCM_TRAINING_MODE='$training_mode'"))
    # ML 数据集要求逐时覆盖，但不需要再与人为负荷倍率和边界扰动做笛卡尔积。
    # 使用真实曲线、真实边界，并以短/中/长三档真实 UC 求解确定 To_star。
    load_scales = ml_training ? [1.0] : [0.90, 1.0, 1.10]
    source_time_avail = size(loads.load_curve, 2)
    execution_hours = max(1, parse(Int, get(ENV, "PCM_INTERVALS", "3"))) * exec_NT
    # 训练范围必须与本次声明的执行时域一致，仅额外保留最大交叠所需前瞻。
    total_time_avail = min(source_time_avail, execution_hours + max_overlap)
    latest_start = max(1, total_time_avail - exec_NT - max_overlap + 1)
    start_stride = max(1, parse(Int, get(ENV, "PCM_TRAINING_START_STRIDE", "1")))
    start_time_candidates = if training_mode == "fast_max_overlap"
        # 大规模工程标定：用四个均匀分布的真实时点覆盖本次执行时域，
        # 避免 1080 机组模型执行完整的逐时笛卡尔扫描。
        unique(round.(Int, range(1, latest_start; length = min(4, latest_start))))
    else
        unique(vcat(collect(1:start_stride:latest_start), latest_start))
    end
    overlap_sizes = training_mode == "fast_max_overlap" ? [max_overlap] :
                    ml_training ? unique(sort([min_overlap, (min_overlap + max_overlap) ÷ 2, max_overlap])) : collect(min_overlap:max_overlap)

    X_list = Vector{Float64}[]
    Y_list = Float64[]

    peak_load = maximum(sum(loads.load_curve; dims = 1))
    if peak_load <= 0.0
        peak_load = 1.0
    end
    total_capacity = sum(units.p_max)
    if total_capacity <= 0.0
        total_capacity = 1.0
    end

    sample_count = 0
    try
        for start_time ∈ start_time_candidates
            base_end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)
            base_load_slice = sum(loads.load_curve[:, start_time:base_end_horizon]; dims = 1)[1, :]
            total_wind_cap = sum(winds.p_max)
            base_net_load = zeros(length(base_load_slice))
            for t ∈ eachindex(base_load_slice)
                avg_wind_factor = mean(winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)])
                base_net_load[t] = base_load_slice[t] - total_wind_cap * avg_wind_factor
            end

            for l_scale ∈ load_scales
                target_capacity = max(mean(base_net_load) * l_scale * 1.15, 0.0)
                ref_x_curr = load_following_commitment(units, target_capacity)
                try
                    ref_units = deepcopy(units)
                    ref_loads = deepcopy(loads)
                    ref_loads.load_curve = loads.load_curve[:, start_time:base_end_horizon] .* l_scale
                    ref_winds = deepcopy(winds)
                    ref_winds.scenarios_curve = winds.scenarios_curve[:, start_time:base_end_horizon]
                    ref_results = each_period_scucmodel_modules(exec_NT + max_overlap, NB, NG, ND, NC, ND2, ref_units, ref_loads, ref_winds,
                        lines, DataCentras, config_param, stroges, scenarios_prob, NL, 1, hydros, NH)
                    if ref_results !== nothing && haskey(ref_results, "x₀")
                        ref_x_curr = Float64.(ref_results["x₀"][:, 1] .> 0.5)
                    end
                catch e
                    # Keep the deterministic load-following reference if the
                    # local no-boundary reference solve is unavailable.
                end
                x_perturbations = ml_training ? [Float64.(units.x_0)] : [Float64.(units.x_0), ref_x_curr]

                for x_init ∈ x_perturbations
                    mini_units = deepcopy(units)
                    mini_units.x_0 = x_init

                    end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)

                    mini_loads = deepcopy(loads)
                    mini_loads.load_curve = loads.load_curve[:, start_time:end_horizon] .* l_scale

                    mini_winds = deepcopy(winds)
                    mini_winds.scenarios_curve = winds.scenarios_curve[:, start_time:end_horizon]

                    # 使用最大交叠窗的结果作为精度损失标定基准。
                    total_NT_true = exec_NT + max_overlap

                    # 计算描述当前调度场景的归一化输入特征。
                    total_load_lookahead = sum(mini_loads.load_curve; dims = 1)[1, :]
                    total_wind_cap = sum(winds.p_max)
                    net_load_lookahead = zeros(length(total_load_lookahead))
                    for t ∈ eachindex(total_load_lookahead)
                        avg_wind_factor = mean(winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)])
                        net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
                    end
                    avg_net_load = mean(net_load_lookahead)
                    L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)

                    online_capacity = sum(units.p_max[i] * x_init[i] for i ∈ 1:NG)
                    U_norm = clamp(online_capacity / total_capacity, 0.0, 1.0)
                    X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_init, ref_x_curr)

                    res_true = nothing
                    try
                        res_true = each_period_scucmodel_modules(total_NT_true, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds,
                            lines, DataCentras, config_param, stroges, scenarios_prob, NL, 1, hydros, NH)
                    catch e
                        continue
                    end

                    if res_true === nothing
                        continue
                    end

                    committed_res_true = truncate_and_commit_results(res_true, exec_NT)
                    committed_cost_true = compute_committed_cost(
                        committed_res_true, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, 1, hydros, scenarios_prob)
                    C_true = sum(committed_cost_true)
                    if C_true <= 1.0
                        continue
                    end

                    sample_count += 1

                    #%% Evaluate each candidate overlap size

                    for H ∈ overlap_sizes
                        total_NT_H = exec_NT + H
                        res_H = nothing
                        if H == max_overlap
                            # 最大交叠候选就是上方已求得的精度参考，避免重复构建同一 UC。
                            res_H = res_true
                        else
                            try
                                res_H = each_period_scucmodel_modules(total_NT_H, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines,
                                    DataCentras, config_param, stroges, scenarios_prob, NL, 1, hydros, NH)
                            catch e
                                continue
                            end
                        end

                        if res_H === nothing
                            continue
                        end

                        committed_res_H = truncate_and_commit_results(res_H, exec_NT)
                        committed_cost_H = compute_committed_cost(
                            committed_res_H, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, 1, hydros, scenarios_prob)
                        C_H = sum(committed_cost_H)

                        # Accuracy loss combines cost deviation and commitment
                        # state deviation. Cost-only labels often make small
                        # overlaps look acceptable even when they leave a
                        # different terminal commitment for the next interval.
                        cost_loss = abs(C_H - C_true) / C_true
                        state_loss, switch_loss = commitment_boundary_deviation(units, committed_res_H["x₀"][:, exec_NT], committed_res_true["x₀"][:, exec_NT])
                        loss_val = cost_loss + 0.05 * state_loss + 0.02 * switch_loss

                        # Record sample
                        push!(X_list, [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H)])
                        push!(Y_list, loss_val)
                    end
                end
            end
        end
    finally
        ENV["PCM_USE_CLUSTERED_UC"] = old_clustered_flag
        task_local_storage(:is_sampling_running, false)
    end

    println("Sampling completed. Total valid scenarios solved: $sample_count. Samples collected: $(length(Y_list))")

    models = TrainedLossModels("regression")

    if length(Y_list) < 4
        println("Warning: Too few successful samples collected. Using default preset coefficients.")
        return models
    end

    # 1. Fit Regression Model:
    # ln(Loss) = b0 + b1*L + b2*U + b3*X_delta + b4*X_switch + b5*H
    try
        X_reg = zeros(length(Y_list), 6)
        Y_reg = zeros(length(Y_list))
        for k ∈ eachindex(Y_list)
            X_reg[k, :] = [1.0, X_list[k][1], X_list[k][2], X_list[k][3], X_list[k][4], X_list[k][5]]
            Y_reg[k] = log(max(Y_list[k], 1e-6))
        end
        # Ridge regularized least squares
        X_reg_sq = X_reg' * X_reg + 1e-4 * I
        beta = X_reg_sq \ (X_reg' * Y_reg)
        if beta[6] >= 0.0
            beta[6] = -0.3 # Ensure physical decay constraint
        end
        models.beta = beta
        println("  ✓ Regression model calibrated: ln(Loss) = $(round(beta[1], digits=2)) + $(round(beta[2], digits=2))*L_norm + $(round(beta[3], digits=2))*U_norm + $(round(beta[4], digits=2))*X_delta_norm + $(round(beta[5], digits=2))*X_switch_ratio + $(round(beta[6], digits=2))*H")
    catch e
        println("  ⚠ Regression model calibration failed. Using defaults. Error: $e")
    end

    # 2. Fit Neural Network Model
    try
        X_nn = zeros(length(Y_list), 5)
        Y_nn = zeros(length(Y_list))
        for k ∈ 1:length(Y_list)
            X_nn[k, :] = [X_list[k][1], X_list[k][2], X_list[k][3], X_list[k][4], X_list[k][5] / 12.0]
            Y_nn[k] = Y_list[k]
        end
        W1, b1, W2, b2 = train_neural_network_backprop(X_nn, Y_nn)
        models.W1 = W1
        models.b1 = b1
        models.W2 = W2
        models.b2 = b2
        println("  ✓ Neural Network model calibrated successfully.")
    catch e
        println("  ⚠ Neural network calibration failed. Using defaults.")
    end

    # 3. Fit CART Decision Tree and update OverlapPredictor & cache
    try
        groups = Dict{Tuple{Float64, Float64, Float64, Float64}, Vector{Tuple{Float64, Float64}}}()
        for k ∈ eachindex(Y_list)
            key = (X_list[k][1], X_list[k][2], X_list[k][3], X_list[k][4])
            H_val = X_list[k][5]
            loss_val = Y_list[k]
            push!(get!(groups, key, Tuple{Float64, Float64}[]), (H_val, loss_val))
        end

        rows = NamedTuple[]
        epsilon_target = 0.01
        for (key, h_losses) ∈ groups
            sort!(h_losses; by = x -> x[1])
            best_H = maximum(x[1] for x ∈ h_losses)
            for (H_val, loss_val) ∈ h_losses
                if loss_val <= epsilon_target
                    best_H = H_val
                    break
                end
            end
            push!(rows,
                (
                    U_norm = key[2],
                    T_dwell_rem = 0.0,
                    L_norm = key[1],
                    sigma_load = 10.0,
                    R_wind_max = 0.05,
                    X_delta_norm = key[3],
                    X_switch_ratio = key[4],
                    To_star = Float64(best_H)
                ))
        end

        df_train = DataFrame(rows)
        if nrow(df_train) >= 4 && isdefined(@__MODULE__, :ADAPTIVE_PCM_PROJECT_ROOT)
            cache_root = joinpath(ADAPTIVE_PCM_PROJECT_ROOT, "output", "ml_trainningdata_res")
            expected_meta = OverlapPredictor.EXPECTED_TRAINING_METADATA[]
            if expected_meta !== nothing
                paths = AdaptiveOverlapTrainingCache.cache_paths(cache_root, expected_meta)
                AdaptiveOverlapTrainingCache.save_cached_dataset(cache_root, df_train, expected_meta)
                OverlapPredictor.train_model(paths.dataset_path)
                println("  ✓ CART Decision Tree trained and cached successfully ($(nrow(df_train)) unique samples).")
            end
        end
    catch e
        println("  ⚠ Decision tree cache update failed: $e")
    end

    return models
end
