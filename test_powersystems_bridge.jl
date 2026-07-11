# ============================================================================
# Test Script for PowerSystems.jl Bridge & Datacenter Mounting
# ============================================================================

println("======================================================================")
println("Running PowerSystems.jl Bridge Integration Test...")
println("======================================================================")

# Include core modules
include("src/environment_config.jl")
include("src/renewableresource_modules/stochasticsimulation.jl")
include("src/read_inputdata_modules/readdatas.jl")
include("src/unitcommitment_model_modules/SUCuccommitmentmodel.jl")

using PowerSystems
using PowerSystemCaseBuilder

# Step 1: Load case "c_sys5" (the standard 5-bus test system)
sys = build_system_from_powersystems("c_sys5")

# Step 2: Define data centers to mount
# We mount data centers on bus 3 (capacity 50 MW) and bus 4 (capacity 30 MW)
# Since the model uses 100 MW base, these are 0.5 p.u. and 0.3 p.u.
dc_buses = [3, 4]
dc_pmax = [0.5, 0.3]

# Optional: Read template frequency parameters from excel to use as override
# or let the bridge use typical dynamic defaults
UnitsFreqParam, WindsFreqParam, _, _, _, _, _, _, _, _, _ = readxlssheet()

# Step 3: Extract and bridge the Sienna system to UC model inputs
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, WindsFreqParam_extracted, bus_to_idx = 
    extract_uc_data_from_powersystems(
        sys,
        data_center_buses = dc_buses,
        data_center_pmax = dc_pmax,
        frequency_params_override = UnitsFreqParam
    )

# Force model configuration to consider data centers and frequency control
config_param.is_ConsiderDataCentra = 1
config_param.is_ConsiderFrequencyControl = 1

println("\n--- Extracted Case Verification ---")
println("Number of Buses: $NB")
println("Number of Generators: $NG")
println("Number of Transmission Lines: $NL")
println("Number of Loads: $ND")
println("Number of Mounted Data Centers: $ND2")
println("Number of BESS units: $NC")
println("Number of Hydro units: $NH")
println("Time steps (NT): $NT")

# Step 4: Generate wind power scenarios from the system components
println("\nGenerating wind power scenarios...")
winds, NW = generate_wind_scenarios_from_system(sys, WindsFreqParam_extracted, 1, NT, bus_to_idx = bus_to_idx)

# Step 5: Solve Stochastic Unit Commitment
println("\nSolving Stochastic Unit Commitment model...")
scenarios_prob = 1.0 / winds.scenarios_nums

results = SUC_scucmodel(
    NT, NB, NG, ND, NC, ND2,
    units, loads, winds, lines, DataCentras, config_param, stroges,
    scenarios_prob, NL, hydros, NH
)

# Step 6: Verify results
if results !== nothing
    println("\n✓ SUCCESS: Optimization solved successfully with Gurobi!")
    save_powerbalance_scheduled_results(units, winds, config_param, results)
    println("Results exported to output/details_schedule_results/")
else
    println("\n✗ ERROR: Optimization failed.")
    exit(1)
end
