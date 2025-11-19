ENV["JULIA_SHOW_ASCII"] = true
include("benders_mainfunc.jl")
println("\n" * "="^80)
println("Initializing Benders decomposition models...")
println("="^80)

# Initialize all models and data structures
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param,
units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules();

# Derive number of wind units (NW) if not provided separately.
if !@isdefined NW
	# Try common field names; fallback to counting collections; else 0.
	NW = if hasproperty(winds, :NW)
		getfield(winds, :NW)
	elseif hasproperty(winds, :wind_nums)
		getfield(winds, :wind_nums)
	elseif hasproperty(winds, :num_winds)
		getfield(winds, :num_winds)
	elseif hasproperty(winds, :wind_units)
		length(getfield(winds, :wind_units))
	elseif hasproperty(winds, :winds)
		length(getfield(winds, :winds))
	else
		0
	end
end

# Validate initialization results
if scuc_masterproblem === nothing || scuc_subproblem === nothing
	error("Failed to initialize master or subproblem models")
end

if isempty(batch_sub_model_struct_dic)
	@warn "Batch subproblem dictionary is empty - using single-cut mode"
end

# Display initialization status and problem dimensions
# Display initialization summary
println("  ✓ Master problem: $(num_variables(scuc_masterproblem)) variables")
println("  ✓ Subproblem: $(num_variables(scuc_subproblem)) variables")
println("  ✓ Batch subproblems: $(length(batch_sub_model_struct_dic)) scenario(s)")
println("  ✓ Dimensions: NB=$NB, NG=$NG, NL=$NL, ND=$ND, NT=$NT, NS=$NS, NC=$NC, ND2=$ND2, NW=$NW")
println("Running Benders decomposition algorithm...")
println("  Iterating until convergence or maximum iterations reached...")
println("-"^80)

try
	bd_framework(
		scuc_masterproblem,
		scuc_subproblem,
		master_model_struct,
		batch_sub_model_struct_dic,
		winds,
		config_param
	)

	println("\n" * "="^80)
	println("✓ Benders decomposition completed successfully!")
	println("="^80)

catch e
	println("\n" * "="^80)
	println("✗ Benders decomposition failed!")
	println("="^80)
	println("Error details:")
	println("  $e")
	rethrow(e)
end

# DEBUG - Benders Decomposition Framework Function
batch_scuc_subproblem_dic = batch_sub_model_struct_dic
# Constants and parameters
MAXIMUM_ITERATIONS = 10000 # Maximum number of iterations for Bender's decomposition
ABSOLUTE_OPTIMIZATION_GAP = 5e-2 # Absolute gap for optimality
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

optimize!(scuc_masterproblem)
assert_is_solved_and_feasible(scuc_masterproblem)
lower_bound = objective_value(scuc_masterproblem)
x⁽⁰⁾ = JuMP.value.(scuc_masterproblem[:x])
u⁽⁰⁾ = JuMP.value.(scuc_masterproblem[:u])
v⁽⁰⁾ = JuMP.value.(scuc_masterproblem[:v])
iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Solve subproblem(s)
ret_dic = if config_param.is_ConsiderMultiCUTs == 1
	batch_solve_subproblem_with_feasibility_cut(
		batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS
	)
else
	batch_solve_subproblem_with_feasibility_cut(
		batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾
	)
end

batch_scuc_subproblem_dic = batch_sub_model_struct_dic
ret_dic = OrderedDict{Int64, Any}()
s = 1
solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic[s]::SCUC_Model, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

scuc_subproblem_dic = batch_scuc_subproblem_dic[1]
scuc_subproblem = scuc_subproblem_dic.model

# Fix variables in subproblem
fix.(scuc_subproblem[:x], x⁽⁰⁾; force = true)
fix.(scuc_subproblem[:u], u⁽⁰⁾; force = true)
fix.(scuc_subproblem[:v], v⁽⁰⁾; force = true)
# fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
# fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)
# Optimize subproblem
optimize!(scuc_subproblem)

# Check if subproblem is solved and feasible
opti_termination_status = is_solved_and_feasible(scuc_subproblem; dual = true)

constraints = scuc_subproblem_dic.reformated_constraints
res_smaller_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._smaller_than, opti_termination_status)
res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._equal_to, opti_termination_status)
res_greater_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._greater_than, opti_termination_status)

# Initialize dictionary to store dual coefficient results for each constraint
dual_results = Dict{Symbol, dual_subprob_expr_coefficient}()
constraints._smaller_than
constrs = constraints._smaller_than
# Iterate through all constraints
key, value = constrs[:key_transmissionline_powerflow_upbound_constr]
key = :key_transmissionline_powerflow_upbound_constr
value = constrs[key]
current_model = scuc_subproblem_dic
constr_type_str = string(typeof(value))
if occursin("EqualTo", constr_type_str)
	rhs_constr = get_equal_to_constr_rhs(current_model.model, value)
	operator_ass = ones(length(rhs_constr)) .* 1.0  # Equality: positive operator
elseif occursin("LessThan", constr_type_str)
	rhs_constr = get_smaller_than_constr_rhs(current_model.model, value)
	operator_ass = ones(length(rhs_constr)) .* -1.0  # LessThan: negative operator for dual formulation
elseif occursin("GreaterThan", constr_type_str)
	rhs_constr = get_greater_than_constr_rhs(current_model.model, value)
	operator_ass = ones(length(rhs_constr)) .* 1.0  # GreaterThan: positive operator
end

rhs_constr = get_smaller_than_constr_rhs(current_model.model, value)

x_coeff, x_sort_order, x_alignment_flag = get_x_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
u_coeff, u_sort_order, u_alignment_flag = get_u_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
v_coeff, v_sort_order, v_alignment_flag = get_v_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)

for (key, value) in constrs
	# Determine constraint type (EqualTo, LessThan, or GreaterThan) and extract RHS values
	constr_type_str = string(typeof(value))
	if occursin("EqualTo", constr_type_str)
		rhs_constr = get_equal_to_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* 1.0  # Equality: positive operator
	elseif occursin("LessThan", constr_type_str)
		rhs_constr = get_smaller_than_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* -1.0  # LessThan: negative operator for dual formulation
	elseif occursin("GreaterThan", constr_type_str)
		rhs_constr = get_greater_than_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* 1.0  # GreaterThan: positive operator
	end

	# Extract coefficients for decision variables x, u, v from the constraint
	# Returns coefficient matrices and metadata about variable ordering and alignment
	x_coeff, x_sort_order, x_alignment_flag = get_x_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
	# u_coeff, u_sort_order, u_alignment_flag = get_u_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
	# v_coeff, v_sort_order, v_alignment_flag = get_v_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)

	# # Validate that variable orderings are consistent (at most 2 unique ordering schemes)
	# # @show x_sort_order, u_sort_order, v_sort_order
	# @assert length(Set([x_sort_order, u_sort_order, v_sort_order])) <= 2

	# # Retrieve dual coefficients based on optimization termination status
	# if opti_termination_status == true
	# 	dual_coeff = dual.(value)  # Strong duality for optimality cuts (optimal solution)
	# else
	# 	dual_coeff = shadow_price.(value)  # Farkas lemma for feasibility cuts (infeasible/unbounded)
	# end

	# # Build the dual cut expression coefficient structure
	# dual_results[key] = build_dual_cuts_expr_coefficient(;
	# 	rhs = rhs_constr,
	# 	# Extract first column of coefficient matrices if they exist
	# 	x = (!isnothing(x_coeff) ? x_coeff = x_coeff[:, 1] : nothing),
	# 	u = (!isnothing(u_coeff) ? u_coeff = u_coeff[:, 1] : nothing),
	# 	v = (!isnothing(v_coeff) ? v_coeff = v_coeff[:, 1] : nothing),
	# 	# Convert sort orders to Int64 if they exist
	# 	x_sort_order = (!isnothing(x_sort_order) ? Int64(x_sort_order) : nothing),
	# 	u_sort_order = (!isnothing(u_sort_order) ? Int64(u_sort_order) : nothing),
	# 	v_sort_order = (!isnothing(v_sort_order) ? Int64(v_sort_order) : nothing),
	# 	# Preserve alignment flags
	# 	x_alignment_flag = (!isnothing(x_alignment_flag) ? x_alignment_flag : nothing),
	# 	u_alignment_flag = (!isnothing(u_alignment_flag) ? u_alignment_flag : nothing),
	# 	v_alignment_flag = (!isnothing(v_alignment_flag) ? v_alignment_flag : nothing),
	# 	# Store dual coefficients and operator associativity
	# 	dual_coeffVector = dual_coeff,
	# 	operator_associativity = operator_ass
	# )
end

dec_symbol = "x"
typeof(current_model)

g, t = 2, 2
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

# -------------------------------

alignment_cons, sort_order = check_var_alignment_with_constraints(scuc_subproblem_dic, value, NG, NT, dec_symbol)

if !isnothing(alignment_cons)
	coeffs = zeros(NG * NT, 1)

	for t ∈ 2:NT, g ∈ 1:NG

		target_var = (
			(alignment_cons == 0) ? current_model[:x][g, t] : current_model[:x][g, t - 1]
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
			target_var = current_model[:x][g, t]
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

# ---

for (key, value) in constrs
	@show key
	@show value
	# Determine constraint type (EqualTo, LessThan, or GreaterThan) and extract RHS values
	constr_type_str = string(typeof(value))
	if occursin("EqualTo", constr_type_str)
		rhs_constr = get_equal_to_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* 1.0  # Equality: positive operator
	elseif occursin("LessThan", constr_type_str)
		rhs_constr = get_smaller_than_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* -1.0  # LessThan: negative operator for dual formulation
	elseif occursin("GreaterThan", constr_type_str)
		rhs_constr = get_greater_than_constr_rhs(current_model.model, value)
		operator_ass = ones(length(rhs_constr)) .* 1.0  # GreaterThan: positive operator
	end

	# @show rhs_constr
	# @show operator_ass
	# Extract coefficients for decision variables x, u, v from the constraint
	# # Returns coefficient matrices and metadata about variable ordering and alignment
	# x_coeff, x_sort_order, x_alignment_flag = get_x_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
	# u_coeff, u_sort_order, u_alignment_flag = get_u_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
	# v_coeff, v_sort_order, v_alignment_flag = get_v_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)

	# dec_symbol = "x"

	# alignment_cons, sort_order = check_var_alignment_with_constraints(scuc_subproblem_dic, value, NG, NT, dec_symbol)

	# if !isnothing(alignment_cons)
	# 	coeffs = zeros(NG * NT, 1)

	# 	for t ∈ 2:NT, g ∈ 1:NG

	# 		target_var = (
	# 			(alignment_cons == 0) ? current_model[:x][g, t] : current_model[:x][g, t - 1]
	# 		)
	# 		res, _, _ = get_index_in_constraint(
	# 			target_var, current_model, constr, NG, NT, g, t, sort_order
	# 		)
	# 		idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
	# 		coeffs[idx, 1] = res
	# 	end

	# 	t = 1
	# 	if alignment_cons == 0
	# 		for g ∈ 1:NG
	# 			target_var = current_model[:x][g, t]
	# 			res, _, _ = get_index_in_constraint(
	# 				target_var, current_model, constr, NG, NT, g, t, sort_order
	# 			)
	# 			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
	# 			coeffs[idx, 1] = res
	# 		end
	# 	else
	# 		res = 0
	# 		for g ∈ 1:NG
	# 			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
	# 			coeffs[idx, 1] = res
	# 		end
	# 	end
	# else
	# 	coeffs = nothing
	# 	sort_order = nothing
	# end

end

