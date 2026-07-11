# ======================================================================
# PowerSystems.jl Bridge Integration Test for Revised Branch
# ======================================================================
println("======================================================================")
println("Running PowerSystems.jl Bridge Integration Test on Revised Branch...")
println("======================================================================")

# Load dependencies
include("src/environment_config.jl")
include("src/renewables/stochastic_simulation.jl")
include("src/input_data/readers.jl")
include("src/unit_commitment/unit_commitment_model.jl")

using PowerSystems
using PowerSystemCaseBuilder

# Step 1: Build the native PowerSystems case
case_name = "c_sys5"
sys = build_system_from_powersystems(case_name)

# Step 2: Set data center locations and capacities
dc_buses = [3, 4]
dc_pmax = [0.5, 0.3]

# Step 3: Load frequency parameters override
excel_units_freq = readxlssheet()[1]

# Step 4: Extract and format UC data using Unified loader
println("Loading and converting Sienna system...")
data = load_uc_data(
    use_powersystems = true,
    sys = sys,
    data_center_buses = dc_buses,
    data_center_pmax = dc_pmax,
    frequency_params_override = excel_units_freq
)

config_param = data.config_param
units = data.units
lines = data.lines
loads = data.loads
winds = data.winds
stroges = data.psses
DataCentras = data.DataCentras
NB = data.NB
NG = data.NG
NL = data.NL
ND = data.ND
NT = data.NT
NC = data.NC
ND2 = data.ND2
scenarios_prob = data.full_scenario_probability

# Verify conversion output properties
println("\n--- Extracted Case Verification ---")
println("Number of Buses: $NB")
println("Number of Generators: $NG")
println("Number of Transmission Lines: $NL")
println("Number of Loads: $ND")
println("Number of Mounted Data Centers: $ND2")
println("Number of BESS units: $NC")
println("Time steps (NT): $NT")

# Step 5: Solve Stochastic Unit Commitment model
println("\nSolving Stochastic Unit Commitment model...")
results = SUC_scucmodel(
    NT, NB, NG, ND, NC, ND2,
    units, loads, winds, lines, DataCentras, config_param, stroges,
    scenarios_prob, NL
)

if results !== nothing
    println("\n✓ SUCCESS: Optimization solved successfully with Gurobi on Revised Branch!")
    save_details_scheduled_results(config_param, results)
else
    error("✗ ERROR: Optimization failed.")
end
