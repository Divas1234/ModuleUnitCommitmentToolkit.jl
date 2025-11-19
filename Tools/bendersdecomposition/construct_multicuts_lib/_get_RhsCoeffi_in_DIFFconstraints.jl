using JuMP
using MathOptInterface

# This file provides utility functions to extract RHS values and variable coefficients
# from different types of constraints (>=, <=, ==) in a JuMP model, and to build
# coefficient vectors for multi-cut Benders decomposition (variables u, v, x).
# Core ideas:
#   1. Detect whether a decision variable at time t or t-1 is present in a given set
#      of constraints (alignment logic) and the ordering pattern of constraints.
#   2. Build dense coefficient vectors (size NG * NT) aligned consistently with
#      chosen ordering (by time-first or generator-first) for each variable type.
#   3. Provide helper routines to safely query MOI backend for bounds or equality.

function get_greater_than_constr_rhs(current_model::Model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).lower)
	end
	return rhs
end

function get_smaller_than_constr_rhs(current_model::Model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).upper)
	end
	return rhs
end

function get_equal_to_constr_rhs(current_model::Model, constr)
	# Extract RHS of equality constraints. Legacy commented code kept for reference.
	# Each constraint's set has a single value field for equality.
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).value)
	end

	return rhs
end

# function get_coeff_from_constr(current_model, constr, target_var)
# 	coeffs = Float64[]
# 	for con in constr
# 		idx = JuMP.index(con)
# 		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
# 		coeffi = get(Dict(term.variable => term.coefficient for term in func.terms), JuMP.index(target_var), 0.0)
# 		push!(coeffs, coeffi)
# 	end
# 	return coeffs, length(coeffs)
# end

function get_v_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	dec_symbol = "v"

	# try
	# 	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	# 	if !isnothing(alignment_cons)
	# 		for t in 2:NT, g in 1:NG

	# 			target_var = ((alignment_cons == 0) ? current_model[:v][g, t] : current_model[:v][g, t - 1])
	# 			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end

	# 		t = 1
	# 		if alignment_cons == 0
	# 			for g in 1:NG
	# 				target_var = current_model[:v][g, t]
	# 				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 				suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 				suit_term = res
	# 			end
	# 		else
	# 			res = 0
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end
	# 	end
	# catch e
	# 	coeffs = zeros(NG * NT, 1)
	# 	sort_order = nothing
	# 	# println("\t v in not in current constraint\t", nam)
	# 	# @info "v coeffs = zeros, default"
	# end

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		# Initialize coefficient matrix (column vector) for variable v.
		# Indexing scheme depends on detected sort_order.
		coeffs = zeros(NG * NT, 1)

		for t ∈ 2:NT, g ∈ 1:NG

			target_var = (
				(alignment_cons == 0) ? current_model[:v][g, t] : current_model[:v][g, t - 1]
			)
			res, _, _ = get_index_in_constraint(
				target_var, current_model, constr, NG, NT, g, t, sort_order
			)
			# Map (g,t) to linear index; pattern determined by sort_order (0: time-major, 1: generator-major)
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		t = 1
		if alignment_cons == 0
			for g ∈ 1:NG
				target_var = current_model[:v][g, t]
				res, _, _ = get_index_in_constraint(
					target_var, current_model, constr, NG, NT, g, t, sort_order
				)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			res = 0
			for g ∈ 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

function get_u_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	dec_symbol = "u"

	# try
	# 	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	# 	if !isnothing(alignment_cons)
	# 		for t in 2:NT, g in 1:NG

	# 			target_var = ((alignment_cons == 0) ? current_model[:u][g, t] : current_model[:u][g, t - 1])
	# 			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end

	# 		t = 1
	# 		if alignment_cons == 0
	# 			for g in 1:NG
	# 				target_var = current_model[:u][g, t]
	# 				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 				suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 				suit_term = res
	# 			end
	# 		else
	# 			res = 0
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end
	# 	end
	# catch e
	# 	coeffs = zeros(NG * NT, 1)
	# 	sort_order = nothing
	# 	# println("\t u in not in current constraint\t", nam)
	# 	# @info "coeffs = zeros, default"
	# end

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		# Initialize coefficient vector for variable u.
		coeffs = zeros(NG * NT, 1)

		for t ∈ 2:NT, g ∈ 1:NG

			target_var = (
				(alignment_cons == 0) ? current_model[:u][g, t] : current_model[:u][g, t - 1]
			)
			res, _, _ = get_index_in_constraint(
				target_var, current_model, constr, NG, NT, g, t, sort_order
			)
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		t = 1
		if alignment_cons == 0
			for g ∈ 1:NG
				target_var = current_model[:u][g, t]
				res, _, _ = get_index_in_constraint(
					target_var, current_model, constr, NG, NT, g, t, sort_order
				)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			res = 0
			for g ∈ 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

function get_x_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	dec_symbol = "x"

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		"""
			We have detected that x appears in at least one of the provided constraints.
			alignment_cons indicates whether constraints reference x at time t (0) or t-1 (1).
			sort_order specifies packing of constraints: 0 => time-major (all generators per time),
			1 => generator-major (all times per generator). We mirror that ordering when building
			the dense coefficient vector so later concatenations stay consistent.
		"""

		coeffs = zeros(NG * NT, 1) # Column vector of size NG*NT storing coeff of x[g,t]

		"""
			Fill coefficients for t ≥ 2. For each (g,t) choose the correct variable index depending
			on alignment_cons. If variable not present a nothing is returned and stored as nothing;
			callers can test and treat nothing as zero if needed.
		"""

		for t ∈ 2:NT, g ∈ 1:NG
			# Select x[g,t] or shifted x[g,t-1] depending on alignment consistency.
			target_var = ((alignment_cons == 0) ? current_model[:x][g, t] : current_model[:x][g, t - 1])
			# Obtain coefficient (res) under detected sort_order; ignore auxiliary returns.
			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
			# Map (g,t) to linear index respecting the detected ordering.
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		# Handle the first time period t = 1 separately (no t-1 exists). If alignment uses time t
		# we query normally; otherwise all coefficients for t=1 default to 0 because constraints
		# only reference the previous time index which is absent.
		t = 1
		if alignment_cons == 0
			for g ∈ 1:NG
				# Direct variable since alignment uses current time index.
				target_var = current_model[:x][g, t]
				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			# When alignment_cons == 1 the constraint references x at t-1; for t=1 that is an
			# out-of-range reference, so coefficient is effectively zero.
			res = 0
			for g ∈ 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		# x does not appear in any provided constraint;
		# returning nothing flags absence so caller can skip combining or treat as a zero vector lazily.
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

# TODO
function check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	g, t = 2, 2
	# Determine whether variable at (g,t) or at (g,t-1) is present in constraint set.
	# Returns alignment_cons:
	#   0 -> uses time t variable
	#   1 -> uses time (t-1) variable
	# nothing -> variable not present at either shift
	# Also returns sort_order inferred from where coefficient found (0 or 1 ordering pattern).
	if dec_symbol == "u"
		target_var = current_model[:u][g, t]
	elseif dec_symbol == "v"
		target_var = current_model[:v][g, t]
	elseif dec_symbol == "x"
		target_var = current_model[:x][g, t]
	end
	_, sort_order_1, is_included_in_current_constr_1 = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, -2)

	if dec_symbol == "u"
		target_var = current_model[:u][g, t - 1]
	elseif dec_symbol == "v"
		target_var = current_model[:v][g, t - 1]
	elseif dec_symbol == "x"
		target_var = current_model[:x][g, t - 1]
	end
	_, sort_order_2, is_included_in_current_constr_2 = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, -2)

	if is_included_in_current_constr_1 || is_included_in_current_constr_2
		alignment_cons = (is_included_in_current_constr_1) ? 0 : 1 # check current variable decision including mode
		sort_order = (is_included_in_current_constr_1) ? sort_order_1 : sort_order_2
	else
		alignment_cons = nothing
		sort_order = nothing
	end
	return alignment_cons, sort_order
end

function get_index_in_constraint(
		target_var, current_model, constr, NG, NT, g, t, order = -2
)
	# Retrieve coefficient of target_var from constraint collection with flexible order modes.
	# Parameters:
	#   order == -2 : auto-detect; try both indexing schemes (time-major and generator-major)
	#   order == -1 : force miss (return nothing)
	#   order == 0  : use time-major ordering (idx = NG * (t-1) + g)
	#   order == 1  : use generator-major ordering (idx = NT * (g-1) + t)
	# Returns (res, sort_order, is_included_in_current_constr)
	if order == -2
		idx = JuMP.index(constr[NG * (t - 1) + g])
		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
		f = get_coeff_from_constr(func, target_var)

		if NT * (g - 1) + t < length(constr)
			im_idx = JuMP.index(constr[NT * (g - 1) + t])
			im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)
			im_f = get_coeff_from_constr(im_func, target_var)
		else
			im_f = nothing
		end

		if !isnothing(f) || !isnothing(im_f)
			# Pick whichever ordering produced a coefficient; establish sort_order accordingly.
			res = (!isnothing(f)) ? f : im_f
			sort_order = (!isnothing(f)) ? 0 : 1
			is_included_in_current_constr = true
		else
			res = nothing
			sort_order = nothing
			is_included_in_current_constr = false
		end

	elseif order == -1
		# Explicitly indicate target_var absent.
		res, sort_order, is_included_in_current_constr = nothing, nothing, false

	elseif order == 0
		# Direct lookup under time-major ordering.
		idx = JuMP.index(constr[NG * (t - 1) + g])
		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
		res = get_coeff_from_constr(func, target_var)
		sort_order = 0
		is_included_in_current_constr = true

	elseif order == 1
		# Direct lookup under generator-major ordering.
		im_idx = JuMP.index(constr[NT * (g - 1) + t])
		im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)
		res = get_coeff_from_constr(im_func, target_var)
		sort_order = 1
		is_included_in_current_constr = true
	end

	return res, sort_order, is_included_in_current_constr
end

function get_coeff_from_constr(func, target_var)
	# Iterate over affine function terms to find coefficient of target_var.
	for term in func.terms
		if term.variable == JuMP.index(target_var)
			# println("Constraint involving x[$g,$t] → Coefficient: ", term.coefficient)
			return term.coefficient
		end
	end
	return nothing
end
