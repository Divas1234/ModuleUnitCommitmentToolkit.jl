# Benders Master & Subproblem Models Entrypoint (Benders 主/子问题模型入口)
# Loads typed model containers, first-stage master, recourse LP subproblem, and scenario/Jensen batch builders.
include("benders_types.jl")
include("master_problem.jl")
include("subproblem.jl")
include("batch_subproblems.jl")

# Export public interfaces for Benders initialization and scenario adaptation
export get_batch_scuc_subproblems_for_scenario, modify_winds_constr_rhs!, build_jensen_subproblem_for_mean_scenario, build_jensen_subproblem_groups
export build_benders_master, build_benders_subproblem, bd_masterfunction, bd_subfunction

# Export foundational model structures and reformatting utilities
export SCUCModel_decision_variables, SCUCModel_objective_function, SCUCModel_constraints, SCUCModel_reformat_constraints
export SCUC_Model
export dual_subprob_expr_coefficient

println("\t-> Benders decomposition [batch] subproblems and master problem successfully loaded.")
