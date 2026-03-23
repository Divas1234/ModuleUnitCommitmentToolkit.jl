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
"""

function multiple_bender_decomposition_scuc(
	scuc_masterproblem::Model,
	scuc_subproblem::Model,
	master_model_struct::SCUC_Model,
	batch_scuc_subproblem_dic::OrderedDict{Int64, SCUC_Model},
	winds::wind,
	config_param::config,
)

	# Constants and parameters
	MAXIMUM_ITERATIONS = 10000 # Maximum number of iterations for Bender's decomposition
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
			batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS)
		else
			batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
		end

		# Update bounds
		batch_subproblem_nummber = length(ret_dic)
		if ((config_param.is_ConsiderMultiCUTs == 1) ? batch_subproblem_nummber == NS : batch_subproblem_nummber == Int64(1)) == false
			println("Error: The number of batch_subproblems does not match the expected number.")
			return nothing
		end

		best_upper_bound, best_lower_bound, current_upper_bound, all_subproblems_feasibility_flag = get_upper_lower_bounds(scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound, scenarios_prob) # NOTE - upper bound from subproblem

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

		# Add appropriate Bender's cut based on subproblem feasibility
		for (s, ret) in ret_dic
			if ret.is_feasible == true
				scuc_masterproblem, _ = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
			else
				scuc_masterproblem, _ = add_feasibilitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
			end
			is_feasible = ret.is_feasible
			dual_coeffs = ret.dual_coeffs
			scuc_masterproblem, _ = add_benders_multicuts_constraints!(scuc_masterproblem, sub_model_struct, is_feasible, dual_coeffs, NG, NT, NW, ND, NL)
		end
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
	scenarios_prob::Float64,
)
	# flag = all(s -> s.is_feasible, ret_dic)
	flag = all(ret.is_feasible for ret in values(ret_dic))

	if flag == true
		average_θ = sum(ret.θ for ret in values(ret_dic)) * scenarios_prob
		current_upper_bound = sum(objective_value(scuc_masterproblem) .- value.(scuc_masterproblem[:θ])) + average_θ
		best_upper_bound = min(best_upper_bound, current_upper_bound)[1]
		best_lower_bound = max(best_lower_bound, lower_bound)[1]
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
	if iteration == 1
		println("ITER:", [best_lower_bound best_upper_bound gap])
	end
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
function batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic::OrderedDict, x, u, v, NS = 1)
	ret_dic = OrderedDict{Int64, Any}()
	for s in 1:NS
		ret = solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic[s]::SCUC_Model, x, u, v)
		ret_dic[s] = ret
	end
	return ret_dic
end

"""
`solve_subproblem_with_feasibility_cut(...)`

Fixes the first-stage variables for a single scenario subproblem, evaluates it, and extracts the corresponding dual variables (or Farkas duals if infeasible) to form Benders cuts.
"""

function solve_subproblem_with_feasibility_cut(scuc_subproblem_dic::SCUC_Model, x, u, v)
	scuc_subproblem = scuc_subproblem_dic.model

	# Fix variables in subproblem
	fix.(scuc_subproblem[:x], x; force = true)
	fix.(scuc_subproblem[:u], u; force = true)
	fix.(scuc_subproblem[:v], v; force = true)
	# fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
	# fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

	set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
	set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)
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

	constraints = scuc_subproblem_dic.reformated_constraints
	res_smaller_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._smaller_than, opti_termination_status)
	res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._equal_to, opti_termination_status)
	res_greater_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._greater_than, opti_termination_status)

	final_dual_subproblem_coefficient_results = merge(res_equal_to, res_smaller_than, res_greater_than)

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
			dual_smaller_than_constr_dic = Dict(k => dual.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._smaller_than),
			dual_greater_than_constr_dic = Dict(k => dual.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._greater_than),
			dual_equal_to_constr_dic = Dict(k => dual.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._equal_to),
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
			dual_smaller_than_constr_dic = Dict(k => shadow_price.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._smaller_than),
			dual_greater_than_constr_dic = Dict(k => shadow_price.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._greater_than),
			dual_equal_to_constr_dic = Dict(k => shadow_price.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._equal_to),
		)
	end
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
