# Bender Decomposition Framework
# This module provides a framework for solving stochastic optimization problems using Bender's decomposition.
include("define_master_sub_problems/construct_rmp_sub_models.jl")
include("construct_multicuts_lib/construct_multicuts.jl")

using Printf

"""
`multiple_bender_decomposition_scuc(...)`

Executes the multiple-cut Benders Decomposition algorithm to solve the two-stage stochastic SCUC problem.

# Arguments
- `scuc_masterproblem::Model`, `scuc_subproblem::Model`: JuMP models for the master and base subproblems.
- `master_model_struct::SCUC_Model`: Data structure associated with the master problem.
- `batch_scuc_subproblem_dic::OrderedDict`: Dictionary of scenario-specific subproblems.
- `winds::wind`: Stochastic wind scenario data.
- `config_param::config`: Configuration parameters for the algorithm.
- `NG::Int64`: Number of generators.
- `NT::Int64`: Number of time periods.
- `NW::Int64`: Number of wind units.
- `ND::Int64`: Number of loads/demand nodes.
- `NL::Int64`: Number of transmission lines.
"""

function multiple_bender_decomposition_scuc(
	scuc_masterproblem::Model,
	scuc_subproblem::Model,
	master_model_struct::SCUC_Model,
	batch_scuc_subproblem_dic::OrderedDict{Int64, SCUC_Model},
	winds::wind,
	config_param::config,
	NG::Int64,
	NT::Int64,
	NW::Int64,
	ND::Int64,
	NL::Int64,
	;
	jensen_subproblem_struct = nothing,
)

	# Constants and parameters
	MAXIMUM_ITERATIONS = parse(Int64, get(ENV, "BENDERS_MAX_ITERATIONS", "10000")) # Maximum number of iterations for Bender's decomposition
	ABSOLUTE_OPTIMIZATION_GAP = 1e-3 # Absolute gap for optimality
	NUMERICAL_TOLERANCE = 1e-6 # Numerical tolerance for stability

	# Initialize bounds
	best_upper_bound = Inf
	best_lower_bound = -Inf
	NS = Int64(winds.scenarios_nums)
	scenarios_prob = 1.0 / winds.scenarios_nums

	@assert !is_mixed_integer_problem(scuc_subproblem)
	println("Starting (Strengthen) Benders decomposition algorithm")
	println("iteration start ...\n")
	println("====================================================")
	println("ITER \t LOWER_bound \t    UPPER_bound   \t GAP")
	println("----------------------------------------------------")

	# Iteration loop
	for iteration in 1:MAXIMUM_ITERATIONS
		# Solve the master problem
		optimize!(scuc_masterproblem)

		# Check solution status
		assert_is_solved_and_feasible(scuc_masterproblem)

		# Get lower bound from master problem
		lower_bound = objective_value(scuc_masterproblem) # NOTE - lower bound from master problem

		# Extract solution from master problem
		x⁽⁰⁾ = value.(scuc_masterproblem[:x])
		u⁽⁰⁾ = value.(scuc_masterproblem[:u])
		v⁽⁰⁾ = value.(scuc_masterproblem[:v])
		iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

		# Solve subproblem with feasibility cut
		ret_dic = if (config_param.is_ConsiderMultiCUTs == 1)
			batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NG, NT, NS)
		else
			batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NG, NT)
		end

		# Update bounds
		batch_subproblem_nummber = length(ret_dic)
		if ((config_param.is_ConsiderMultiCUTs == 1) ? batch_subproblem_nummber == NS : batch_subproblem_nummber == Int64(1)) == false
			println("Error: The number of batch_subproblems does not match the expected number.")
			return nothing
		end

		best_upper_bound, best_lower_bound, current_upper_bound, all_subproblems_feasibility_flag = get_upper_lower_bounds(scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound) # NOTE - upper bound from subproblem
		if !all_subproblems_feasibility_flag
			feasible_count = count(ret -> ret.is_feasible, values(ret_dic))
			println("ITER ", iteration, ": lower_bound=", lower_bound, ", feasible_subproblems=", feasible_count, "/", length(ret_dic), "; adding feasibility cuts")
		end

		# Check for convergence
		if all_subproblems_feasibility_flag &&
			check_Bender_convergence(
			best_upper_bound,
			best_lower_bound,
			current_upper_bound,
			iteration,
			ABSOLUTE_OPTIMIZATION_GAP,
			NUMERICAL_TOLERANCE,
		) == 1
			break
		end

		if config_param.is_ConsiderMultiCUTs == 1
			candidate_cuts = collect_scenario_cut_candidates(ret_dic, value.(scuc_masterproblem[:θ]))
			add_jensen_cut_if_violated!(scuc_masterproblem, jensen_subproblem_struct, iter_value, NG, NT)
			add_selected_scenario_optimality_cuts!(scuc_masterproblem, candidate_cuts, ret_dic, iter_value)
			if !all_subproblems_feasibility_flag
				add_no_good_cut!(scuc_masterproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
			end
		else
			# Add appropriate Bender's cut based on subproblem feasibility
			for (s, ret) in ret_dic
				# Single-cut mode: use reduced-cost-based standard optimality/feasibility cuts
				if ret.is_feasible == true
					scuc_masterproblem, _ = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
				else
					add_no_good_cut!(scuc_masterproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
				end
			end
		end
	end
end

function collect_scenario_cut_candidates(
	ret_dic::OrderedDict{Int64, Any},
	theta_values;
	tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_CUT_VIOLATION_TOL", "1e-5")),
)
	scenario_ids = collect(keys(ret_dic))
	candidate_slots = Vector{Union{Nothing, Tuple{Float64, Int64}}}(nothing, length(scenario_ids))
	if should_build_cut_candidates_in_parallel(length(scenario_ids))
		Threads.@threads for idx in eachindex(scenario_ids)
			s = scenario_ids[idx]
			ret = ret_dic[s]
			if ret.is_feasible == true
				violation = Float64(ret.θ - theta_values[s])
				if violation > tolerance
					candidate_slots[idx] = (violation, s)
				end
			end
		end
	else
		for idx in eachindex(scenario_ids)
			s = scenario_ids[idx]
			ret = ret_dic[s]
			if ret.is_feasible == true
				violation = Float64(ret.θ - theta_values[s])
				if violation > tolerance
					candidate_slots[idx] = (violation, s)
				end
			end
		end
	end

	candidate_cuts = Tuple{Float64, Int64}[]
	for candidate in candidate_slots
		candidate === nothing && continue
		push!(candidate_cuts, candidate)
	end
	sort!(candidate_cuts; by = cut -> cut[1], rev = true)
	max_cuts = max(0, parse(Int64, get(ENV, "BENDERS_MAX_SCENARIO_CUTS_PER_ITERATION", string(length(candidate_cuts)))))
	if max_cuts < length(candidate_cuts)
		resize!(candidate_cuts, max_cuts)
	end
	return candidate_cuts
end

function should_build_cut_candidates_in_parallel(candidate_count::Int64)
	return candidate_count > 1 && Threads.nthreads() > 1 && get(ENV, "BENDERS_PARALLEL_CUT_CANDIDATES", "1") != "0"
end

function add_selected_scenario_optimality_cuts!(model::Model, selected_candidates, ret_dic, iter_value)
	added = 0
	for (_, s) in selected_candidates
		cut_expr = get_reduced_cost_optimality_cut_expression(model, ret_dic[s], iter_value)
		@constraint(model, model[:θ][s] >= cut_expr)
		added += 1
	end
	if get(ENV, "BENDERS_VERBOSE_CUTS", "0") == "1"
		println("Added scenario optimality cuts: ", added)
	end
	return added
end

function add_violated_scenario_optimality_cuts!(model::Model, candidate_cuts; tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_CUT_VIOLATION_TOL", "1e-5")))
	if isempty(candidate_cuts)
		return 0
	end
	sort!(candidate_cuts; by = cut -> cut[1], rev = true)
	max_cuts = parse(Int64, get(ENV, "BENDERS_MAX_SCENARIO_CUTS_PER_ITERATION", string(length(candidate_cuts))))
	added = 0
	for (violation, s, cut_expr) in candidate_cuts
		if violation <= tolerance || added >= max_cuts
			break
		end
		@constraint(model, model[:θ][s] >= cut_expr)
		added += 1
	end
	return added
end

function add_jensen_cut_if_violated!(model::Model, jensen_subproblem_struct, iter_value, NG::Int64, NT::Int64; tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_JENSEN_CUT_TOL", "1e-5")))
	if jensen_subproblem_struct === nothing
		return nothing
	end
	x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾ = iter_value
	ret = solve_subproblem_with_feasibility_cut(jensen_subproblem_struct, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NG, NT)
	if ret.is_feasible != true
		return nothing
	end
	jensen_cut = get_reduced_cost_optimality_cut_expression(model, ret, iter_value)
	theta_sum = sum(value.(model[:θ]))
	cut_value = value(jensen_cut)
	if cut_value - theta_sum > tolerance
		return @constraint(model, sum(model[:θ]) >= jensen_cut)
	end
	return nothing
end

function get_reduced_cost_optimality_cut_expression(model::Model, ret, iter_value)
	x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾ = iter_value
	return @expression(
		model,
		ret.θ +
		sum(ret.ray_x .* (model[:x] - x⁽⁰⁾)) +
		sum(ret.ray_u .* (model[:u] - u⁽⁰⁾)) +
		sum(ret.ray_v .* (model[:v] - v⁽⁰⁾))
	)
end

function add_no_good_cut!(model::Model, x_value, u_value, v_value; tolerance::Float64 = 0.5)
	x = model[:x]
	u = model[:u]
	v = model[:v]
	return @constraint(
		model,
		sum((x_value[i] >= tolerance) ? (1 - x[i]) : x[i] for i in eachindex(x)) +
		sum((u_value[i] >= tolerance) ? (1 - u[i]) : u[i] for i in eachindex(u)) +
		sum((v_value[i] >= tolerance) ? (1 - v[i]) : v[i] for i in eachindex(v)) >= 1
	)
end

function add_violated_feasibility_cut!(model::Model, cut_expr, cut_value; tolerance::Float64 = 1e-7)
	if cut_value < -tolerance
		return @constraint(model, cut_expr >= 0)
	elseif cut_value > tolerance
		return @constraint(model, cut_expr <= 0)
	else
		@debug "Skipping nearly inactive feasibility cut" cut_value
		return nothing
	end
end

"""
`get_upper_lower_bounds(...)`

Calculates and updates the global upper and lower bounds for the Benders decomposition across all scenarios.

# Returns
- `best_upper_bound`, `best_lower_bound`: Updated global best bounds.
- `current_upper_bound`: The upper bound for the current iteration (missing if any subproblem is infeasible).
- `flag`: A boolean indicating if all subproblems are jointly feasible.
"""

function get_upper_lower_bounds(
	scuc_masterproblem::Model,
	ret_dic::OrderedDict{Int64, Any},
	best_upper_bound,
	best_lower_bound,
	lower_bound,
)
	# flag = all(s -> s.is_feasible, ret_dic)
	flag = all(ret.is_feasible for ret in values(ret_dic))

	if flag == true
		expected_θ = sum(ret.θ for ret in values(ret_dic))
		theta_value = scuc_masterproblem[:θ]
		recourse_estimate = theta_value isa AbstractArray ? sum(value.(theta_value)) : value(theta_value)
		current_upper_bound = objective_value(scuc_masterproblem) - recourse_estimate + expected_θ
		best_upper_bound = min(best_upper_bound, current_upper_bound)
		best_lower_bound = max(best_lower_bound, lower_bound)
	else
		current_upper_bound = missing
	end

	return best_upper_bound, best_lower_bound, current_upper_bound, flag
end

"""
`check_Bender_convergence(...)`

Evaluates the relative gap between the best upper and lower bounds to determine if the algorithm has converged.
Returns 1 if convergence criteria are successfully met.
"""

function check_Bender_convergence(best_upper_bound, best_lower_bound, current_upper_bound, iteration, ABSOLUTE_OPTIMIZATION_GAP, NUMERICAL_TOLERANCE)
	flag = 0
	# Calculate gap with best bounds
	gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + NUMERICAL_TOLERANCE)

	# Print iteration results
	print_iteration([iteration, best_lower_bound, best_upper_bound, gap])

	# Check convergence
	if gap < ABSOLUTE_OPTIMIZATION_GAP || abs(best_upper_bound - best_lower_bound) < NUMERICAL_TOLERANCE
		println("\n")
		println("====================================================")
		println("Convergence achieved - Optimal solution found")
		println("FINAL UPPER BOUND: ", best_upper_bound)
		println("FINAL LOWER BOUND: ", best_lower_bound)
		println("FINAL GAP:         ", gap)
		println("====================================================")
		flag = 1
	end
	return flag
end

"""
`batch_solve_subproblem_with_feasibility_cut(...)`

Solves a batch of scenario subproblems iteratively with fixed first-stage variables.
Returns a dictionary containing feasibility status, objective values, and duals for each scenario.
"""
function batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic::OrderedDict, x, u, v, NG::Int64, NT::Int64, NS::Int64 = 1)
	ret_dic = OrderedDict{Int64, Any}()
	if should_solve_subproblems_in_parallel(NS)
		ret_vec = Vector{Any}(undef, NS)
		Threads.@threads for s in 1:NS
			ret_vec[s] = solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic[s]::SCUC_Model, x, u, v, NG, NT)
		end
		for s in 1:NS
			ret_dic[s] = ret_vec[s]
		end
	else
		for s in 1:NS
			ret = solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic[s]::SCUC_Model, x, u, v, NG, NT)
			ret_dic[s] = ret
		end
	end
	return ret_dic
end

function should_solve_subproblems_in_parallel(NS::Int64)
	return NS > 1 && Threads.nthreads() > 1 && get(ENV, "BENDERS_PARALLEL_SUBPROBLEMS", "1") != "0"
end

function should_collect_dual_coefficients()
	return get(ENV, "BENDERS_COLLECT_DUAL_COEFFS", "0") == "1"
end

function should_collect_dual_details()
	return get(ENV, "BENDERS_COLLECT_DUAL_DETAILS", "0") == "1"
end

function maybe_get_dual_coefficients(scuc_subproblem_dic::SCUC_Model, opti_termination_status::Bool, NT::Int64, NG::Int64)
	if !should_collect_dual_coefficients()
		return Dict{Symbol, dual_subprob_expr_coefficient}()
	end
	constraints = scuc_subproblem_dic.reformated_constraints
	res_smaller_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._smaller_than, opti_termination_status, NT, NG)
	res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._equal_to, opti_termination_status, NT, NG)
	res_greater_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._greater_than, opti_termination_status, NT, NG)
	return merge(res_equal_to, res_smaller_than, res_greater_than)
end

function maybe_get_dual_detail_dictionaries(scuc_subproblem_dic::SCUC_Model, opti_termination_status::Bool)
	if !should_collect_dual_details()
		return (
			smaller = Dict{Symbol, Any}(),
			greater = Dict{Symbol, Any}(),
			equal = Dict{Symbol, Any}(),
		)
	end
	dual_getter = opti_termination_status ? dual : shadow_price
	return (
		smaller = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._smaller_than),
		greater = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._greater_than),
		equal = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._equal_to),
	)
end

"""
`solve_subproblem_with_feasibility_cut(...)`

Fixes the first-stage variables for a single scenario subproblem, evaluates it, and extracts the corresponding dual variables (or Farkas duals if infeasible) to form Benders cuts.
"""

function solve_subproblem_with_feasibility_cut(scuc_subproblem_dic::SCUC_Model, x, u, v, NG::Int64, NT::Int64)
	scuc_subproblem = scuc_subproblem_dic.model

	# Fix variables in subproblem
	fix.(scuc_subproblem[:x], x; force = true)
	fix.(scuc_subproblem[:u], u; force = true)
	fix.(scuc_subproblem[:v], v; force = true)
	# fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
	# fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

	set_optimizer_attribute_if_supported(scuc_subproblem, "InfUnbdInfo", 1)
	set_optimizer_attribute_if_supported(scuc_subproblem, "DualReductions", 0)
	if Threads.nthreads() > 1
		subproblem_threads = parse(Int64, get(ENV, "BENDERS_SUBPROBLEM_SOLVER_THREADS", "1"))
		if subproblem_threads > 0
			set_optimizer_attribute_if_supported(scuc_subproblem, "Threads", subproblem_threads)
		end
	end
	# Optimize subproblem
	optimize!(scuc_subproblem)

	# Check if subproblem is solved and feasible
	opti_termination_status = is_solved_and_feasible(scuc_subproblem; dual = true)

	# constrs_smaller_than = scuc_subproblem_dic.reformated_constraints._smaller_than
	# res_smaller_than = get_dual_constrs_coefficient(
	# 	scuc_subproblem_dic, constrs_smaller_than, opti_termination_status)

	# constrs_equal_to = scuc_subproblem_dic.reformated_constraints._equal_to
	# res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constrs_equal_to, opti_termination_status)

	# constrs_greater_than = scuc_subproblem_dic.reformated_constraints._greater_than
	# res_greater_than = get_dual_constrs_coefficient(
	# 	scuc_subproblem_dic, constrs_greater_than, opti_termination_status)

	final_dual_subproblem_coefficient_results = maybe_get_dual_coefficients(scuc_subproblem_dic, opti_termination_status, NT, NG)
	dual_details = maybe_get_dual_detail_dictionaries(scuc_subproblem_dic, opti_termination_status)

	if opti_termination_status == true
		# Return solution information with scaled duals for numerical stability

		return (
			is_feasible = true,
			θ = objective_value(scuc_subproblem),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v]),

			# NOTE - strong convex duality
			dual_coeffs = final_dual_subproblem_coefficient_results,

			# NOTE - additional dual info
			dual_smaller_than_constr_dic = dual_details.smaller,
			dual_greater_than_constr_dic = dual_details.greater,
			dual_equal_to_constr_dic = dual_details.equal,
		)
	else
		# Get Farkas certificate (dual rays) for infeasibility
		# farkas_dual = MOI.get(scuc_subproblem, MOI.FarkasDual())

		# Scale and process the Farkas certificate
		return (
			is_feasible = false,
			dual_θ = dual_objective_value(scuc_subproblem),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v]),

			# NOTE - farkas_dual process
			dual_coeffs = final_dual_subproblem_coefficient_results,

			# NOTE - additional dual info
			dual_smaller_than_constr_dic = dual_details.smaller,
			dual_greater_than_constr_dic = dual_details.greater,
			dual_equal_to_constr_dic = dual_details.equal,
		)
	end
end

function set_optimizer_attribute_if_supported(model::Model, attribute_name::String, value)
	try
		set_optimizer_attribute(model, attribute_name, value)
	catch err
		@debug "Skipping unsupported optimizer attribute" attribute_name value err
	end
	return nothing
end

"""
`print_iteration(numbers, col_width=15)`

Prints formatted algorithmic progress including iteration count and computed gaps.
"""

function print_iteration(numbers, col_width = 15)
	# f(x) = Printf.@sprintf("%12.4e", x)
	# println(lpad(k, 9), " ", join(f.(args), " "))
	for num in numbers
		print(rpad(@sprintf("%.*g", 6, num), col_width))
	end
	println()
	return nothing
end

"""
`scale_duals(duals; scale_factor=1e3, min_magnitude=1e-10)`

Scales dual values to improve numerical stability in resolving extreme constraint coefficients, explicitly preserving their signs.
"""

function scale_duals(duals; scale_factor = 1e3, min_magnitude = 1e-10)
	scaled_duals = similar(duals)
	for i in eachindex(duals)
		magnitude = abs(duals[i])
		if magnitude > scale_factor
			scaled_duals[i] = sign(duals[i]) * (magnitude / scale_factor)
		elseif magnitude < min_magnitude
			scaled_duals[i] = 0.0
		else
			scaled_duals[i] = duals[i]
		end
	end
	return scaled_duals
end
