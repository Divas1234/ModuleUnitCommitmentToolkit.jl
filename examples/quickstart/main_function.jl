using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))
using ModuleUnitCommitmentToolkit

# Destructure directly from function call for clarity
# Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, storage_data, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, data_center_data = readxlssheet();

# Form input data for the model
config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, data_centers =
    forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, storage_data, data_center_data);

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1);

# Apply boundary conditions
# boundary_condition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses);

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums;

# Call the refactored function
results = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, psses, scenarios_prob, NL)

save_details_scheduled_results(config_param, results; winds = winds)
println("Simulation completed successfully.")
