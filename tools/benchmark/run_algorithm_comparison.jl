
using Dates
using JuMP

include(joinpath(@__DIR__, "..", "ccg", "ccg_solver.jl"))
include(joinpath(@__DIR__, "benchmark_uc.jl"))

const ALGORITHM_OUTPUT_ROOT = uc_output_root()

function algorithm_output_dir(algorithm_name::AbstractString; run_id::AbstractString = uc_run_id())
    output_dir = uc_algorithm_run_dir(algorithm_name; run_id = run_id)
    mkpath(output_dir)
    return output_dir
end

function algorithm_log_path(algorithm_name::AbstractString, scenario_count::Int64; run_id::AbstractString = uc_run_id())
    output_dir = joinpath(algorithm_output_dir(algorithm_name; run_id = run_id), "logs")
    mkpath(output_dir)
    return joinpath(output_dir, "$(algorithm_name)_$(scenario_count)_scenarios.log")
end

function mirror_power_balance_summary(algorithm_name::AbstractString, scenario_count::Int64; run_id::AbstractString = uc_run_id())
    prefix = uc_schedule_file_prefix(algorithm_name, scenario_count)
    source_path = joinpath(uc_scheduling_output_dir(algorithm_name; run_id = run_id), prefix * "power_balance_summary.csv")
    isfile(source_path) || return nothing
    power_balance_dir = joinpath(algorithm_output_dir(algorithm_name; run_id = run_id), "power_balance")
    mkpath(power_balance_dir)
    target_path = joinpath(power_balance_dir, "$(algorithm_name)_$(scenario_count)_scenarios.csv")
    cp(source_path, target_path; force = true)
    return target_path
end

function parse_benchmark_scenario_counts()
    if haskey(ENV, "BENCHMARK_SCENARIO_COUNTS")
        return [parse(Int64, strip(value)) for value in split(ENV["BENCHMARK_SCENARIO_COUNTS"], ",") if !isempty(strip(value))]
    end
    return [parse(Int64, get(ENV, "BENCHMARK_SCENARIO_COUNT", "2"))]
end

function scenario_count_label(scenario_counts::Vector{Int64})
    return join(string.(scenario_counts), "_")
end

function should_keep_log_line(line::AbstractString)
    text = strip(line)
    isempty(text) && return false

    noise_prefixes = (
        "Set parameter ",
        "Academic license",
        "Step-1:",
        "Step-2:",
        "Initializing Benders",
        "Objective function has been set",
        "Generating renewable energy scenarios",
    )
    any(startswith(text, prefix) for prefix in noise_prefixes) && return false

    noise_contains = (
        "constraint modules included",
        "objective functions exported",
        "utility functions exported",
        "all boundary conditions validated",
        "multicuts_libs have been loaded",
        "Benders decomposition [batch]",
        "The [JULIA] environment_config",
        "renewable energy curves module loaded",
        "inputdata was written",
        "Variables defined.",
        "constraints:",
        "MILP_type objective_function",
        "LP_type subproblem objective_function",
    )
    any(occursin(pattern, text) for pattern in noise_contains) && return false

    keep_contains = (
        "Starting",
        "ITER",
        "LOWER_bound",
        "UPPER_bound",
        "ACTIVE",
        "GAP",
        "ADDED",
        "FINAL",
        "Convergence achieved",
        "C&CG convergence achieved",
        "C&CG stopped",
        "maximum iterations",
        "No violated",
        "WARNING",
        "Error",
        "bound",
        "feasible_subproblems",
    )
    any(occursin(pattern, text) for pattern in keep_contains) && return true

    # Numeric iteration rows printed by Benders and CCG.
    return occursin(r"^\d+\s+", text)
end

function filter_algorithm_log(raw_text::AbstractString)
    lines = split(raw_text, '\n')
    kept = String[]
    last_blank = false
    for line in lines
        if should_keep_log_line(line)
            push!(kept, rstrip(line))
            last_blank = false
        elseif !last_blank && !isempty(kept)
            last_blank = true
        end
    end
    return isempty(kept) ? "" : join(kept, "\n") * "\n"
end

function env_bool(name::String, default::Bool)
    value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    return value in ("1", "true", "yes", "y", "on")
end

function capture_stdout_to_file(path::AbstractString, fn::Function)
    result_ref = Ref{Any}(nothing)
    raw_text = ""
    mkpath(dirname(path))
    elapsed = mktemp() do raw_path, raw_io
        close(raw_io)
        run_time = open(raw_path, "w") do io
            redirect_stdout(io) do
                redirect_stderr(io) do
                    @elapsed result_ref[] = fn()
                end
            end
        end
        raw_text = read(raw_path, String)
        return run_time
    end
    if env_bool("BENCHMARK_KEEP_RAW_LOGS", false)
        raw_path = replace(path, r"\.log$" => ".raw.log")
        open(raw_path, "w") do io
            return write(io, raw_text)
        end
    end
    open(path, "w") do io
        return write(io, filter_algorithm_log(raw_text))
    end
    return result_ref[], elapsed
end

function benders_data_tuple_to_namedtuple(config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras)
    return (
        config_param = config_param,
        units = units,
        lines = lines,
        loads = loads,
        winds = winds,
        psses = psses,
        DataCentras = DataCentras,
        NB = NB,
        NG = NG,
        NL = NL,
        ND = ND,
        NT = NT,
        NC = NC,
        ND2 = ND2,
        NW = Int64(length(winds.index)),
        NS = NS,
        full_scenario_probability = 1.0 / NS,
    )
end

function solve_benchmark_benders(; scenario_limit::Int64 = 20)
    setup = main(; scenario_limit = scenario_limit)
    scuc_masterproblem = setup.master_model
    scuc_subproblem = setup.sub_model
    master_model_struct = setup.master_struct
    batch_sub_model_struct_dic = setup.batch_subproblems
    config_param = setup.config_param
    units = setup.units
    lines = setup.lines
    loads = setup.loads
    winds = setup.winds
    psses = setup.psses
    NB = setup.NB
    NG = setup.NG
    NL = setup.NL
    ND = setup.ND
    NS = setup.NS
    NT = setup.NT
    NC = setup.NC
    ND2 = setup.ND2
    DataCentras = setup.DataCentras

    NW = Int64(length(winds.index))
    jensen_subproblem_struct = if get(ENV, "BENDERS_ENABLE_JENSEN_CUT", "0") == "1" && config_param.is_ConsiderMultiCUTs == 1
        build_jensen_subproblem_for_mean_scenario(NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, DataCentras, psses, config_param)
    else
        nothing
    end

    result = multiple_bender_decomposition_scuc(
        scuc_masterproblem,
        scuc_subproblem,
        master_model_struct,
        batch_sub_model_struct_dic,
        winds,
        config_param,
        NG,
        NT,
        NW,
        ND,
        NL;
        jensen_subproblem_struct = jensen_subproblem_struct,
    )

    data = benders_data_tuple_to_namedtuple(config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras)
    cost_summary = nothing
    dispatch_model = nothing
    if result.incumbent !== nothing
        dispatch_model = build_ccg_extensive_model(data, winds, NS, 1.0 / NS)
        fix_first_stage_commitment!(dispatch_model, result.incumbent)
        optimize!(dispatch_model)
        assert_is_solved_and_feasible(dispatch_model)
        cost_summary = export_solved_uc_model_results(
            dispatch_model,
            data;
            output_dir = uc_scheduling_output_dir("benders"),
            winds = winds,
            NS = NS,
            scenarios_prob = 1.0 / NS,
            file_prefix = uc_schedule_file_prefix("benders", NS),
        )
    else
        @warn "Benders did not produce an incumbent; scheduling CSV export was skipped."
    end

    return merge(result, (dispatch_model = dispatch_model, cost_summary = cost_summary))
end

function run_benders_benchmark(scenario_count::Int64)
    println("Starting benchmark Benders decomposition solver")
    return capture_stdout_to_file(
        algorithm_log_path("benders", scenario_count),
        () -> begin
            result = solve_benchmark_benders(; scenario_limit = scenario_count)
            mirror_power_balance_summary("benders", scenario_count)
            println("FINAL STATUS:       ", result.status)
            println("FINAL ITERATIONS:   ", result.iterations)
            println("FINAL UPPER BOUND:  ", result.upper_bound)
            println("FINAL LOWER BOUND:  ", result.lower_bound)
            println("FINAL GAP:          ", result.gap)
            return result
        end,
    )
end

function run_ccg_benchmark(scenario_count::Int64)
    println("Starting benchmark C&CG solver")
    return capture_stdout_to_file(
        algorithm_log_path("ccg", scenario_count),
        () -> begin
            result = solve_ccg_unit_commitment(; scenario_limit = scenario_count)
            mirror_power_balance_summary("ccg", scenario_count)
            println("FINAL STATUS:       ", result.status)
            println("FINAL ITERATIONS:   ", length(result.history))
            println("FINAL UPPER BOUND:  ", result.upper_bound)
            println("FINAL LOWER BOUND:  ", result.lower_bound)
            println("FINAL GAP:          ", result.gap)
            return result
        end,
    )
end

function run_extensive_form_benchmark(scenario_count::Int64)
    println("Starting benchmark extensive-form UC solver")
    return capture_stdout_to_file(
        algorithm_log_path("benchmark_uc", scenario_count),
        () -> begin
            result = solve_benchmark_uc(; scenario_limit = scenario_count)
            mirror_power_balance_summary("benchmark_uc", scenario_count)
            println("FINAL STATUS:       ", result.status)
            println("FINAL SCENARIOS:    ", length(result.active_scenarios))
            println("FINAL OBJECTIVE:    ", result.upper_bound)
            println("FINAL BEST BOUND:   ", result.lower_bound)
            println("FINAL GAP:          ", result.gap)
            return result
        end,
    )
end

function copy_algorithm_outputs_to_comparison(comparison_dir::AbstractString, algorithm_name::AbstractString; run_id::AbstractString = uc_run_id())
    source_dir = algorithm_output_dir(algorithm_name; run_id = run_id)
    target_dir = joinpath(comparison_dir, algorithm_name)
    if isdir(target_dir)
        rm(target_dir; recursive = true, force = true)
    end
    cp(source_dir, target_dir; force = true)
    return target_dir
end

function write_comparison_summary(comparison_dir::AbstractString, rows)
    summary_path = joinpath(comparison_dir, "algorithm_summary.csv")
    open(summary_path, "w") do io
        println(io, "algorithm,scenarios,status,iterations,upper_bound,lower_bound,gap,runtime_seconds")
        for row in rows
            println(
                io,
                join([row.algorithm, row.scenarios, row.status, row.iterations, row.upper_bound, row.lower_bound, row.gap, row.elapsed_seconds], ","),
            )
        end
    end
    return summary_path
end

function write_summary_csv(comparison_dir::AbstractString, rows)
    summary_path = joinpath(comparison_dir, "summary.csv")
    open(summary_path, "w") do io
        println(io, "algorithm,scenarios,status,iterations,lower_bound,upper_bound,gap,elapsed_seconds,max_ram_mb,log_path")
        for row in rows
            println(
                io,
                join(
                    [
                        row.algorithm,
                        row.scenarios,
                        row.status,
                        row.iterations,
                        row.lower_bound,
                        row.upper_bound,
                        row.gap,
                        row.elapsed_seconds,
                        row.max_ram_mb,
                        row.log_path,
                    ],
                    ",",
                ),
            )
        end
    end
    return summary_path
end

function result_max_ram_mb(result)
    if hasproperty(result, :history) && !isempty(result.history)
        values = [get(history_row, :memory_mb, NaN) for history_row in result.history]
        filtered_values = filter(!isnan, Float64.(values))
        return isempty(filtered_values) ? process_memory_mb() : maximum(filtered_values)
    end
    return process_memory_mb()
end

function result_iterations(algorithm_name::AbstractString, result)
    if algorithm_name == "benchmark_uc"
        return 1
    end
    if hasproperty(result, :iterations)
        return result.iterations
    end
    return hasproperty(result, :history) ? length(result.history) : 1
end

function result_status(result)
    return string(result.status)
end

function result_summary_row(algorithm_name::AbstractString, scenario_count::Int64, result, elapsed_seconds::Real)
    log_path = algorithm_log_path(algorithm_name, scenario_count)
    return (
        algorithm = algorithm_name,
        scenarios = scenario_count,
        status = result_status(result),
        iterations = result_iterations(algorithm_name, result),
        lower_bound = result.lower_bound,
        upper_bound = result.upper_bound,
        gap = result.gap,
        elapsed_seconds = round(elapsed_seconds; digits = 3),
        max_ram_mb = round(result_max_ram_mb(result); digits = 2),
        log_path = log_path,
    )
end

function write_iteration_history_csv(comparison_dir::AbstractString, entries)
    path = joinpath(comparison_dir, "iteration_history.csv")
    open(path, "w") do io
        println(io, "algorithm,scenarios,iteration,active_scenarios,lower_bound,upper_bound,gap,added_scenarios,ram_mb")
        for entry in entries
            algorithm_name = entry.algorithm
            scenario_count = entry.scenarios
            result = entry.result
            if algorithm_name == "benchmark_uc"
                println(
                    io,
                    join(
                        [
                            algorithm_name,
                            scenario_count,
                            1,
                            scenario_count,
                            result.lower_bound,
                            result.upper_bound,
                            result.gap,
                            "",
                            result_max_ram_mb(result),
                        ],
                        ",",
                    ),
                )
                continue
            end
            for history_row in result.history
                added_scenarios = if haskey(history_row, :added_scenarios)
                    join(history_row.added_scenarios, ";")
                else
                    ""
                end
                active_scenarios = if haskey(history_row, :active_scenarios)
                    history_row.active_scenarios
                else
                    scenario_count
                end
                lower_bound = get(history_row, :lower_bound, result.lower_bound)
                upper_bound = get(history_row, :upper_bound, result.upper_bound)
                gap = get(history_row, :gap, result.gap)
                ram_mb = get(history_row, :memory_mb, result_max_ram_mb(result))
                println(
                    io,
                    join(
                        [
                            algorithm_name,
                            scenario_count,
                            history_row.iteration,
                            active_scenarios,
                            lower_bound,
                            upper_bound,
                            gap,
                            added_scenarios,
                            ram_mb,
                        ],
                        ",",
                    ),
                )
            end
        end
    end
    return path
end

function power_balance_quality_row(algorithm_name::AbstractString, scenario_count::Int64)
    path = joinpath(algorithm_output_dir(algorithm_name), "power_balance", "$(algorithm_name)_$(scenario_count)_scenarios.csv")
    if !isfile(path)
        return (
            algorithm = algorithm_name,
            scenarios = scenario_count,
            max_abs_balance_error = missing,
            total_load_curtailment = missing,
            total_wind_curtailment = missing,
            peak_served_load = missing,
        )
    end
    lines = readlines(path)
    isempty(lines) && return (
        algorithm = algorithm_name,
        scenarios = scenario_count,
        max_abs_balance_error = missing,
        total_load_curtailment = missing,
        total_wind_curtailment = missing,
        peak_served_load = missing,
    )
    header = split(lines[1], ",")
    column_index(name) = findfirst(==(name), header)
    net_balance_idx = column_index("net_balance")
    load_shed_idx = column_index("load_shed")
    wind_spill_idx = column_index("wind_spill")
    served_load_idx = column_index("served_load")
    max_abs_balance_error = 0.0
    total_load_curtailment = 0.0
    total_wind_curtailment = 0.0
    peak_served_load = 0.0
    for line in lines[2:end]
        values = split(line, ",")
        max_abs_balance_error = max(max_abs_balance_error, abs(parse(Float64, values[net_balance_idx])))
        total_load_curtailment += parse(Float64, values[load_shed_idx])
        total_wind_curtailment += parse(Float64, values[wind_spill_idx])
        peak_served_load = max(peak_served_load, parse(Float64, values[served_load_idx]))
    end
    return (
        algorithm = algorithm_name,
        scenarios = scenario_count,
        max_abs_balance_error = max_abs_balance_error,
        total_load_curtailment = total_load_curtailment,
        total_wind_curtailment = total_wind_curtailment,
        peak_served_load = peak_served_load,
    )
end

function write_power_balance_quality_csv(comparison_dir::AbstractString, summary_rows)
    path = joinpath(comparison_dir, "power_balance_quality.csv")
    open(path, "w") do io
        println(io, "algorithm,scenarios,max_abs_balance_error,total_load_curtailment,total_wind_curtailment,peak_served_load")
        for row in summary_rows
            quality = power_balance_quality_row(row.algorithm, row.scenarios)
            println(
                io,
                join(
                    [
                        quality.algorithm,
                        quality.scenarios,
                        quality.max_abs_balance_error,
                        quality.total_load_curtailment,
                        quality.total_wind_curtailment,
                        quality.peak_served_load,
                    ],
                    ",",
                ),
            )
        end
    end
    return path
end

function write_benchmark_report(comparison_dir::AbstractString, run_id::AbstractString, scenario_counts::Vector{Int64}, summary_rows)
    path = joinpath(comparison_dir, "benchmark_report.md")
    open(path, "w") do io
        println(io, "# Benchmark UC vs Benders vs CCG Report")
        println(io)
        println(io, "- Run id: `$(run_id)`")
        println(io, "- Generated at: `$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))`")
        println(io, "- Scenario counts: `$(join(scenario_counts, ", "))`")
        println(io, "- Benders max iterations: `$(get(ENV, "BENDERS_MAX_ITERATIONS", "10000"))`")
        println(io, "- CCG max iterations: `$(get(ENV, "CCG_MAX_ITERATIONS", "50"))`")
        println(io)
        println(io, "## Summary")
        println(io)
        println(io, "| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |")
        println(io, "|---|---:|---|---:|---:|---:|---:|---:|---:|")
        for row in summary_rows
            println(
                io,
                "| $(row.algorithm) | $(row.scenarios) | $(row.status) | $(row.iterations) | $(row.lower_bound) | $(row.upper_bound) | $(row.gap) | $(row.elapsed_seconds) | $(row.max_ram_mb) |",
            )
        end
        println(io)
        println(io, "## Tables")
        println(io)
        println(io, "- Summary: `$(joinpath(comparison_dir, "summary.csv"))`")
        println(io, "- Iteration history: `$(joinpath(comparison_dir, "iteration_history.csv"))`")
        println(io, "- Power-balance quality table: `$(joinpath(comparison_dir, "power_balance_quality.csv"))`")
        println(io)
        println(io, "## Interpretation")
        println(io)
        println(
            io,
            "- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.",
        )
        println(
            io,
            "- Benders evaluates scenario subproblems under first-stage commitments; the exported scheduling files use the best incumbent dispatch reconstruction.",
        )
        println(
            io,
            "- CCG starts from a scenario subset and adds uncovered scenarios; its active-scenario history is recorded in `iteration_history.csv`.",
        )
        return println(
            io,
            "- Power-balance quality reports residual balance error, load curtailment, wind curtailment, and peak served load from each algorithm's generated power-balance CSV.",
        )
    end
    return path
end

function run_algorithm_comparison(; scenario_counts::Vector{Int64} = parse_benchmark_scenario_counts())
    run_id = get(ENV, "MODULE_UC_RUN_ID", "$(Dates.format(now(), "yyyymmdd_HHMMSS"))_three_way_$(scenario_count_label(scenario_counts))")
    ENV["MODULE_UC_RUN_ID"] = run_id
    comparison_dir = joinpath(ALGORITHM_OUTPUT_ROOT, "comparison", run_id)
    mkpath(comparison_dir)

    summary_rows = NamedTuple[]
    history_entries = NamedTuple[]
    for scenario_count in scenario_counts
        benchmark_result, benchmark_time = run_extensive_form_benchmark(scenario_count)
        push!(summary_rows, result_summary_row("benchmark_uc", scenario_count, benchmark_result, benchmark_time))
        push!(history_entries, (algorithm = "benchmark_uc", scenarios = scenario_count, result = benchmark_result))

        benders_result, benders_time = run_benders_benchmark(scenario_count)
        push!(summary_rows, result_summary_row("benders", scenario_count, benders_result, benders_time))
        push!(history_entries, (algorithm = "benders", scenarios = scenario_count, result = benders_result))

        ccg_result, ccg_time = run_ccg_benchmark(scenario_count)
        push!(summary_rows, result_summary_row("ccg", scenario_count, ccg_result, ccg_time))
        push!(history_entries, (algorithm = "ccg", scenarios = scenario_count, result = ccg_result))
    end

    write_comparison_summary(comparison_dir, summary_rows)
    write_summary_csv(comparison_dir, summary_rows)
    write_iteration_history_csv(comparison_dir, history_entries)
    write_power_balance_quality_csv(comparison_dir, summary_rows)
    write_benchmark_report(comparison_dir, run_id, scenario_counts, summary_rows)
    for algorithm_name in ("benders", "ccg", "benchmark_uc")
        copy_algorithm_outputs_to_comparison(comparison_dir, algorithm_name; run_id = run_id)
    end
    println("Comparison outputs saved to: ", comparison_dir)
    return (comparison_dir = comparison_dir, rows = summary_rows)
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_algorithm_comparison()
end
