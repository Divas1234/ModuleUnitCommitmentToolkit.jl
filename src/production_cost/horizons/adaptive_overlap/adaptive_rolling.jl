"""
    src/production_cost/horizons/adaptive_overlap/adaptive_rolling.jl

Unified adaptive-overlap rolling PCM engine for both `SingleUnitFormulation`
(`adaptive_overlap`) and `ClusteredFormulation` (`clustered_overlap`).
"""

using CSV
using DataFrames
using Printf
using Random
using Statistics

function _repeat_time_series_to_horizon(curve::AbstractMatrix{<:Real}, target_hours::Int)
    source_hours = size(curve, 2)
    source_hours > 0 || error("Cannot extend an empty time-series curve.")
    repeat_count = cld(target_hours, source_hours)
    return repeat(Matrix{Float64}(curve), 1, repeat_count)[:, 1:target_hours]
end

function _overlap_limiting_factor(T_steady::Int, T_unit::Int, T_ramp::Int)
    raw_max = max(T_steady, T_unit, T_ramp)
    factors = String[]
    T_steady == raw_max && push!(factors, "steady")
    T_unit == raw_max && push!(factors, "unit_dwell")
    T_ramp == raw_max && push!(factors, "ramp")
    return join(factors, "+")
end

function execute_adaptive_overlap_pcm(
    formulation::AbstractPCMFormulation,
    policy::AdaptiveOverlapPolicy;
    cfg::PCMConfig = PCMConfig(),
    label::String = "",
)
    t_start_wall = time()
    is_clustered = formulation isa ClusteredFormulation
    formulation_sym = is_clustered ? :clustered : :standard
    method_label = isempty(label) ? (is_clustered ? "clustered_overlap" : "adaptive_overlap") : label
    perf = cfg.performance_mode

    project_root = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
    default_data = joinpath(project_root, "data", "data_118.xlsx")
    data_file = cfg.data_file !== nothing ? cfg.data_file :
        (isfile(default_data) ? default_data : nothing)

    env_overrides = Pair{String, String}[
        "PCM_USE_CLUSTERED_UC" => (is_clustered ? "true" : "false"),
        "PCM_LOAD_PROFILE" => cfg.load_profile,
        "PCM_WINDOW_HOURS" => string(policy.window_hours),
        "PCM_INTERVALS" => string(policy.intervals),
        "PCM_NETWORK_CONSTRAINTS" => (cfg.network_constraints ? "1" : "0"),
        "PCM_RANDOM_SEED" => string(cfg.random_seed),
    ]
    data_file !== nothing && push!(env_overrides, "MODULE_UC_DATA_FILE" => data_file)
    haskey(ENV, "PCM_OVERLAP_MODE") || push!(env_overrides, "PCM_OVERLAP_MODE" => policy.overlap_mode)
    if perf == "fast"
        haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "load_following")
        haskey(ENV, "PCM_MIP_GAP") || push!(env_overrides, "PCM_MIP_GAP" => "0.03")
        if is_clustered
            haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS") || push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "5")
            haskey(ENV, "PCM_CLUSTER_REFERENCE_REPAIR") || push!(env_overrides, "PCM_CLUSTER_REFERENCE_REPAIR" => "false")
        end
    else
        haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "economic_solve")
        if is_clustered && !haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS")
            push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "9")
        end
    end
    if is_clustered && !haskey(ENV, "PCM_TRAINING_FORMULATION")
        push!(env_overrides, "PCM_TRAINING_FORMULATION" => "clustered")
    end

    return withenv(env_overrides...) do
        Random.seed!(cfg.random_seed)
        d = load_pcm_excel_data(; data_file = data_file, network_constraints = cfg.network_constraints)
        apply_pcm_load_profile!(d.loads, cfg.load_profile)

        winds, NW = genscenario(d.WindsFreqParam, 0; scenario_limit = 1)
        scenarios_prob = 1.0

        exec_NT = policy.window_hours
        n_intervals = policy.intervals
        min_overlap = 2
        max_overlap = max(min_overlap, policy.max_overlap_hours)
        required_horizon = exec_NT * n_intervals + max_overlap
        alpha = 0.25
        epsilon = 0.10
        slow_threshold = 4.0
        training_mode = lowercase(strip(get(ENV, "PCM_TRAINING_MODE", "sweep")))
        steady_state_mode = lowercase(strip(get(ENV, "PCM_OVERLAP_MODE", policy.overlap_mode)))

        if size(d.loads.load_curve, 2) < required_horizon
            d.loads.load_curve = _repeat_time_series_to_horizon(d.loads.load_curve, required_horizon)
        end
        if size(winds.scenarios_curve, 2) < required_horizon
            winds.scenarios_curve = _repeat_time_series_to_horizon(winds.scenarios_curve, required_horizon)
        end

        cache_root = joinpath(project_root, "output", "ml_trainningdata_res")
        solver_name = try
            pcm_solver_name()
        catch
            get(ENV, "PCM_SOLVER", "unknown")
        end
        training_metadata = AdaptiveOverlapTrainingCache.build_case_metadata(;
            input_file = abspath(get(ENV, "MODULE_UC_DATA_FILE", "")),
            load_profile = cfg.load_profile,
            solver = solver_name,
            network_constraints = string(d.config_param.is_NetWorkCon),
            window_hours = exec_NT,
            intervals = n_intervals,
            min_overlap = min_overlap,
            max_overlap = max_overlap,
            dimensions = Dict("NB" => d.NB, "NG" => d.NG, "ND" => d.ND, "NL" => d.NL, "NW" => NW, "NH" => d.NH),
            load_curve = d.loads.load_curve,
            wind_curve = winds.scenarios_curve,
            training_mode = training_mode,
            formulation = is_clustered ? "clustered" : "single",
            sampling_version = "hourly-v5-strict-boundary-unknown-initial-candidate3",
        )
        cached_training_data = AdaptiveOverlapTrainingCache.load_cached_dataset(
            cache_root;
            expected_metadata = training_metadata,
            min_samples = 4,
        )
        OverlapPredictor.configure_training_cache!(cache_root, training_metadata)

        calibration_start = time()
        trained_models = TrainedLossModels(steady_state_mode)
        if steady_state_mode != "decay" && steady_state_mode != "ml_prediction"
            trained_models = sample_and_train_loss_models(
                d.loads, winds, d.units, d.lines, d.DataCentras, d.config_param, d.stroges, scenarios_prob,
                d.hydros, exec_NT, min_overlap, max_overlap, d.NB, d.NG, d.ND, d.NC, d.ND2, d.NL, d.NH,
            )
        elseif steady_state_mode == "ml_prediction" && cached_training_data === nothing
            trained_models = sample_and_train_loss_models(
                d.loads, winds, d.units, d.lines, d.DataCentras, d.config_param, d.stroges, scenarios_prob,
                d.hydros, exec_NT, min_overlap, max_overlap, d.NB, d.NG, d.ND, d.NC, d.ND2, d.NL, d.NH,
            )
            cached_training_data = AdaptiveOverlapTrainingCache.load_cached_dataset(
                cache_root;
                expected_metadata = training_metadata,
                min_samples = 4,
            )
            cached_training_data === nothing && error(
                "ML steady-state overlap training did not produce a compatible cache; fallback prediction is disabled.",
            )
        end
        calibration_time = time() - calibration_start
        reset_pcm_cluster_stats!()

        slow_units, _, T_unit_req = classify_generator_speed(d.units; slow_threshold = slow_threshold)
        T_steady_req = calculate_boundary_sensitivity_decay(alpha, epsilon)

        df_stats = DataFrame(;
            Interval_ID = Int64[], Start_Hour = Int64[], Execution_Window_h = Int64[],
            Steady_State_Overlap_h = Int64[], Unit_Dwell_Overlap_h = Int64[],
            Ramp_Event_Detected = Bool[], Ramp_Overlap_h = Int64[], Raw_Max_Overlap_h = Int64[],
            Limiting_Factor = String[], Final_Adaptive_Overlap_h = Int64[], Total_Solved_Horizon_h = Int64[],
            Overlap_SelectionTime_sec = Float64[], Subproblem_SolveTime_sec = Float64[],
            Reference_Cost_Gap_pct = Float64[], Reference_Repair_Applied = Bool[],
            Optimization_Status = String[],
        )

        pre_results = nothing
        total_scheduled_cost = zeros(n_intervals + 1, 7)

        for k in 1:n_intervals
            start_time = (k - 1) * exec_NT + 1
            select_start = time()
            reference_mode = lowercase(get(ENV, "PCM_OVERLAP_REFERENCE_MODE", "economic_solve"))
            local_reference = if reference_mode == "load_following"
                (
                    commitment = load_following_commitment(
                        d.units,
                        maximum(sum(d.loads.load_curve[:, start_time:(start_time + exec_NT - 1)]; dims = 1)),
                    ),
                    results = nothing,
                )
            else
                solve_local_reference_commitment(
                    d.loads, winds, d.units, d.lines, d.DataCentras, d.config_param, d.stroges, scenarios_prob,
                    d.hydros, start_time, exec_NT, max_overlap, d.NB, d.NG, d.ND, d.NC, d.ND2, d.NL, d.NH, k;
                    return_results = is_clustered,
                )
            end
            x_ref_curr = local_reference isa NamedTuple ? local_reference.commitment : local_reference
            ref_results = local_reference isa NamedTuple ? local_reference.results : nothing

            T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
                d.loads, winds, d.units, start_time, exec_NT, alpha, epsilon, min_overlap,
                max_overlap, pre_results, k, steady_state_mode, trained_models, x_ref_curr,
            )
            select_time = time() - select_start
            total_NT = exec_NT + T_overlap
            raw_max = max(T_steady, T_unit, T_ramp)
            limiting_factor = _overlap_limiting_factor(T_steady, T_unit, T_ramp)

            mini_units, mini_loads, mini_winds = update_adaptive_boundary_conditions(
                k, d.NG, exec_NT, total_NT, start_time, d.units, d.loads, winds, pre_results,
            )

            solve_start = time()
            res = each_period_scucmodel_modules(
                total_NT, d.NB, d.NG, d.ND, d.NC, d.ND2, mini_units, mini_loads, mini_winds, d.lines,
                d.DataCentras, d.config_param, d.stroges, scenarios_prob, d.NL, k, d.hydros, d.NH;
                formulation = formulation_sym,
            )
            solve_time = time() - solve_start
            res === nothing && error("Adaptive overlap subproblem ($method_label) failed at interval $k.")

            reference_gap_pct = 0.0
            reference_repair = false
            if is_clustered && ref_results !== nothing
                clustered_committed = truncate_and_commit_results(res, exec_NT)
                reference_committed = truncate_and_commit_results(ref_results, exec_NT)
                clustered_cost = compute_committed_cost(
                    clustered_committed, exec_NT, mini_units, mini_loads, mini_winds, d.lines,
                    d.DataCentras, d.config_param, k, d.hydros, scenarios_prob,
                )[1]
                reference_cost = compute_committed_cost(
                    reference_committed, exec_NT, mini_units, mini_loads, mini_winds, d.lines,
                    d.DataCentras, d.config_param, k, d.hydros, scenarios_prob,
                )[1]
                reference_gap_pct = 100.0 * (clustered_cost / max(reference_cost, 1.0) - 1.0)
                repair_tol = parse(Float64, get(ENV, "PCM_CLUSTER_REFERENCE_GAP_TOL", "0.01"))
                repair_enabled = lowercase(get(ENV, "PCM_CLUSTER_REFERENCE_REPAIR", "true")) in ("1", "true", "yes", "on")
                if repair_enabled && abs(reference_gap_pct) > 100.0 * repair_tol
                    repair_start = time()
                    physical_repair = each_period_scucmodel_modules(
                        total_NT, d.NB, d.NG, d.ND, d.NC, d.ND2, mini_units, mini_loads, mini_winds, d.lines,
                        d.DataCentras, d.config_param, d.stroges, scenarios_prob, d.NL, k, d.hydros, d.NH;
                        formulation = :standard,
                    )
                    solve_time += time() - repair_start
                    physical_repair === nothing && error("Physical inherited-boundary repair failed at interval $k.")
                    res = physical_repair
                    reference_repair = true
                end
            end

            committed_results = truncate_and_commit_results(res, exec_NT)
            total_scheduled_cost[k, :] = compute_committed_cost(
                committed_results, exec_NT, mini_units, mini_loads, mini_winds, d.lines,
                d.DataCentras, d.config_param, k, d.hydros, scenarios_prob,
            )
            pre_results = res

            push!(df_stats, (
                k, start_time, exec_NT, T_steady, T_unit, is_ramp, T_ramp, raw_max, limiting_factor,
                T_overlap, total_NT, select_time, solve_time, reference_gap_pct, reference_repair, "OK",
            ))
        end

        total_scheduled_cost[end, :] = sum(total_scheduled_cost[1:(end - 1), :]; dims = 1)
        stats_snap = snapshot_pcm_cluster_stats()
        preprocess_time = is_clustered ? stats_snap.preprocess_time_sec : 0.0
        sim_time = max(0.0, sum(df_stats.Overlap_SelectionTime_sec) + sum(df_stats.Subproblem_SolveTime_sec) - preprocess_time)

        out_folder = is_clustered ? "clustered_adaptive_pcm_simulation_results" : "adaptive_pcm_simulation_results"
        output_root = let out_env = strip(get(ENV, "MODULE_UC_OUTPUT_DIR", ""))
            isempty(out_env) ? joinpath(project_root, "output") : out_env
        end
        outdir = joinpath(output_root, "details_schedule_results", out_folder)
        mkpath(outdir)
        CSV.write(joinpath(outdir, "total_scheduled_results.csv"), DataFrame(total_scheduled_cost, :auto); header = false)
        CSV.write(joinpath(outdir, "overlap_window_statistics.csv"), df_stats)
        open(joinpath(outdir, "overlap_window_summary.txt"), "w") do io
            println(io, "ADAPTIVE OVERLAP WINDOW STATISTICAL REPORT ($method_label)")
            println(io, @sprintf("Intervals: %d | Exec Window: %dh | Avg Overlap: %.2fh | Total Solve: %.2fs",
                n_intervals, exec_NT, mean(df_stats.Final_Adaptive_Overlap_h), sum(df_stats.Subproblem_SolveTime_sec)))
        end

        elapsed = time() - t_start_wall
        return (
            method = method_label,
            formulation = formulation_sym,
            overlap = true,
            status = "OPTIMAL",
            total_cost = Float64(total_scheduled_cost[end, 1]),
            runtime_seconds = elapsed,
            simulation_time_sec = sim_time,
            offline_training_time_sec = calibration_time,
            offline_preprocess_time_sec = preprocess_time,
            intervals = n_intervals,
            window_hours = exec_NT,
            total_hours = exec_NT * n_intervals,
            physical_units = d.NG,
            units = d.units,
            overlap_stats = df_stats,
            scheduled_costs = total_scheduled_cost,
            slow_unit_count = length(slow_units),
            steady_state_decay_h = T_steady_req,
            unit_dwell_h = T_unit_req,
        )
    end
end
