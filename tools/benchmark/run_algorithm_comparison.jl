using Dates
using Printf

const REPO_ROOT = abspath(joinpath(@__DIR__, "..", ".."))
cd(REPO_ROOT)

include(joinpath(REPO_ROOT, "tools", "ccg", "ccg_solver.jl"))
include(joinpath(REPO_ROOT, "tools", "benchmark", "benchmark_uc.jl"))

function env_bool(name::String, default::Bool)
	value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
	return value in ("1", "true", "yes", "y", "on")
end

function parse_scenario_list()
	raw = get(ENV, "BENCHMARK_SCENARIOS", "2,6")
	values = [parse(Int64, strip(item)) for item in split(raw, ",") if !isempty(strip(item))]
	!isempty(values) || throw(ArgumentError("BENCHMARK_SCENARIOS must contain at least one integer"))
	return values
end

function ensure_dir(path::AbstractString)
	mkpath(path)
	return path
end

function csv_escape(value)
	text = string(value)
	if occursin(",", text) || occursin("\"", text) || occursin("\n", text)
		return "\"" * replace(text, "\"" => "\"\"") * "\""
	end
	return text
end

function write_csv(path::AbstractString, header::Vector{String}, rows)
	open(path, "w") do io
		println(io, join(csv_escape.(header), ","))
		for row in rows
			println(io, join(csv_escape.(row), ","))
		end
	end
	return path
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

function finite_or_blank(value)
	if value isa Missing || value === nothing
		return ""
	end
	if value isa Number && !isfinite(value)
		return ""
	end
	return value
end

function set_benchmark_defaults()
	ENV["PRINT_BOUNDARY_CONDITION"] = get(ENV, "BENCHMARK_PRINT_BOUNDARY_CONDITION", "0")
	ENV["BOUNDARY_SHOW_PLOTS"] = "0"
	ENV["BENDERS_MAX_ITERATIONS"] = get(ENV, "BENCHMARK_BENDERS_MAX_ITERATIONS", get(ENV, "BENDERS_MAX_ITERATIONS", "3"))
	ENV["BENDERS_PARALLEL_SUBPROBLEMS"] = get(ENV, "BENCHMARK_BENDERS_PARALLEL_SUBPROBLEMS", "0")
	ENV["BENDERS_VERBOSE_CUTS"] = get(ENV, "BENCHMARK_BENDERS_VERBOSE_CUTS", "0")
	ENV["CCG_MAX_ITERATIONS"] = get(ENV, "BENCHMARK_CCG_MAX_ITERATIONS", get(ENV, "CCG_MAX_ITERATIONS", "3"))
	ENV["CCG_PARALLEL_RECOURSE"] = get(ENV, "BENCHMARK_CCG_PARALLEL_RECOURSE", "0")
	ENV["CCG_SCENARIOS_PER_ITERATION"] = get(ENV, "BENCHMARK_CCG_SCENARIOS_PER_ITERATION", get(ENV, "CCG_SCENARIOS_PER_ITERATION", "2"))
	return nothing
end

function capture_stdout_to_file(path::AbstractString, fn::Function)
	result_ref = Ref{Any}(nothing)
	raw_text = ""
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
			write(io, raw_text)
		end
	end
	open(path, "w") do io
		write(io, filter_algorithm_log(raw_text))
	end
	return result_ref[], elapsed
end

function run_benders_case(scenario_count::Int64, log_path::AbstractString)
	return capture_stdout_to_file(log_path, () -> begin
		ENV["BENDERS_SCENARIO_LIMIT"] = string(scenario_count)
		scuc_masterproblem,
		scuc_subproblem,
		master_model_struct,
		sub_model_struct,
		batch_sub_model_struct_dic,
		config_param,
		units,
		lines,
		loads,
		winds,
		psses,
		NB,
		NG,
		NL,
		ND,
		NS,
		NT,
		NC,
		ND2,
		DataCentras = main(; scenario_limit = scenario_count)

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
		println("FINAL STATUS:       ", result.status)
		println("FINAL ITERATIONS:   ", result.iterations)
		println("FINAL UPPER BOUND:  ", result.upper_bound)
		println("FINAL LOWER BOUND:  ", result.lower_bound)
		println("FINAL GAP:          ", result.gap)
		return (
			result = result,
			data = (
				config_param = config_param,
				units = units,
				lines = lines,
				loads = loads,
				winds = winds,
				psses = psses,
				NB = NB,
				NG = NG,
				NL = NL,
				ND = ND,
				NS = NS,
				NT = NT,
				NC = NC,
				ND2 = ND2,
				NW = NW,
				DataCentras = DataCentras,
			),
		)
	end)
end

function run_ccg_case(scenario_count::Int64, log_path::AbstractString)
	return capture_stdout_to_file(log_path, () -> begin
		ENV["CCG_SCENARIO_LIMIT"] = string(scenario_count)
		return solve_ccg_unit_commitment(; scenario_limit = scenario_count)
	end)
end

function run_benchmark_uc_case(scenario_count::Int64, log_path::AbstractString)
	return capture_stdout_to_file(log_path, () -> begin
		println("Starting benchmark extensive-form UC solver")
		result = solve_benchmark_uc(; scenario_limit = scenario_count)
		println("FINAL STATUS:       ", result.status)
		println("FINAL SCENARIOS:    ", length(result.active_scenarios))
		println("FINAL OBJECTIVE:    ", result.upper_bound)
		println("FINAL BEST BOUND:   ", result.lower_bound)
		println("FINAL GAP:          ", result.gap)
		return result
	end)
end

function array_value(model, symbol_name::String)
	sym = Symbol(symbol_name)
	haskey(JuMP.object_dictionary(model), sym) || return nothing
	return Array(value.(model[sym]))
end

function rows_for_scenario(total_rows::Int64, block_size::Int64, scenario_index::Int64)
	start_row = 1 + (scenario_index - 1) * block_size
	stop_row = min(scenario_index * block_size, total_rows)
	return start_row:stop_row
end

function storage_power(model, data, scenario_index::Int64, time_index::Int64)
	if data.NC <= 0 || data.config_param.is_ConsiderBESS != 1
		return (charge = 0.0, discharge = 0.0)
	end
	pc_pos = array_value(model, "pc⁺")
	pc_neg = array_value(model, "pc⁻")
	if pc_pos === nothing || pc_neg === nothing
		return (charge = 0.0, discharge = 0.0)
	end
	rows = rows_for_scenario(size(pc_pos, 1), data.NC, scenario_index)
	return (
		charge = sum(pc_pos[rows, time_index]),
		discharge = sum(pc_neg[rows, time_index]),
	)
end

function extract_power_balance_from_model(model, data; scenario_ids = collect(1:data.NS), active_scenario_ids = scenario_ids)
	pg = array_value(model, "pg₀")
	delta_pd = array_value(model, "Δpd")
	delta_pw = array_value(model, "Δpw")
	pg === nothing && return NamedTuple[]
	rows = NamedTuple[]
	for (local_scenario, source_scenario) in enumerate(active_scenario_ids)
		for t in 1:data.NT
			gen_rows = rows_for_scenario(size(pg, 1), data.NG, local_scenario)
			load_rows = delta_pd === nothing ? (1:0) : rows_for_scenario(size(delta_pd, 1), data.ND, local_scenario)
			wind_rows = delta_pw === nothing ? (1:0) : rows_for_scenario(size(delta_pw, 1), data.NW, local_scenario)
			thermal_generation = sum(pg[gen_rows, t])
			load_demand = sum(data.loads.load_curve[:, t])
			wind_available = sum(data.winds.p_max) * data.winds.scenarios_curve[source_scenario, t]
			load_curtailment = delta_pd === nothing ? 0.0 : sum(delta_pd[load_rows, t])
			wind_curtailment = delta_pw === nothing ? 0.0 : sum(delta_pw[wind_rows, t])
			storage = storage_power(model, data, local_scenario, t)
			wind_used = wind_available - wind_curtailment
			served_load = load_demand - load_curtailment
			balance_error = thermal_generation + wind_used + storage.discharge - storage.charge - served_load
			push!(
				rows,
				(
					scenario = source_scenario,
					time = t,
					load_demand = load_demand,
					served_load = served_load,
					thermal_generation = thermal_generation,
					wind_available = wind_available,
					wind_used = wind_used,
					load_curtailment = load_curtailment,
					wind_curtailment = wind_curtailment,
					storage_charge = storage.charge,
					storage_discharge = storage.discharge,
					balance_error = balance_error,
				),
			)
		end
	end
	return rows
end

function extract_benders_power_balance(bundle)
	result = bundle.result
	data = bundle.data
	result === nothing && return NamedTuple[]
	result.subproblem_models === nothing && return NamedTuple[]
	rows = NamedTuple[]
	for scenario_id in sort(collect(keys(result.subproblem_models)))
		model = result.subproblem_models[scenario_id].model
		local_data = merge(data, (NS = 1,))
		append!(rows, extract_power_balance_from_model(model, local_data; scenario_ids = [scenario_id], active_scenario_ids = [scenario_id]))
	end
	return rows
end

function extract_ccg_power_balance(result)
	result === nothing && return NamedTuple[]
	model = result.model
	model === nothing && return NamedTuple[]
	active = collect(result.active_scenarios)
	active_data = merge(result.data, (NS = length(active),))
	return extract_power_balance_from_model(model, active_data; scenario_ids = active, active_scenario_ids = active)
end

function extract_benchmark_uc_power_balance(result)
	result === nothing && return NamedTuple[]
	model = result.model
	model === nothing && return NamedTuple[]
	active = collect(result.active_scenarios)
	return extract_power_balance_from_model(model, result.data; scenario_ids = active, active_scenario_ids = active)
end

function history_rows(algorithm::String, scenario_count::Int64, history)
	rows = []
	for item in history
		added = haskey(item, :added_scenarios) ? join(item.added_scenarios, ";") : ""
		active = haskey(item, :active_scenarios) ? item.active_scenarios : get(item, :total_subproblems, scenario_count)
		push!(
			rows,
			[
				algorithm,
				scenario_count,
				item.iteration,
				active,
				finite_or_blank(item.lower_bound),
				finite_or_blank(item.upper_bound),
				finite_or_blank(item.gap),
				added,
				finite_or_blank(item.memory_mb),
			],
		)
	end
	return rows
end

function final_summary_row(algorithm::String, scenario_count::Int64, result, elapsed::Float64, log_path::String)
	status = haskey(result, :status) ? result.status : "completed"
	iterations = haskey(result, :iterations) ? result.iterations : length(result.history)
	upper_bound = haskey(result, :upper_bound) ? result.upper_bound : missing
	lower_bound = haskey(result, :lower_bound) ? result.lower_bound : missing
	gap = haskey(result, :gap) ? result.gap : missing
	max_memory = isempty(result.history) ? process_memory_mb() : maximum([row.memory_mb for row in result.history])
	return [
		algorithm,
		scenario_count,
		status,
		iterations,
		finite_or_blank(lower_bound),
		finite_or_blank(upper_bound),
		finite_or_blank(gap),
		round(elapsed; digits = 3),
		round(max_memory; digits = 2),
		log_path,
	]
end

function write_power_balance_csv(path::AbstractString, rows)
	header = [
		"scenario",
		"time",
		"load_demand",
		"served_load",
		"thermal_generation",
		"wind_available",
		"wind_used",
		"load_curtailment",
		"wind_curtailment",
		"storage_charge",
		"storage_discharge",
		"balance_error",
	]
	write_csv(path, header, [[getfield(row, Symbol(col)) for col in header] for row in rows])
end

function power_balance_quality_row(algorithm::String, scenario_count::Int64, rows)
	if isempty(rows)
		return [algorithm, scenario_count, "", "", "", ""]
	end
	return [
		algorithm,
		scenario_count,
		maximum(abs.(getfield.(rows, :balance_error))),
		sum(getfield.(rows, :load_curtailment)),
		sum(getfield.(rows, :wind_curtailment)),
		maximum(getfield.(rows, :served_load)),
	]
end

function points_for_metric(rows, x_key::Symbol, y_key::Symbol; filter_fn = _ -> true)
	filtered = [row for row in rows if filter_fn(row)]
	return [(Float64(getfield(row, x_key)), Float64(getfield(row, y_key))) for row in filtered]
end

function svg_polyline(points, x_min, x_max, y_min, y_max, width, height, margin, color)
	isempty(points) && return ""
	scale_x(x) = margin + (x - x_min) / max(x_max - x_min, eps()) * (width - 2margin)
	scale_y(y) = height - margin - (y - y_min) / max(y_max - y_min, eps()) * (height - 2margin)
	coords = join(["$(round(scale_x(x); digits=2)),$(round(scale_y(y); digits=2))" for (x, y) in points], " ")
	return "<polyline points=\"$coords\" fill=\"none\" stroke=\"$color\" stroke-width=\"2\"/>"
end

function write_line_svg(path::AbstractString, title::String, series)
	width = 980
	height = 520
	margin = 64
	all_points = reduce(vcat, [item.points for item in series]; init = Tuple{Float64, Float64}[])
	isempty(all_points) && return nothing
	x_values = [p[1] for p in all_points]
	y_values = [p[2] for p in all_points if isfinite(p[2])]
	isempty(y_values) && return nothing
	x_min, x_max = minimum(x_values), maximum(x_values)
	y_min, y_max = minimum(y_values), maximum(y_values)
	if y_min == y_max
		y_min -= 1
		y_max += 1
	end
	colors = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#ff7f0e", "#17becf"]
	open(path, "w") do io
		println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
		println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
		println(io, "<text x=\"$(width / 2)\" y=\"32\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"22\">$(title)</text>")
		println(io, "<line x1=\"$margin\" y1=\"$(height - margin)\" x2=\"$(width - margin)\" y2=\"$(height - margin)\" stroke=\"#333\"/>")
		println(io, "<line x1=\"$margin\" y1=\"$margin\" x2=\"$margin\" y2=\"$(height - margin)\" stroke=\"#333\"/>")
		for (i, item) in enumerate(series)
			color = colors[mod1(i, length(colors))]
			println(io, svg_polyline(item.points, x_min, x_max, y_min, y_max, width, height, margin, color))
			println(io, "<text x=\"$(width - margin + 8)\" y=\"$(margin + 18i)\" font-family=\"Arial\" font-size=\"13\" fill=\"$color\">$(item.label)</text>")
		end
		println(io, "<text x=\"$(width / 2)\" y=\"$(height - 18)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"13\">iteration / time period</text>")
		println(io, "<text x=\"18\" y=\"$(height / 2)\" text-anchor=\"middle\" transform=\"rotate(-90 18,$(height / 2))\" font-family=\"Arial\" font-size=\"13\">value</text>")
		println(io, "</svg>")
	end
	return path
end

function write_bar_svg(path::AbstractString, title::String, labels::Vector{String}, values::Vector{Float64}; ylabel::String = "value")
	width = 980
	height = 520
	margin = 72
	max_value = max(maximum(values), eps())
	bar_width = (width - 2margin) / max(length(values), 1) * 0.62
	open(path, "w") do io
		println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
		println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
		println(io, "<text x=\"$(width / 2)\" y=\"32\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"22\">$title</text>")
		println(io, "<line x1=\"$margin\" y1=\"$(height - margin)\" x2=\"$(width - margin)\" y2=\"$(height - margin)\" stroke=\"#333\"/>")
		println(io, "<line x1=\"$margin\" y1=\"$margin\" x2=\"$margin\" y2=\"$(height - margin)\" stroke=\"#333\"/>")
		for (i, value) in enumerate(values)
			x = margin + (i - 0.5) * (width - 2margin) / length(values) - bar_width / 2
			bar_height = value / max_value * (height - 2margin)
			y = height - margin - bar_height
			println(io, "<rect x=\"$x\" y=\"$y\" width=\"$bar_width\" height=\"$bar_height\" fill=\"#1f77b4\"/>")
			println(io, "<text x=\"$(x + bar_width / 2)\" y=\"$(y - 8)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"12\">$(round(value; digits=2))</text>")
			println(io, "<text x=\"$(x + bar_width / 2)\" y=\"$(height - margin + 18)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"11\">$(labels[i])</text>")
		end
		println(io, "<text x=\"18\" y=\"$(height / 2)\" text-anchor=\"middle\" transform=\"rotate(-90 18,$(height / 2))\" font-family=\"Arial\" font-size=\"13\">$ylabel</text>")
		println(io, "</svg>")
	end
	return path
end

function write_markdown_report(path, run_id, summary_rows, scenario_list, comparison_dir)
	open(path, "w") do io
		println(io, "# Benchmark UC vs Benders vs CCG Report")
		println(io)
		println(io, "- Run id: `$run_id`")
		println(io, "- Generated at: `$(Dates.format(now(), dateformat"yyyy-mm-dd HH:MM:SS"))`")
		println(io, "- Scenario counts: `$(join(scenario_list, ", "))`")
		println(io, "- Benders max iterations: `$(get(ENV, "BENDERS_MAX_ITERATIONS", ""))`")
		println(io, "- CCG max iterations: `$(get(ENV, "CCG_MAX_ITERATIONS", ""))`")
		println(io)
		println(io, "## Summary")
		println(io)
		println(io, "| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |")
		println(io, "|---|---:|---|---:|---:|---:|---:|---:|---:|")
		for row in summary_rows
			println(io, "| $(row[1]) | $(row[2]) | $(row[3]) | $(row[4]) | $(row[5]) | $(row[6]) | $(row[7]) | $(row[8]) | $(row[9]) |")
		end
		println(io)
		println(io, "## Figures")
		println(io)
		println(io, "- Gap convergence: `$(joinpath(comparison_dir, "gap_convergence.svg"))`")
		println(io, "- Runtime comparison: `$(joinpath(comparison_dir, "runtime_seconds.svg"))`")
		println(io, "- RAM comparison: `$(joinpath(comparison_dir, "ram_mb.svg"))`")
		println(io, "- Power-balance sample: `$(joinpath(comparison_dir, "power_balance_sample.svg"))`")
		println(io, "- Power-balance quality table: `$(joinpath(comparison_dir, "power_balance_quality.csv"))`")
		println(io)
		println(io, "## Interpretation")
		println(io)
		println(io, "- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.")
		println(io, "- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.")
		println(io, "- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.")
		println(io, "- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.")
	end
	return path
end

function sample_power_series(label_prefix::String, rows)
	isempty(rows) && return NamedTuple[]
	first_scenario = first(unique([row.scenario for row in rows]))
	return [
		(label = "$label_prefix load", points = points_for_metric(rows, :time, :served_load; filter_fn = row -> row.scenario == first_scenario)),
		(label = "$label_prefix thermal", points = points_for_metric(rows, :time, :thermal_generation; filter_fn = row -> row.scenario == first_scenario)),
		(label = "$label_prefix wind", points = points_for_metric(rows, :time, :wind_used; filter_fn = row -> row.scenario == first_scenario)),
	]
end

function build_gap_series(iteration_rows, scenario_list)
	series = NamedTuple[]
	for algorithm in ["benchmark_uc", "benders", "ccg"]
		for scenario_count in scenario_list
			points = Tuple{Float64, Float64}[]
			for row in iteration_rows
				if row[1] == algorithm && row[2] == scenario_count && row[7] != ""
					push!(points, (Float64(row[3]), parse(Float64, string(row[7]))))
				end
			end
			push!(series, (label = "$algorithm-$scenario_count", points = points))
		end
	end
	return series
end

function main_report()
	set_benchmark_defaults()
	scenario_list = parse_scenario_list()
	run_id = get(ENV, "BENCHMARK_RUN_ID", Dates.format(now(), dateformat"yyyymmdd_HHMMSS"))
	benchmark_uc_dir = ensure_dir(joinpath(REPO_ROOT, "output", "benchmark_uc", run_id))
	benders_dir = ensure_dir(joinpath(REPO_ROOT, "output", "benders", run_id))
	ccg_dir = ensure_dir(joinpath(REPO_ROOT, "output", "ccg", run_id))
	comparison_dir = ensure_dir(joinpath(REPO_ROOT, "output", "comparison", run_id))
	ensure_dir(joinpath(benchmark_uc_dir, "logs"))
	ensure_dir(joinpath(benders_dir, "logs"))
	ensure_dir(joinpath(ccg_dir, "logs"))
	ensure_dir(joinpath(benchmark_uc_dir, "power_balance"))
	ensure_dir(joinpath(benders_dir, "power_balance"))
	ensure_dir(joinpath(ccg_dir, "power_balance"))

	summary_rows = []
	iteration_rows = []
	power_quality_rows = []
	power_plot_series = []

	for scenario_count in scenario_list
		println("Running Benchmark UC with $scenario_count scenarios...")
		benchmark_uc_log = joinpath(benchmark_uc_dir, "logs", "benchmark_uc_$(scenario_count)_scenarios.log")
		benchmark_uc_result, benchmark_uc_elapsed = run_benchmark_uc_case(scenario_count, benchmark_uc_log)
		push!(summary_rows, final_summary_row("benchmark_uc", scenario_count, benchmark_uc_result, benchmark_uc_elapsed, benchmark_uc_log))
		append!(iteration_rows, history_rows("benchmark_uc", scenario_count, benchmark_uc_result.history))
		benchmark_uc_power = extract_benchmark_uc_power_balance(benchmark_uc_result)
		write_power_balance_csv(joinpath(benchmark_uc_dir, "power_balance", "benchmark_uc_$(scenario_count)_scenarios.csv"), benchmark_uc_power)
		push!(power_quality_rows, power_balance_quality_row("benchmark_uc", scenario_count, benchmark_uc_power))

		println("Running Benders with $scenario_count scenarios...")
		benders_log = joinpath(benders_dir, "logs", "benders_$(scenario_count)_scenarios.log")
		benders_bundle, benders_elapsed = run_benders_case(scenario_count, benders_log)
		push!(summary_rows, final_summary_row("benders", scenario_count, benders_bundle.result, benders_elapsed, benders_log))
		append!(iteration_rows, history_rows("benders", scenario_count, benders_bundle.result.history))
		benders_power = extract_benders_power_balance(benders_bundle)
		write_power_balance_csv(joinpath(benders_dir, "power_balance", "benders_$(scenario_count)_scenarios.csv"), benders_power)
		push!(power_quality_rows, power_balance_quality_row("benders", scenario_count, benders_power))

		println("Running CCG with $scenario_count scenarios...")
		ccg_log = joinpath(ccg_dir, "logs", "ccg_$(scenario_count)_scenarios.log")
		ccg_result, ccg_elapsed = run_ccg_case(scenario_count, ccg_log)
		push!(summary_rows, final_summary_row("ccg", scenario_count, ccg_result, ccg_elapsed, ccg_log))
		append!(iteration_rows, history_rows("ccg", scenario_count, ccg_result.history))
		ccg_power = extract_ccg_power_balance(ccg_result)
		write_power_balance_csv(joinpath(ccg_dir, "power_balance", "ccg_$(scenario_count)_scenarios.csv"), ccg_power)
		push!(power_quality_rows, power_balance_quality_row("ccg", scenario_count, ccg_power))

		append!(power_plot_series, sample_power_series("benchmark_uc s$(scenario_count)", benchmark_uc_power))
		append!(power_plot_series, sample_power_series("benders s$(scenario_count)", benders_power))
		append!(power_plot_series, sample_power_series("ccg s$(scenario_count)", ccg_power))
	end

	write_csv(
		joinpath(comparison_dir, "summary.csv"),
		["algorithm", "scenarios", "status", "iterations", "lower_bound", "upper_bound", "gap", "elapsed_seconds", "max_ram_mb", "log_path"],
		summary_rows,
	)
	write_csv(
		joinpath(comparison_dir, "iteration_history.csv"),
		["algorithm", "scenarios", "iteration", "active_scenarios", "lower_bound", "upper_bound", "gap", "added_scenarios", "ram_mb"],
		iteration_rows,
	)
	write_csv(
		joinpath(comparison_dir, "power_balance_quality.csv"),
		["algorithm", "scenarios", "max_abs_balance_error", "total_load_curtailment", "total_wind_curtailment", "peak_served_load"],
		power_quality_rows,
	)

	write_line_svg(joinpath(comparison_dir, "gap_convergence.svg"), "Gap convergence", build_gap_series(iteration_rows, scenario_list))
	write_bar_svg(
		joinpath(comparison_dir, "runtime_seconds.svg"),
		"Runtime comparison",
		["$(row[1])-$(row[2])" for row in summary_rows],
		[Float64(row[8]) for row in summary_rows];
		ylabel = "seconds",
	)
	write_bar_svg(
		joinpath(comparison_dir, "ram_mb.svg"),
		"RAM usage comparison",
		["$(row[1])-$(row[2])" for row in summary_rows],
		[Float64(row[9]) for row in summary_rows];
		ylabel = "MB",
	)
	write_line_svg(joinpath(comparison_dir, "power_balance_sample.svg"), "Power balance sample", power_plot_series)
	write_markdown_report(joinpath(comparison_dir, "benchmark_report.md"), run_id, summary_rows, scenario_list, comparison_dir)
	println("Benchmark outputs saved under:")
	println("  ", benchmark_uc_dir)
	println("  ", benders_dir)
	println("  ", ccg_dir)
	println("  ", comparison_dir)
	return (benchmark_uc_dir = benchmark_uc_dir, benders_dir = benders_dir, ccg_dir = ccg_dir, comparison_dir = comparison_dir)
end

if abspath(PROGRAM_FILE) == @__FILE__
	main_report()
end
