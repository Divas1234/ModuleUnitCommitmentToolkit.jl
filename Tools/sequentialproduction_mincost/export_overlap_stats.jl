# ============================================================================
# Helper Script: Export Adaptive Overlap Window Statistics
#
# This script calculates per-interval overlap window parameters and exports:
# 1. output/details_schedule_results/adaptive_pcm_simulation_results/overlap_window_statistics.csv
# 2. output/details_schedule_results/adaptive_pcm_simulation_results/overlap_window_summary.txt
# ============================================================================

using Printf, Statistics, CSV, DataFrames
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"))
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"))
include("adaptive_period_scuc_modules.jl")

function export_overlap_statistics()
    println("\n" * "="^80)
    println("EXPORTING ADAPTIVE OVERLAP WINDOW STATISTICS")
    println("="^80)

    # 1. Read input data
    println("\nReading project input data...")
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )
    winds, NW = genscenario(WindsFreqParam, 0)

    exec_NT = 24
    N_sets = 7
    alpha = 0.25
    epsilon = 0.05
    min_overlap = 2
    max_overlap = 12
    slow_threshold = 4.0

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
        Final_Adaptive_Overlap_h = Int64[],
        Total_Solved_Horizon_h = Int64[]
    )

    for k in 1:N_sets
        start_time = (k - 1) * exec_NT + 1
        T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
            loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap
        )
        total_NT = exec_NT + T_overlap
        raw_max = max(T_steady, T_unit, T_ramp)

        push!(df_stats, (
            k, start_time, exec_NT, T_steady, T_unit, is_ramp, T_ramp, raw_max, T_overlap, total_NT
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
        println(io, @sprintf("Slow-Start Generators      : %d units (dwell req: %dh)", length(slow_units), T_unit_req))
        println(io, @sprintf("Steady-State Decay Window  : %d hours", T_steady_req))
        println(io, @sprintf("Average Overlap Window     : %.2f hours", mean(df_stats.Final_Adaptive_Overlap_h)))
        println(io, @sprintf("Max Overlap Window         : %d hours", maximum(df_stats.Final_Adaptive_Overlap_h)))
        println(io, @sprintf("Min Overlap Window         : %d hours", minimum(df_stats.Final_Adaptive_Overlap_h)))
        println(io, "-"^80)
        println(io, "PER-INTERVAL OVERLAP WINDOW BREAKDOWN:")
        println(io, "-"^80)
        for row in eachrow(df_stats)
            println(io, @sprintf(
                "Interval %d | Start Hour %3d | Exec: %2dh | Steady: %2dh | UnitDwell: %2dh | Ramp: %5s (%2dh) | Final Overlap: %2dh | Total Solved: %2dh",
                row.Interval_ID, row.Start_Hour, row.Execution_Window_h, row.Steady_State_Overlap_h,
                row.Unit_Dwell_Overlap_h, string(row.Ramp_Event_Detected), row.Ramp_Overlap_h,
                row.Final_Adaptive_Overlap_h, row.Total_Solved_Horizon_h
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
