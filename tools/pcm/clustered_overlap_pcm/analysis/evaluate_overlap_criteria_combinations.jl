include("../paths.jl")

using Printf, Statistics, CSV, DataFrames

const ROOT = ADAPTIVE_PCM_PROJECT_ROOT

function arg_value(flag::String, default::Union{Nothing, String} = nothing)
    idx = findfirst(==(flag), ARGS)
    if idx === nothing || idx == length(ARGS)
        return default
    end
    return ARGS[idx + 1]
end

include("../../../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../../../src/read_inputdata_modules/readdatas.jl")
include("../../standard_pcm/period_scuc.jl")
include("../core/pcm_overlap_core.jl")

function repeat_time_series_to_horizon(curve::AbstractMatrix{<:Real}, target_hours::Int)
    source_hours = size(curve, 2)
    if source_hours == 0
        error("Cannot extend an empty time-series curve.")
    end
    repeat_count = cld(target_hours, source_hours)
    return repeat(Matrix{Float64}(curve), 1, repeat_count)[:, 1:target_hours]
end

function selected_overlap_from_components(criteria::Tuple{Bool, Bool, Bool}, T_steady::Int, T_unit::Int, T_ramp::Int,
        min_overlap::Int, max_overlap::Int, start_time::Int, exec_NT::Int, total_time_avail::Int)
    use_steady, use_unit, use_ramp = criteria
    candidates = Int[]
    if use_steady
        push!(candidates, T_steady)
    end
    if use_unit
        push!(candidates, T_unit)
    end
    if use_ramp
        push!(candidates, T_ramp)
    end
    raw_overlap = isempty(candidates) ? 0 : maximum(candidates)
    overlap = isempty(candidates) ? 0 : clamp(raw_overlap, min_overlap, max_overlap)
    remaining_overlap = total_time_avail - (start_time + exec_NT - 1)
    return max(0, min(overlap, remaining_overlap)), raw_overlap
end

function limiting_factor_for_subset(criteria::Tuple{Bool, Bool, Bool}, T_steady::Int, T_unit::Int, T_ramp::Int, raw_overlap::Int)
    use_steady, use_unit, use_ramp = criteria
    if raw_overlap == 0
        return "none"
    end
    factors = String[]
    if use_steady && T_steady == raw_overlap
        push!(factors, "steady")
    end
    if use_unit && T_unit == raw_overlap
        push!(factors, "unit_dwell")
    end
    if use_ramp && T_ramp == raw_overlap
        push!(factors, "ramp")
    end
    return join(factors, "+")
end

function run_mode!(df_results::DataFrame, df_intervals::DataFrame, mode_name::String, criteria::Tuple{Bool, Bool, Bool}, loads, winds, units, lines,
        DataCentras, config_param, stroges, scenarios_prob, hydros, trained_models, x_refs, exec_NT::Int, N_sets::Int, alpha::Float64,
        epsilon::Float64, min_overlap::Int, max_overlap::Int, NB::Int, NG::Int, ND::Int, NC::Int, ND2::Int, NL::Int, NH::Int)
    pre_results = nothing
    total_cost = 0.0
    total_startup_shutdown = 0.0
    total_fuel = 0.0
    total_wind_curtailment = 0.0
    total_load_shedding = 0.0
    overlap_history = Int[]
    solve_times = Float64[]
    factor_counts = Dict{String, Int}()
    total_time_avail = size(loads.load_curve, 2)

    GC.gc()
    elapsed = @elapsed allocated_bytes = @allocated begin
        for k ∈ 1:N_sets
            start_time = (k - 1) * exec_NT + 1
            _, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
                loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap,
                max_overlap, pre_results, k, "regression", trained_models, x_refs[k])
            T_overlap, raw_overlap = selected_overlap_from_components(
                criteria, T_steady, T_unit, T_ramp, min_overlap, max_overlap, start_time, exec_NT, total_time_avail)
            limiting_factor = limiting_factor_for_subset(criteria, T_steady, T_unit, T_ramp, raw_overlap)
            factor_counts[limiting_factor] = get(factor_counts, limiting_factor, 0) + 1
            push!(overlap_history, T_overlap)

            total_NT = exec_NT + T_overlap
            mini_units, mini_loads, mini_winds = update_adaptive_boundary_conditions(
                k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results)

            solve_start = time()
            res = each_period_scucmodel_modules(total_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines,
                DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)
            solve_time = time() - solve_start
            push!(solve_times, solve_time)
            if res === nothing
                error("Mode $mode_name failed at interval $k")
            end

            committed_res = truncate_and_commit_results(res, exec_NT)
            committed_cost = compute_committed_cost(
                committed_res, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, k, hydros, scenarios_prob)
            total_cost += sum(committed_cost[1:5])
            total_startup_shutdown += committed_cost[1] + committed_cost[2]
            total_fuel += committed_cost[3]
            total_load_shedding += committed_cost[6]
            total_wind_curtailment += committed_cost[7]

            push!(df_intervals, (
                mode_name, k, start_time, T_steady, T_unit, T_ramp, is_ramp, raw_overlap, T_overlap, limiting_factor, total_NT, solve_time))

            pre_results = res
        end
    end

    push!(df_results,
        (mode_name, criteria[1], criteria[2], criteria[3], total_cost, total_startup_shutdown, total_fuel, total_load_shedding,
            total_wind_curtailment, elapsed, sum(solve_times), allocated_bytes / 1024.0^2, mean(overlap_history),
            maximum(overlap_history), minimum(overlap_history), join(["$k=$v" for (k, v) ∈ sort(collect(factor_counts))], "; ")))
end

function main()
    println("="^80)
    println("EVALUATING OVERLAP CRITERIA COMBINATIONS")
    println("="^80)

    data_file_arg = arg_value("--data-file", joinpath(ROOT, "data", "data_118.xlsx"))
    data_file = isabspath(data_file_arg) ? data_file_arg : joinpath(ROOT, data_file_arg)
    scenario_label = arg_value("--scenario-label", replace(splitext(basename(data_file))[1], "data_" => "ieee"))
    outdir_arg = arg_value("--output-dir", joinpath(ROOT, "output", "details_schedule_results", "adaptive_pcm_simulation_results"))
    outdir = isabspath(outdir_arg) ? outdir_arg : joinpath(ROOT, outdir_arg)

    ENV["MODULE_UC_DATA_FILE"] = data_file
    println("Input data file: $data_file")
    println("Scenario label : $scenario_label")
    println("Output dir     : $outdir")

    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData,
    HydroCurve = readxlssheet()
    global config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, scenarios_prob, winds
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)
    config_param.is_NetWorkCon = 0
    winds, _ = genscenario(WindsFreqParam, 0)
    winds.scenarios_nums = 1
    winds.scenarios_curve = winds.scenarios_curve[1:1, :]
    scenarios_prob = 1.0

    exec_NT = 24
    N_sets = 7
    alpha = 0.25
    epsilon = 0.10
    min_overlap = 2
    max_overlap = 12
    required_horizon = exec_NT * N_sets

    if size(loads.load_curve, 2) < required_horizon
        loads.load_curve = repeat_time_series_to_horizon(loads.load_curve, required_horizon)
    end
    if size(winds.scenarios_curve, 2) < required_horizon
        winds.scenarios_curve = repeat_time_series_to_horizon(winds.scenarios_curve, required_horizon)
    end

    task_local_storage(:is_sampling_running, true)
    println("Calibrating steady-state model once for all modes...")
    calibration_time = @elapsed trained_models = sample_and_train_loss_models(
        loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob,
        hydros, exec_NT, min_overlap, max_overlap, NB, NG, ND, NC, ND2, NL, NH)

    println("Solving local no-boundary reference commitments once...")
    reference_times = Float64[]
    x_refs = Vector{Union{Nothing, Vector{Float64}}}(undef, N_sets)
    for k ∈ 1:N_sets
        start_time = (k - 1) * exec_NT + 1
        ref_elapsed = @elapsed x_refs[k] = solve_local_reference_commitment(
            loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob,
            hydros, start_time, exec_NT, max_overlap, NB, NG, ND, NC, ND2, NL, NH, k)
        push!(reference_times, ref_elapsed)
    end

    modes = [("NoOverlap", (false, false, false)), ("SteadyOnly", (true, false, false)), ("UnitOnly", (false, true, false)),
        ("RampOnly", (false, false, true)), ("Steady+Unit", (true, true, false)), ("Steady+Ramp", (true, false, true)),
        ("Unit+Ramp", (false, true, true)), ("Steady+Unit+Ramp", (true, true, true))]

    df_results = DataFrame(; Mode = String[], UseSteady = Bool[], UseUnitDwell = Bool[], UseRamp = Bool[], TotalCost_USD = Float64[],
        StartupShutdownCost_USD = Float64[], FuelCost_USD = Float64[], LoadShedding_MWh = Float64[], WindCurtailment_MWh = Float64[],
        WallTime_sec = Float64[], SubproblemSolveTime_sec = Float64[], JuliaAllocated_MB = Float64[],
        AvgOverlap_h = Float64[], MaxOverlap_h = Int[], MinOverlap_h = Int[], LimitingFactorCounts = String[])

    df_intervals = DataFrame(; Mode = String[], Interval_ID = Int[], Start_Hour = Int[], T_steady = Int[], T_unit = Int[],
        T_ramp = Int[], Ramp_Event_Detected = Bool[], Raw_Selected_Overlap_h = Int[], Final_Overlap_h = Int[],
        Limiting_Factor = String[], Total_Solved_Horizon_h = Int[], Subproblem_SolveTime_sec = Float64[])

    for (mode_name, criteria) ∈ modes
        println("-"^80)
        println("Running mode: $mode_name")
        run_mode!(df_results, df_intervals, mode_name, criteria, loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob,
            hydros, trained_models, x_refs, exec_NT, N_sets, alpha, epsilon, min_overlap, max_overlap, NB, NG, ND, NC, ND2, NL, NH)
    end

    baseline_cost = df_results[df_results[!, :Mode] .== "Steady+Unit+Ramp", :TotalCost_USD][1]
    baseline_time = df_results[df_results[!, :Mode] .== "NoOverlap", :SubproblemSolveTime_sec][1]
    df_results[!, :CostGap_vs_All_pct] = round.((df_results[!, :TotalCost_USD] .- baseline_cost) ./ baseline_cost .* 100.0; digits = 4)
    df_results[!, :SolveTimeDelta_vs_NoOverlap_sec] = round.(df_results[!, :SubproblemSolveTime_sec] .- baseline_time; digits = 3)
    df_results[!, :CalibrationTime_excluded_sec] = fill(calibration_time, nrow(df_results))
    df_results[!, :ReferenceTime_excluded_sec] = fill(sum(reference_times), nrow(df_results))

    mkpath(outdir)
    summary_path = joinpath(outdir, "criteria_combination_performance.csv")
    intervals_path = joinpath(outdir, "criteria_combination_intervals.csv")
    CSV.write(summary_path, df_results)
    CSV.write(intervals_path, df_intervals)
    cp(data_file, joinpath(outdir, "input_data_$(scenario_label).xlsx"); force = true)

    open(joinpath(outdir, "run_metadata.txt"), "w") do io
        println(io, "scenario_label=$scenario_label")
        println(io, "data_file=$data_file")
        println(io, "exec_NT=$exec_NT")
        println(io, "N_sets=$N_sets")
        println(io, "alpha=$alpha")
        println(io, "epsilon=$epsilon")
        println(io, "min_overlap=$min_overlap")
        println(io, "max_overlap=$max_overlap")
        println(io, "calibration_time_excluded_sec=$calibration_time")
        println(io, "reference_time_excluded_sec=$(sum(reference_times))")
    end

    println("="^80)
    println("CRITERIA COMBINATION SUMMARY")
    show(df_results; allrows = true, allcols = true)
    println()
    println("Calibration time excluded: ", calibration_time)
    println("Reference time excluded: ", sum(reference_times))
    println("Summary CSV: ", summary_path)
    println("Interval CSV: ", intervals_path)
end

main()
