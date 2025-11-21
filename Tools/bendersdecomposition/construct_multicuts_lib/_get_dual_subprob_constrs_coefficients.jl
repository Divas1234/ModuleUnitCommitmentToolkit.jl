"""
	get_dual_constrs_coefficients(
		sub_scuc_dic::SCUC_Model,
		constrs::Dict{Symbol, <:ConstraintRef},
		opti_termination_status::Bool,
		NT::Int, # Pass NT as argument
		NG::Int  # Pass NG as argument
	)::Dict{Symbol, dual_subprob_expr_coefficient}

Calculates the coefficients for constructing dual feasibility or optimality cuts
based on the constraints of a subproblem model.

Args:
	sub_scuc_dic: The SCUC_Model containing the solved JuMP model.
	constrs: A dictionary mapping constraint names (Symbols) to their JuMP ConstraintRef objects.
	opti_termination_status: Boolean indicating if the optimization terminated successfully (true)
							 or if shadow prices should be used (false, e.g., infeasible/unbounded).
	NT: Number of time periods (passed as argument).
	NG: Number of generators (passed as argument).

Returns:
	A dictionary mapping constraint names (Symbols) to their corresponding
	`dual_subprob_expr_coefficient` structs containing coefficients for the dual cut expression.
"""

function get_dual_constrs_coefficient(
		sub_scuc_dic::SCUC_Model, constrs, _is_solved_status::MathOptInterface.TerminationStatusCode
)
	# Initialize dictionary to store dual coefficient results for each constraint
	dual_results = Dict{Symbol, dual_subprob_expr_coefficient}()

	# Extract NT and NG from model variables
	x_var = sub_scuc_dic.model[:x]
	NG, NT = size(x_var)

	# Iterate through all constraints
	for (key, cons) in constrs
		@show key

		# Determine constraint type (EqualTo, LessThan, or GreaterThan) and extract RHS values
		constr_type_str = string(typeof(cons))
		if occursin("EqualTo", constr_type_str)
			rhs_constr = get_equal_to_constr_rhs(sub_scuc_dic.model, cons)
			operator_ass = ones(length(rhs_constr)) .* 1.0  # Equality: positive operator
		elseif occursin("LessThan", constr_type_str)
			rhs_constr = get_smaller_than_constr_rhs(sub_scuc_dic.model, cons)
			operator_ass = ones(length(rhs_constr)) .* -1.0  # LessThan: negative operator for dual formulation
		elseif occursin("GreaterThan", constr_type_str)
			rhs_constr = get_greater_than_constr_rhs(sub_scuc_dic.model, cons)
			operator_ass = ones(length(rhs_constr)) .* 1.0  # GreaterThan: positive operator
		end

		# Extract coefficients for decision variables x, u, v from the constraint
		# Returns coefficient matrices and metadata about variable ordering and alignment
		x_coeff, x_sort_order, x_alignment_flag = get_x_coeff_vectors_from_constr(key, sub_scuc_dic.model, cons, NT, NG)
		u_coeff, u_sort_order, u_alignment_flag = get_u_coeff_vectors_from_constr(key, sub_scuc_dic.model, cons, NT, NG)
		v_coeff, v_sort_order, v_alignment_flag = get_v_coeff_vectors_from_constr(key, sub_scuc_dic.model, cons, NT, NG)

		# Validate that variable orderings are consistent (at most 2 unique ordering schemes)
		# @show x_sort_order, u_sort_order, v_sort_order
		@assert length(Set([x_sort_order, u_sort_order, v_sort_order])) <= 2

		# Retrieve dual coefficients based on optimization termination status
		# if opti_termination_status == true
		# 	dual_coeff = dual.(value)  # Strong duality for optimality cuts (optimal solution)
		# else
		# 	dual_coeff = shadow_price.(value)  # Farkas lemma for feasibility cuts (infeasible/unbounded)
		# end
		dual_coeff = get_subproblem_dual_coefficients(sub_scuc_dic.model, cons, _is_solved_status)

		# Build the dual cut expression coefficient structure
		dual_results[key] = build_dual_cuts_expr_coefficient(;
			rhs = rhs_constr,
			# Extract first column of coefficient matrices if they exist
			x = (!isnothing(x_coeff) ? x_coeff = x_coeff[:, 1] : nothing),
			u = (!isnothing(u_coeff) ? u_coeff = u_coeff[:, 1] : nothing),
			v = (!isnothing(v_coeff) ? v_coeff = v_coeff[:, 1] : nothing),
			# Convert sort orders to Int64 if they exist
			x_sort_order = (!isnothing(x_sort_order) ? Int64(x_sort_order) : nothing),
			u_sort_order = (!isnothing(u_sort_order) ? Int64(u_sort_order) : nothing),
			v_sort_order = (!isnothing(v_sort_order) ? Int64(v_sort_order) : nothing),
			# Preserve alignment flags
			x_alignment_flag = (!isnothing(x_alignment_flag) ? x_alignment_flag : nothing),
			u_alignment_flag = (!isnothing(u_alignment_flag) ? u_alignment_flag : nothing),
			v_alignment_flag = (!isnothing(v_alignment_flag) ? v_alignment_flag : nothing),
			# Store dual coefficients and operator associativity
			dual_coeffVector = dual_coeff,
			operator_associativity = operator_ass
		)
	end
	# Return dictionary containing dual coefficient structures for all constraints
	return dual_results
end

# function get_subproblem_dual_coefficients(model, value, status)
# 	if status ∈ (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)
# 		return dual.(value)
# 	elseif status == MOI.INFEASIBLE
# 		# For infeasible problems, shadow_price returns the Farkas duals (ray)
# 		return shadow_price.(value)
# 	else
# 		return zeros(length(value))
# 	end
# end

function get_subproblem_dual_coefficients(model::JuMP.Model, constraints, status)
	# status = termination_status(model)
	if status ∈ (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)
		return dual.(constraints)
	elseif status == MOI.INFEASIBLE
		if MOI.get(model, MOI.DualStatus()) != MOI.INFEASIBILITY_CERTIFICATE
			@warn "No infeasibility certificate available; enable solver option for Farkas duals."
		end
		backend_model = backend(model)
		farkas_duals = Dict{Symbol, Vector{Float64}}()
		for (k, cons_array) in constrs
			# Ensure cons_array is always iterable
			cons_iter = cons_array isa AbstractVector ? cons_array : [cons_array]
			vals = Float64[]
			for c in cons_iter
				ci = try
					index(c)
				catch
					nothing
				end
				if ci !== nothing && MOI.is_valid(backend_model, ci)
					dual_val = try
						MOI.get(backend_model, MOI.ConstraintDual(), ci)
					catch
						0.0
					end
					push!(vals, dual_val)
				else
					push!(vals, 0.0) # Fallback if certificate not available
				end
			end
			farkas_duals[k] = vals
		end

		return farkas_duals

	else
		error("不支持的状态: $status")
	end
end
