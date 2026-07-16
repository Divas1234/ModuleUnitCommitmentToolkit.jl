# ============================================================================
# Utility functions module for the unit commitment model.
#
# This module provides utility functions for:
# - Defining decision variables for the optimization model
# - Linearization techniques (fuel cost curves, power flow)
# - Power flow calculation using linear DC approximation
# - Solver utilities (model solving and result extraction)
# - Obtaining initial boundary conditions
# - Exporting results to text files
# - Saving scheduling results to CSV files
# - Data type conversion and constraint reorganization
#
# Exported Functions:
# - `define_decision_variables!`: Define decision variables in the optimization model
# - `solve_and_extract_results`: Solve the model and extract optimization results
# - `linearizationfuelcurve`: Linearize generator fuel cost curves
# - `linearpowerflow`: Calculate linearized power flow
# - `save_UCresults`, `read_UCresults`: Save/load unit commitment results
# - `savebalance_result`: Save power balance results
# - `convert_constraints_type_to_vector`: Convert constraint types
# - `check_constrainsref_type`: Check constraint reference types
# - `reorginze_constraints_sets`: Reorganize constraint sets
# ============================================================================

include("_define_decision_variables.jl")
include("_linearization.jl")
include("_powerflowcalculation.jl")
include("_solver_utils.jl")
include("_obtain_initial_boundrycontidions.jl")
include("_export_res_to_txtfiles.jl")
include("_saveschedulingresult.jl")
include("_convert_datatype.jl")
include("_reorginze_constr.jl")

export define_decision_variables!,
    solve_and_extract_results,
    linearizationfuelcurve,
    linearpowerflow,
    save_UCresults,
    read_UCresults,
    savebalance_result,
    convert_constraints_type_to_vector,
    check_constrainsref_type,
    reorginze_constraints_sets

println("\t→ Utility functions module loaded and exported.")
