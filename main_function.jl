# ============================================================================
# Main execution script for the Stochastic Unit Commitment (SUC) model.
#
# This script orchestrates the entire unit commitment optimization process:
# 1. Loads environment configuration and required packages
# 2. Reads input data from Excel files
# 3. Formats and processes input data
# 4. Generates wind power scenarios
# 5. Solves the stochastic unit commitment optimization problem
# 6. Saves scheduling results to output files
#
# Usage: julia main_function.jl
# Output: Results are saved to the `output/` directory.
# ============================================================================

include("src/environment_config.jl")
include("src/renewableresource_modules/stochasticsimulation.jl")
include("src/read_inputdata_modules/readdatas.jl")
include("src/unitcommitment_model_modules/SUCuccommitmentmodel.jl")

# ============================================================================
# Step 1: Read input data from Excel sheet
# ============================================================================
println("\n" * "="^80)
println("Step 1: Reading input data from Excel file...")
println("="^80)

UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()

# ============================================================================
# Step 2: Format and process input data for the optimization model
# ============================================================================
println("\n" * "="^80)
println("Step 2: Formatting input data for optimization model...")
println("="^80)

config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras,
hydros = forminputdata(DataGen,
	DataBranch,
	DataLoad,
	LoadCurve,
	GenCost,
	UnitsFreqParam,
	StrogeData,
	Datacentra_Data,
	HydroData,
	HydroCurve)

# Override time periods if needed (default: 24 hours)
NT = 24

# ============================================================================
# Step 3: Generate wind power scenarios
# ============================================================================
println("\n" * "="^80)
println("Step 3: Generating wind power scenarios...")
println("="^80)

winds, NW = genscenario(WindsFreqParam, 1)

# ============================================================================
# Step 4: Run the Stochastic Unit Commitment (SUC-SCUC) model
# ============================================================================
println("\n" * "="^80)
println("Step 4: Running Stochastic Unit Commitment optimization...")
println("="^80)

# Define scenario probability (assuming equal probability for all scenarios)
scenarios_prob = 1.0 / winds.scenarios_nums

# Solve the optimization problem
results = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges,
	scenarios_prob, NL, hydros, NH)
# ============================================================================
# Step 5: Save scheduling results
# ============================================================================
println("\n" * "="^80)
println("Step 5: Saving scheduling results...")
println("="^80)

if results !== nothing
	save_powerbalance_scheduled_results(units, winds, config_param, results)
	println("\n✓ Simulation completed successfully!")
	println("  Results saved to: output/details_schedule_results/")
else
	println("\n✗ Simulation failed. Please check the error messages above.")
	exit(1)
end
