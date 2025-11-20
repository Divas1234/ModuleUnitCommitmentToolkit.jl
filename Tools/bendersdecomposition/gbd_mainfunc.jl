ENV["JULIA_SHOW_ASCII"] = true;
ENV["GRB_LICENSE_FILE"] = "C:\\Users\\YUAN\\gurobi.lic";
ENV["GUROBI_HOME"] = "D:\\CommonSoftwares\\ProductiveCodingEditors\\Gurobi\\win64";
ENV["GRB_LOGFILE"] = "";
ENV["GRB_SUPPRESS_STARTUP_MSG"] = "1";
ENV["GRB_NO_ANNOYING_STARTUP_MSG"] = "1";
using MathOptInterface, JuMP
const MOI = MathOptInterface
const gurobi_env = redirect_stderr(devnull) do
	Gurobi.Env()
end

include("benders_mainfunc.jl")
println("\n" * "="^80)
println("Initializing Benders decomposition models...")
println("="^80)

# Initialize all models and data structures
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param,
units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules();

# sub_model_struct.constraints
# batch_sub_model_struct_dic[1].constraints


# Validate initialization results
if scuc_masterproblem === nothing || scuc_subproblem === nothing
	error("Failed to initialize master or subproblem models")
end

if isempty(batch_sub_model_struct_dic)
	@warn "Batch subproblem dictionary is empty - using single-cut mode"
end

try
	bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct, batch_sub_model_struct_dic, winds, config_param)
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

#TODO DEBUG - Context: Path: tools/bendersdecomposition/construct_multicuts_lib/_get_dual_subprob_constrs_coefficients.jl

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
# for iteration ∈ 1:MAXIMUM_ITERATIONS
iteration = 1
# Solve the master problem
optimize!(scuc_masterproblem)

# Check solution status
assert_is_solved_and_feasible(scuc_masterproblem)

# Get lower bound from master problem
lower_bound = objective_value(scuc_masterproblem) # NOTE - lower bound from master problem

# To load/read the saved data, use:
# using JLD2
tem_path = "D:\\GithubClonefiles\\module_unitcommitment\\tools\\bendersdecomposition\\"
data = JLD2.load(joinpath(tem_path, "iter_value_iteration_3.jld2"))
iteration_loaded = data["iteration"]
x⁽⁰⁾ = data["x"]
u⁽⁰⁾ = data["u"]
v⁽⁰⁾ = data["v"]

# Extract solution from master problem
# x⁽⁰⁾ = value.(scuc_masterproblem[:x])
# u⁽⁰⁾ = value.(scuc_masterproblem[:u])
# v⁽⁰⁾ = value.(scuc_masterproblem[:v])
iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Solve subproblem with feasibility cut
# batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS)
batch_scuc_subproblem_dic = batch_sub_model_struct_dic
ret_dic = OrderedDict{Int64, Any}()
for s ∈ 1:NS
	ret = solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic[s]::SCUC_Model, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
	ret_dic[s] = ret
end

scuc_subproblem_dic = batch_scuc_subproblem_dic[1]::SCUC_Model
new_scuc_subproblem = copy_scuc_subproblem(scuc_subproblem_dic)


batch_scuc_subproblem_dic[1].constraints

scuc_subproblem_dic.constraints

new_scuc_subproblem.model
new_scuc_subproblem.reformated_constraints
new_scuc_subproblem.constraints
new_scuc_subproblem.objective_function

# Fix variables in subproblem
fix.(new_scuc_subproblem.model[:x], x⁽⁰⁾; force = true)
fix.(new_scuc_subproblem.model[:u], u⁽⁰⁾; force = true)
fix.(new_scuc_subproblem.model[:v], v⁽⁰⁾; force = true)

# Optimize subproblem
optimize!(new_scuc_subproblem.model)

# Check if subproblem is solved and feasible
# opti_termination_status = is_solved_and_feasible(scuc_subproblem; dual = true)

solved_status = termination_status(new_scuc_subproblem.model)

constraints = new_scuc_subproblem.reformated_constraints
res_smaller_than = get_dual_constrs_coefficient(new_scuc_subproblem, constraints._smaller_than, solved_status)
res_equal_to = get_dual_constrs_coefficient(new_scuc_subproblem, constraints._equal_to, solved_status)
res_greater_than = get_dual_constrs_coefficient(new_scuc_subproblem, constraints._greater_than, solved_status)
final_dual_subproblem_coefficient_results = merge(res_equal_to, res_smaller_than, res_greater_than)

# Initialize dictionary to store dual coefficient results for each constraint
dual_results = Dict{Symbol, dual_subprob_expr_coefficient}()

# Extract NT and NG from model variables
x_var = sub_scuc_dic.model[:x]
NG, NT = size(x_var)

# Iterate through all constraints

key = :key_transmissionline_powerflow_upbound_constr

constrs = new_scuc_subproblem.reformated_constraints
sub_scuc_dic = new_scuc_subproblem
cons = constrs[key]

constrs[:key_units_maxpower_constr]





summary(scuc_subproblem_dic) |> println
summary(constrs) |> println
keys(scuc_subproblem_dic) |> println

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

# Solve subproblem with feasibility cut
ret_dic = (config_param.is_ConsiderMultiCUTs == 1) ?
		  batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS) :
		  batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Update bounds
batch_subproblem_nummber = length(ret_dic)
if (
	(config_param.is_ConsiderMultiCUTs == 1) ? batch_subproblem_nummber == NS :
	batch_subproblem_nummber == Int64(1)
) == false
	println(
		"Error: The number of batch_subproblems does not match the expected number.",
	)
	return nothing
end

best_upper_bound, best_lower_bound, current_upper_bound, all_subproblems_feasibility_flag = get_upper_lower_bounds(
	scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound, scenarios_prob
) # NOTE - upper bound from subproblem

# Check for convergence
if all_subproblems_feasibility_flag &&
   check_Bender_convergence(
	best_upper_bound, best_lower_bound, current_upper_bound, iteration, ABSOLUTE_OPTIMIZATION_GAP, NUMERICAL_TOLERANCE
) == 1
	# break
end

# Add appropriate Bender's cut based on subproblem feasibility
for (s, ret) in ret_dic
	if ret.is_feasible == true
		scuc_masterproblem, _ = add_optimitycut_constraints!(
			scuc_masterproblem,
			batch_scuc_subproblem_dic[s],
			ret,
			iter_value
		)
	else
		scuc_masterproblem, _ = add_feasibilitycut_constraints!(
			scuc_masterproblem,
			batch_scuc_subproblem_dic[s],
			ret,
			iter_value
		)
	end
end
