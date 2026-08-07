# ============================================================================
# Benders Decomposition Debug Script
#
# This script is used to debug and test the Benders decomposition algorithm
# for solving the stochastic unit commitment (SUC) problem.
#
# The Benders decomposition algorithm decomposes the two-stage stochastic
# optimization problem into:
# - Master problem: First-stage decisions (unit commitment)
# - Subproblems: Second-stage decisions (economic dispatch) for each scenario
#
# Algorithm Overview:
# 1. Initialize master and subproblem models
# 2. Iteratively solve master problem and subproblems
# 3. Generate Benders cuts (optimality and feasibility cuts)
# 4. Add cuts to master problem and repeat until convergence
#
# Usage:
#   julia --project=. debug_bd.jl
#
# Output:
#   - Console output showing iteration progress and convergence
#   - Optimization results from the Benders decomposition algorithm
# ============================================================================

ENV["JULIA_SHOW_ASCII"] = true

# ============================================================================
# Step 1: Load Required Modules
# ============================================================================
# Include the main Benders decomposition function module
# This module contains:
#   - benders_mainfunc_modules(): Initializes master and subproblem models
#   - Returns all necessary data structures and models for the algorithm
include("benders_mainfunc.jl")

# ============================================================================
# Step 2: Initialize Benders Decomposition Models
# ============================================================================
# Call the main function to set up all models and data structures
#
# Returns:
#   - scuc_masterproblem: JuMP model for the master problem (first-stage decisions)
#   - scuc_subproblem: JuMP model for the base subproblem (second-stage decisions)
#   - master_model_struct: Structured representation of master problem constraints
#   - sub_model_struct: Structured representation of subproblem constraints
#   - batch_sub_model_struct_dic: Dictionary of subproblems for each scenario (multi-cut mode)
#   - config_param: Configuration parameters for the optimization model
#   - units: Generator unit data structure
#   - lines: Transmission line data structure
#   - loads: Load data structure
#   - winds: Wind power scenario data structure
#   - psses: Energy storage system data structure
#   - NB: Number of buses in the network
#   - NG: Number of generators
#   - NL: Number of transmission lines
#   - ND: Number of loads
#   - NS: Number of scenarios
#   - NT: Number of time periods
#   - NC: Number of energy storage units
#   - ND2: Number of data centers
#   - DataCentras: Data center data structure
println("\n" * "="^80)
println("Initializing Benders decomposition models...")
println("="^80)

# Initialize all models and data structures
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic,
config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules()

# Validate initialization results
if scuc_masterproblem === nothing || scuc_subproblem === nothing
	error("Failed to initialize master or subproblem models")
end

if isempty(batch_sub_model_struct_dic)
	@warn "Batch subproblem dictionary is empty - using single-cut mode"
end

# Display initialization status and problem dimensions
println("  ✓ Master problem model initialized")
println("    - Variables: $(num_variables(scuc_masterproblem))")
println("  ✓ Subproblem model initialized")
println("    - Variables: $(num_variables(scuc_subproblem))")
println("  ✓ Batch subproblems: $(length(batch_sub_model_struct_dic)) scenario(s)")
println("  ✓ Problem dimensions:")
println("    - Buses (NB): $NB")
println("    - Generators (NG): $NG")
println("    - Transmission lines (NL): $NL")
println("    - Loads (ND): $ND")
println("    - Time periods (NT): $NT")
println("    - Scenarios (NS): $NS")
println("    - Storage units (NC): $NC")
println("    - Data centers (ND2): $ND2")
println("="^80)

# ============================================================================
# Step 3: Run Benders Decomposition Algorithm
# ============================================================================
# Execute the Benders decomposition framework to solve the stochastic UC problem
#
# The algorithm will:
#   1. Solve the master problem to get first-stage decisions (unit commitment)
#   2. Fix first-stage decisions and solve subproblems for each scenario
#   3. Generate Benders cuts based on subproblem solutions
#   4. Add cuts to master problem and iterate until convergence
#
# Convergence criteria:
#   - Optimality gap (upper bound - lower bound) < tolerance
#   - Maximum number of iterations reached
#
# Arguments:
#   - scuc_masterproblem: Master problem model
#   - scuc_subproblem: Base subproblem model
#   - master_model_struct: Master problem structure for constraint management
#   - batch_sub_model_struct_dic: Dictionary of scenario-specific subproblems
#   - winds: Wind power scenario data
#   - config_param: Configuration parameters
println("\n" * "="^80)
println("Running Benders decomposition algorithm...")
println("="^80)
println("  This may take several minutes depending on problem size...")
println("  Algorithm will iterate until convergence or maximum iterations reached")
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
