# PCM 自适应交叠窗决策策略
# 根据边界误差、净负荷爬坡和预测损失确定交叠时长。

function adaptive_overlap_verbose()
    lowercase(get(ENV, "PCM_OVERLAP_VERBOSE", "1")) in ("1", "true", "yes", "on")
end

"""
    compute_steady_state_overlap_mapping(
    	loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64,
    	epsilon::Float64, min_overlap::Int64, max_overlap::Int64, x_0_curr::Vector{Float64},
    	mode::String, trained_models
    )

Quantitatively determine steady-state overlap window size steady_state_overlap_h based on
the predicted solving accuracy loss under specific load level and startup/shutdown plans.
"""
function compute_steady_state_overlap_mapping(
        loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64, epsilon::Float64, min_overlap::Int64, max_overlap::Int64,
        x_0_curr::Vector{Float64}, mode::String = "regression", trained_models = nothing, x_ref_curr::Union{Nothing, Vector{Float64}} = nothing)
    # Estimate system characteristics
    total_time_avail = size(loads.load_curve, 2)
    end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)

    # Peak load for normalization
    peak_load = maximum(sum(loads.load_curve; dims = 1))
    if peak_load <= 0.0
        peak_load = 1.0
    end

    # Total generation capacity for normalization
    total_capacity = sum(units.p_max)
    if total_capacity <= 0.0
        total_capacity = 1.0
    end

    # Average net load in the lookahead horizon
    total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
    total_wind_cap = sum(winds.p_max)
    net_load_lookahead = zeros(length(total_load_lookahead))
    for t ∈ eachindex(total_load_lookahead)
        scen_curves = winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)]
        avg_wind_factor = mean(scen_curves)
        net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
    end
    avg_net_load = mean(net_load_lookahead)
    L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)

    # Online generator capacity at start of interval
    NG = length(units.index)
    online_capacity = sum(units.p_max[i] * x_0_curr[i] for i ∈ 1:NG)
    U_norm = clamp(online_capacity / total_capacity, 0.0, 1.0)

    X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_0_curr, x_ref_curr)
    epsilon_state = clamp(epsilon / 2.0, 0.01, 0.08)
    state_decay_floor = commitment_deviation_decay_overlap(X_delta_norm, X_switch_ratio, epsilon_state, min_overlap, max_overlap)

    models = (trained_models !== nothing) ? trained_models : TrainedLossModels(mode)

    # Find the smallest overlap window H such that predicted accuracy loss <= epsilon
    model_selected_H = max_overlap
    for H ∈ min_overlap:max_overlap
        loss = 0.0
        if mode == "regression"
            beta = models.beta
            if length(beta) >= 6
                loss = exp(beta[1] + beta[2] * L_norm + beta[3] * U_norm + beta[4] * X_delta_norm + beta[5] * X_switch_ratio + beta[6] * H)
            else
                loss = exp(beta[1] + beta[2] * L_norm + beta[3] * U_norm + beta[4] * H)
            end
        elseif mode == "neural_network"
            loss = predict_accuracy_loss_neural_network_custom(L_norm, U_norm, X_delta_norm, X_switch_ratio, H, models)
        else
            return calculate_boundary_sensitivity_decay(0.25, epsilon)
        end

        if loss <= epsilon
            model_selected_H = H
            break
        end
    end

    return max(model_selected_H, state_decay_floor)
end

"""
    compute_adaptive_overlap_window(
    	loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64,
    	alpha::Float64, epsilon::Float64, min_overlap::Int64, max_overlap::Int64,
    	pre_scheduling_results, interval_scheduling_id, steady_state_mode, trained_models
    )

Compute composite adaptive overlapping window size considering:

 1. Steady-state boundary sensitivity decay / Dynamic Accuracy Loss Mapping
 2. Slow-start generator dwell requirements (dynamic remaining dwell time tracking)
 3. Strong Net Load ramping & multi-scenario uncertainty coverage
"""
function compute_adaptive_overlap_window(
        loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64, alpha::Float64 = 0.25, epsilon::Float64 = 0.05,
        min_overlap::Int64 = 2, max_overlap::Int64 = 12, pre_scheduling_results = nothing, interval_scheduling_id = 1,
        steady_state_mode::String = "decay", trained_models = nothing, x_ref_curr::Union{Nothing, Vector{Float64}} = nothing)
    NG = length(units.index)

    # Extract dynamic remaining dwell times of units at start of current interval
    t_0_curr = deepcopy(units.t_0)
    t_1_curr = deepcopy(units.t_1)
    x_0_curr = deepcopy(units.x_0)

    if interval_scheduling_id != 1 && pre_scheduling_results !== nothing
        # Get remaining up/down times from pre_scheduling_results committed window
        u_sub = pre_scheduling_results["u₀"][:, 1:exec_NT]
        v_sub = pre_scheduling_results["v₀"][:, 1:exec_NT]
        res_up, res_down = get_generators_upoff_durations(units, u_sub, v_sub, NG)
        t_0_curr = res_up[:, 1]
        t_1_curr = res_down[:, 1]
        x_0_curr = pre_scheduling_results["x₀"][:, exec_NT]
    end

    if startswith(steady_state_mode, "fixed_")
        fixed_val = parse(Int, split(steady_state_mode, "_")[2])
        T_overlap = fixed_val
        # Clamping at boundary for last interval
        if interval_scheduling_id == 7
            total_time_avail = size(loads.load_curve, 2)
            remaining_time = total_time_avail - (start_time + exec_NT - 1)
            T_overlap = min(T_overlap, remaining_time)
            T_overlap = max(0, T_overlap)
        end
        adaptive_overlap_verbose() && println("[AdaptiveOverlap] interval=$(interval_scheduling_id) criterion=fixed steady=$(fixed_val) final=$(T_overlap)")
        return T_overlap, false, fixed_val, 0, 0
    end

    if steady_state_mode == "ml_prediction"
        # Extract system-independent features
        total_capacity = sum(units.p_max)
        U_norm = total_capacity > 0.0 ? sum(x_0_curr .* units.p_max) / total_capacity : 0.0
        online_remaining = [x_0_curr[i] > 0.5 ? max(0.0, t_0_curr[i]) : 0.0 for i ∈ 1:NG]
        offline_remaining = [x_0_curr[i] <= 0.5 ? max(0.0, t_1_curr[i]) : 0.0 for i ∈ 1:NG]
        T_dwell_rem = max(0.0, maximum(online_remaining), maximum(offline_remaining))
        X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_0_curr, x_ref_curr)

        end_horizon = min(size(loads.load_curve, 2), start_time + exec_NT + max_overlap - 1)
        total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
        total_wind_cap = sum(winds.p_max)

        net_load_lookahead = zeros(length(total_load_lookahead))
        for t ∈ eachindex(total_load_lookahead)
            scen_curves = winds.scenarios_curve[:, min(size(loads.load_curve, 2), start_time + t - 1)]
            avg_wind_factor = mean(scen_curves)
            net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
        end

        avg_net_load = mean(net_load_lookahead)
        peak_load = maximum(sum(loads.load_curve; dims = 1))
        if peak_load <= 0.0
            peak_load = 1.0
        end
        L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)
        sigma_load = std(total_load_lookahead)

        wind_ramps = [abs(winds.scenarios_curve[s, t + 1] - winds.scenarios_curve[s, t])
                      for s ∈ 1:winds.scenarios_nums, t ∈ start_time:(end_horizon - 1)]
        R_wind_max = isempty(wind_ramps) ? 0.0 : maximum(wind_ramps)

        feat_vec = [U_norm, T_dwell_rem, L_norm, sigma_load, R_wind_max, X_delta_norm, X_switch_ratio]

        T_o_pred = OverlapPredictor.predict_overlap(feat_vec; min_overlap = min_overlap, max_overlap = max_overlap)

        # The overlap window at the END of the execution window provides lookahead
        # for steady-state accuracy decay (T_ml) and net-load ramping events (T_ramp).
        # Dynamic remaining dwell time at start of interval (T_dwell_rem) is enforced
        # at the BEGINNING of the subproblem (hours 1..T_dwell_rem <= 10) and is
        # completed within the 24h execution window, so it does not force the end overlap.
        T_unit = Int64(ceil(T_dwell_rem))
        is_ramp, T_ramp = detect_ramp_events_and_overlap(loads, winds, start_time, exec_NT, max_overlap)
        T_overlap = clamp(max(T_o_pred, T_ramp), min_overlap, max_overlap)

        total_time_avail = size(loads.load_curve, 2)
        max_possible_overlap = total_time_avail - (start_time + exec_NT - 1)
        T_overlap = max(0, min(T_overlap, max_possible_overlap))

        if adaptive_overlap_verbose()
            println("[AdaptiveOverlap] interval=$(interval_scheduling_id) start=$(start_time) mode=ml_prediction")
            println("  boundary criterion: U_norm=$(round(U_norm; digits=4)), T_dwell_rem=$(round(T_dwell_rem; digits=2)), X_delta_norm=$(round(X_delta_norm; digits=4)), X_switch_ratio=$(round(X_switch_ratio; digits=4))")
            println("  steady-state criterion: L_norm=$(round(L_norm; digits=4)), sigma_load=$(round(sigma_load; digits=4)), R_wind_max=$(round(R_wind_max; digits=4)), T_ml=$(T_o_pred)")
            println("  physical criteria: T_unit_start=$(T_unit), ramp_event=$(is_ramp), T_ramp=$(T_ramp)")
            println("  final criterion: max(T_ml=$(T_o_pred), T_ramp=$(T_ramp))=$(max(T_o_pred, T_ramp)); clamped_final=$(T_overlap), solved_horizon=$(exec_NT + T_overlap)")
        end

        return T_overlap, is_ramp, T_o_pred, T_unit, T_ramp
    end

    # 1. Steady-state overlap window.
    #
    # For "regression" and "neural_network" modes, T_steady is calculated by
    # compute_steady_state_overlap_mapping(...). That function predicts the
    # accuracy loss associated with candidate overlap lengths H and selects
    # the smallest H whose predicted loss is <= epsilon.
    #
    # This branch is intentionally separate from "ml_prediction": the CART
    # predictor branch above directly returns an overlap value and therefore
    # does not exercise the T_steady/T_unit/T_ramp aggregation used here.
    T_steady = 0
    if steady_state_mode == "decay"
        T_steady = calculate_boundary_sensitivity_decay(alpha, epsilon)
    else
        T_steady = compute_steady_state_overlap_mapping(
            loads, winds, units, start_time, exec_NT, epsilon, min_overlap, max_overlap, x_0_curr, steady_state_mode, trained_models, x_ref_curr)
    end

    # 2. Dynamic thermal-unit dwell requirement.
    #
    # T_unit must describe the *remaining* boundary restriction at the start
    # of the current subproblem, not the static maximum minimum-up/down time
    # of all slow units. For currently online thermal units, t_0_curr is the
    # remaining minimum online time before they may be shut down. For currently
    # offline thermal units, t_1_curr is the remaining minimum offline time
    # before they may be started up. These values are already measured at the
    # current interval boundary, so do not subtract exec_NT again here.
    online_remaining = [x_0_curr[i] > 0.5 ? max(0.0, t_0_curr[i]) : 0.0 for i ∈ 1:NG]
    offline_remaining = [x_0_curr[i] <= 0.5 ? max(0.0, t_1_curr[i]) : 0.0 for i ∈ 1:NG]
    T_dwell_rem = max(0.0, maximum(online_remaining), maximum(offline_remaining))
    T_unit = Int64(ceil(T_dwell_rem))

    #STUB:  3. Net Load ramping & uncertainty event detection (净负荷视角)
    is_ramp, T_ramp = detect_ramp_events_and_overlap(loads, winds, start_time, exec_NT, max_overlap)

    # Composite overlap calculation
    T_overlap_raw = max(T_steady, T_ramp)
    T_overlap = clamp(T_overlap_raw, min_overlap, max_overlap)

    # Ensure total window does not exceed remaining simulation time
    total_time_avail = size(loads.load_curve, 2)
    max_possible_overlap = total_time_avail - (start_time + exec_NT - 1)
    T_overlap = max(0, min(T_overlap, max_possible_overlap))

    if adaptive_overlap_verbose()
        println("[AdaptiveOverlap] interval=$(interval_scheduling_id) start=$(start_time) mode=$(steady_state_mode)")
        println("  steady-state criterion: T_steady=$(T_steady), epsilon=$(epsilon), alpha=$(alpha)")
        println("  physical criteria: T_unit_start=$(T_unit), ramp_event=$(is_ramp), T_ramp=$(T_ramp)")
        println("  final criterion: max(T_steady=$(T_steady), T_ramp=$(T_ramp))=$(T_overlap_raw); clamped_final=$(T_overlap), solved_horizon=$(exec_NT + T_overlap)")
    end

    return T_overlap, is_ramp, T_steady, T_unit, T_ramp
end
