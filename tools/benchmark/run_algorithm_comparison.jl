
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

function run_benders_benchmark(scenario_count::Int64)
	println("Starting benchmark Benders decomposition solver")
	return capture_stdout_to_file(joinpath("output", "benders", "benchmark.log"), () -> begin
		result = solve_benchmark_benders(; scenario_limit = scenario_count)
		println("FINAL STATUS:       ", result.status)
		println("FINAL ITERATIONS:   ", result.iterations)
		println("FINAL UPPER BOUND:  ", result.upper_bound)
		println("FINAL LOWER BOUND:  ", result.lower_bound)
		println("FINAL GAP:          ", result.gap)
		return result
	end)
end

function run_ccg_benchmark(scenario_count::Int64)
	println("Starting benchmark C&CG solver")
	return capture_stdout_to_file(joinpath("output", "ccg", "benchmark.log"), () -> begin
		result = solve_ccg_unit_commitment(; scenario_limit = scenario_count)
		println("FINAL STATUS:       ", result.status)
		println("FINAL ITERATIONS:   ", length(result.history))
		println("FINAL UPPER BOUND:  ", result.upper_bound)
		println("FINAL LOWER BOUND:  ", result.lower_bound)
		println("FINAL GAP:          ", result.gap)
		return result
	end)
end

function run_extensive_form_benchmark(scenario_count::Int64)
	println("Starting benchmark extensive-form UC solver")
	return capture_stdout_to_file(joinpath("output", "benchmark_uc", "benchmark.log"), () -> begin
		result = solve_benchmark_uc(; scenario_limit = scenario_count)
		println("FINAL STATUS:       ", result.status)
		println("FINAL SCENARIOS:    ", length(result.active_scenarios))
		println("FINAL OBJECTIVE:    ", result.upper_bound)
		println("FINAL BEST BOUND:   ", result.lower_bound)
		println("FINAL GAP:          ", result.gap)
		return result
	end)
end
