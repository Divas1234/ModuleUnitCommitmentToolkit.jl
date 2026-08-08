# ============================================================================
# Helper Script: Export Adaptive Overlap Window Statistics
#
# This script calculates per-interval overlap window parameters and exports:
# 1. output/details_schedule_results/adaptive_pcm_simulation_results/overlap_window_statistics.csv
# 2. output/details_schedule_results/adaptive_pcm_simulation_results/overlap_window_summary.txt
# ============================================================================

using Pkg
Pkg.activate("d:/GithubClonefiles/module_unitcommitment/pkg")
using Printf, Statistics, CSV, DataFrames
include("../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../src/read_inputdata_modules/readdatas.jl")
include("period_scuc_modules.jl")
include("adaptive_period_scuc_modules.jl")

function repeat_time_series_to_horizon(curve::AbstractMatrix{<:Real}, target_hours::Int)
    source_hours = size(curve, 2)
    if source_hours == 0
        error("Cannot extend an empty time-series curve.")
    end
    repeat_count = cld(target_hours, source_hours)
    extended_curve = repeat(Matrix{Float64}(curve), 1, repeat_count)
    return extended_curve[:, 1:target_hours]
end

function overlap_limiting_factor(T_steady::Int, T_unit::Int, T_ramp::Int)
    raw_max = max(T_steady, T_unit, T_ramp)
    factors = String[]
    if T_steady == raw_max
        push!(factors, "steady")
    end
    if T_unit == raw_max
        push!(factors, "unit_dwell")
    end
    if T_ramp == raw_max
        push!(factors, "ramp")
    end
    return join(factors, "+")
end

function export_overlap_statistics()
    println("\n" * "="^80)
    println("EXPORTING ADAPTIVE OVERLAP WINDOW STATISTICS")
    println("="^80)

    # 1. Read input data
    println("\nReading project input data...")
    ENV["MODULE_UC_DATA_FILE"] = "d:/GithubClonefiles/module_unitcommitment/data/data_118.xlsx"
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
    global config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, scenarios_prob, winds
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )
    config_param.is_NetWorkCon = 0
    winds, NW = genscenario(WindsFreqParam, 0)
    winds.scenarios_nums = 1
    winds.scenarios_curve = winds.scenarios_curve[1:1, :]

    exec_NT = 24
    N_sets = 7
    required_horizon = exec_NT * N_sets
    alpha = 0.25
    epsilon = 0.10
    min_overlap = 2
    max_overlap = 12
    slow_threshold = 4.0
    steady_state_mode = "regression"

    if size(loads.load_curve, 2) < required_horizon
        loads.load_curve = repeat_time_series_to_horizon(loads.load_curve, required_horizon)
    end
    if size(winds.scenarios_curve, 2) < required_horizon
        winds.scenarios_curve = repeat_time_series_to_horizon(winds.scenarios_curve, required_horizon)
    end
    scenarios_prob = 1.0

    println("  Load curve horizon used for statistics: $(size(loads.load_curve, 2)) h")
    println("  Wind scenario horizon used for statistics: $(size(winds.scenarios_curve, 2)) h")
    println("  Steady-state overlap mode: $steady_state_mode")

    # Calibration is pre-run preparation. Keep it separate from per-subproblem
    # rolling-horizon solve times, matching the benchmark timing convention.
    calibration_start = time()
    trained_models = TrainedLossModels(steady_state_mode)
    if steady_state_mode != "decay" && steady_state_mode != "ml_prediction"
        trained_models = sample_and_train_loss_models(
            loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob,
            hydros, exec_NT, min_overlap, max_overlap, NB, NG, ND, NC, ND2, NL, NH
        )
    end
    calibration_time_excluded = time() - calibration_start
    println(@sprintf("  Calibration / training time excluded from subproblem solve times: %.2f s", calibration_time_excluded))

    slow_units, fast_units, T_unit_req = classify_generator_speed(units; slow_threshold = slow_threshold)
    T_steady_req = calculate_boundary_sensitivity_decay(alpha, epsilon)

    df_stats = DataFrame(
        Interval_ID = Int64[],
        Start_Hour = Int64[],
        Execution_Window_h = Int64[],
        Steady_State_Overlap_h = Int64[],
        Unit_Dwell_Overlap_h = Int64[],
        Ramp_Event_Detected = Bool[],
        Ramp_Overlap_h = Int64[],
        Raw_Max_Overlap_h = Int64[],
        Limiting_Factor = String[],
        Final_Adaptive_Overlap_h = Int64[],
        Total_Solved_Horizon_h = Int64[],
        Subproblem_SolveTime_sec = Float64[],
        Optimization_Status = String[]
    )

    pre_results = nothing

    for k in 1:N_sets
        start_time = (k - 1) * exec_NT + 1
        # Local reference commitment for T_steady:
        # solve the same interval while ignoring inherited boundary conditions.
        # The first-period commitment is a local economic benchmark; T_steady
        # then measures how far the inherited rolling boundary is from this
        # benchmark and how much overlap is needed for that influence to decay.
        x_ref_curr = solve_local_reference_commitment(
            loads, winds, units, lines, DataCentras, config_param, stroges,
            scenarios_prob, hydros, start_time, exec_NT, max_overlap,
            NB, NG, ND, NC, ND2, NL, NH, k
        )
        T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
            loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap,
            pre_results, k, steady_state_mode, trained_models, x_ref_curr
        )
        total_NT = exec_NT + T_overlap
        raw_max = max(T_steady, T_unit, T_ramp)
        limiting_factor = overlap_limiting_factor(T_steady, T_unit, T_ramp)

        mini_units, mini_loads, mini_winds = update_adaptive_boundary_conditions(
            k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results
        )

        solve_start = time()
        res = each_period_scucmodel_modules(
            total_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds,
            lines, DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH
        )
        solve_time = time() - solve_start
        status = res === nothing ? "FAILED" : "OK"
        if res === nothing
            error("Adaptive subproblem failed at interval $k; overlap statistics are incomplete.")
        end
        pre_results = res

        push!(df_stats, (
            k, start_time, exec_NT, T_steady, T_unit, is_ramp, T_ramp, raw_max,
            limiting_factor, T_overlap, total_NT, solve_time, status
        ))
    end

    # Define output file paths
    outdir = joinpath(pwd(), "output", "details_schedule_results", "adaptive_pcm_simulation_results")
    mkpath(outdir)

    csv_path = joinpath(outdir, "overlap_window_statistics.csv")
    txt_path = joinpath(outdir, "overlap_window_summary.txt")

    # Export CSV
    CSV.write(csv_path, df_stats)
    println("  ✓ Per-interval overlap statistics exported to CSV: $csv_path")

    # Export Human-Readable TXT Summary
    open(txt_path, "w") do io
        println(io, "="^80)
        println(io, "ADAPTIVE OVERLAP WINDOW STATISTICAL REPORT")
        println(io, "="^80)
        println(io, @sprintf("Total Scheduling Intervals : %d", N_sets))
        println(io, @sprintf("Execution Window Per Set   : %d hours", exec_NT))
        println(io, @sprintf("Decay Factor (alpha)       : %.2f", alpha))
        println(io, @sprintf("Decay Threshold (epsilon)  : %.2f", epsilon))
        println(io, @sprintf("Calibration Time Excluded  : %.2f seconds", calibration_time_excluded))
        println(io, @sprintf("Slow-Start Generators      : %d units (dwell req: %dh)", length(slow_units), T_unit_req))
        println(io, @sprintf("Steady-State Decay Window  : %d hours", T_steady_req))
        println(io, @sprintf("Average Overlap Window     : %.2f hours", mean(df_stats.Final_Adaptive_Overlap_h)))
        println(io, @sprintf("Max Overlap Window         : %d hours", maximum(df_stats.Final_Adaptive_Overlap_h)))
        println(io, @sprintf("Min Overlap Window         : %d hours", minimum(df_stats.Final_Adaptive_Overlap_h)))
        println(io, @sprintf("Total Subproblem Solve Time: %.2f seconds", sum(df_stats.Subproblem_SolveTime_sec)))
        println(io, "-"^80)
        println(io, "PER-INTERVAL OVERLAP WINDOW BREAKDOWN:")
        println(io, "-"^80)
        for row in eachrow(df_stats)
            println(io, @sprintf(
                "Interval %d | Start Hour %3d | Exec: %2dh | Steady: %2dh | UnitDwell: %2dh | Ramp: %5s (%2dh) | Limiting: %-16s | Final Overlap: %2dh | Total Solved: %2dh | Solve: %.2fs",
                row.Interval_ID, row.Start_Hour, row.Execution_Window_h, row.Steady_State_Overlap_h,
                row.Unit_Dwell_Overlap_h, string(row.Ramp_Event_Detected), row.Ramp_Overlap_h,
                row.Limiting_Factor, row.Final_Adaptive_Overlap_h, row.Total_Solved_Horizon_h,
                row.Subproblem_SolveTime_sec
            ))
        end
        println(io, "="^80)
    end
    println("  ✓ Human-readable summary report exported to TXT: $txt_path")
    println("="^80 * "\n")

    # Also display dataframe in console
    println("\nPer-Interval Overlap Summary Dataframe:")
    println(df_stats)
end

export_overlap_statistics()
