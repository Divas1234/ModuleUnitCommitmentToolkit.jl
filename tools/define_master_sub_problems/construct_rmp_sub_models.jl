# Implementation of Master and Subproblem formulations for Benders Decomposition
# Includes logic for Scenario-based stochastic programming and Dual subproblem analysis.

# Include component definitions for the SCUC model structure and optimization stages
include("_define_SCUCmodel_structure.jl")
include("_define_masterproblem.jl")
include("_define_subproblem.jl")
include("_define_batch_subproblems.jl")

# Export public interfaces for Benders initialization and scenario adaptation
export get_batch_scuc_subproblems_for_scenario, modify_winds_constr_rhs!
export bd_masterfunction, bd_subfunction

# Export foundational model structures and reformatting utilities
export SCUCModel_decision_variables, SCUCModel_objective_function, SCUCModel_constraints, SCUCModel_reformat_constraints
export SCUC_Model
export dual_subprob_expr_coefficient

println("\t-> Benders decomposition [batch] subproblems and master problem successfully loaded.")
