using MathOptInterface
using Printf
using JLD2

# Enable ASCII output for Julia REPL
ENV["JULIA_SHOW_ASCII"] = true
ENV["JULIA_SHOW_ASCII"] = true;
# ENV["GRB_LICENSE_FILE"] = "C:\\Users\\YUAN\\gurobi.lic";
# ENV["GUROBI_HOME"] = "D:\\CommonSoftwares\\ProductiveCodingEditors\\Gurobi\\win64";
ENV["GRB_LOGFILE"] = "";
ENV["GRB_SUPPRESS_STARTUP_MSG"] = "1";
ENV["GRB_NO_ANNOYING_STARTUP_MSG"] = "1";

# Include necessary modules and scripts for environment configuration, stochastic simulation, and data reading
project_root = joinpath(@__DIR__, "..", "..")
include(joinpath(project_root, "src", "environment_config.jl"));
include(joinpath(project_root, "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(project_root, "src", "read_inputdata_modules", "readdatas.jl"));
# include(joinpath(project_root, "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

# Include Benders decomposition related modules
include("define_master_sub_problems/construct_rmp_sub_models.jl")
include("construct_multicuts_lib/construct_multicuts.jl")
include("benderdecomposition_module.jl")

# Main function for Benders decomposition (commented out)
# include("benders_mainfunc.jl");
# function main()
# 	scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units,
# 	lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules();

# 	bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct,
# 		batch_sub_model_struct_dic, winds, config_param)
# end

# Main module function for setting up and running Benders decomposition
function benders_mainfunc_modules()
	# Read all necessary input data from Excel sheets
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data, HydroData, HydroCurve = readxlssheet()

	# Form input data structures for the model
	config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras,
	hydros = forminputdata(
		DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data, HydroData, HydroCurve
	)

	# Set number of time periods (NT) - currently hardcoded
	NT = 24  # TODO: Allow NT (number of periods) to be configurable from input or parameters instead of hardcoding
	# Generate wind scenarios and number of wind scenarios (NW)
	winds, NW = genscenario(WindsFreqParam, 1, NT)

	# Apply boundary conditions (currently commented out)
	# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

	# Run the SUC-SCUC model
	# Define scenario probability (assuming equal probability for all scenarios)
	scenarios_prob = 1.0 / winds.scenarios_nums
	NS = Int64(winds.scenarios_nums)
	# Ensure scenarios_prob is defined (redundant check)
	if !@isdefined(scenarios_prob)
		println("Warning: scenarios_prob not defined, setting to default value")
		scenarios_prob = 1.0 / NS
	end

	# Linearize fuel cost curve for generators
	refcost, eachslope = linearizationfuelcurve(units, NG)
	"""
		for benders decomposition, we need to build both master and subproblem models.
		The master problem handles the unit commitment decisions,
		while the subproblem deals with economic dispatch and other operational constraints.
		HERE, we construct both models using the defined functions with two mode: 1) union mode and 2) intersection mode.
		define config_param.is_ConsiderMultiCUTs = 1 for multi-cuts, and 0 for single-cut.
	"""
	# Build master and subproblem models for Benders decomposition
	# If not using multi-cuts (single-cut mode), set NS = 1
	NS_for_master_sub = (config_param.is_ConsiderMultiCUTs == 1) ? 1 : NS
	scuc_masterproblem, master_model_struct = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS_for_master_sub, units, config_param, scenarios_prob)
	scuc_subproblem, sub_model_struct = bd_subfunction(
		NT, NB, NL, NG, ND, NC, ND2, NS_for_master_sub, NW, units, winds, loads, lines, DataCentras, psses, scenarios_prob, config_param
	)

	# Define the subproblem structure for multi_cuts in benderdecomposition_module.jl
	# Generate batch subproblems based on multi-cut configuration
	if config_param.is_ConsiderMultiCUTs == 1
		@info "Generating batch subproblems for multi-cut scenarios"
		batch_scuc_subproblem_struct_dic = get_batch_scuc_subproblems_for_scenario(scuc_subproblem, sub_model_struct, winds, config_param, NS, NT, NW)
		@info "Batch subproblem dictionary created with $(length(batch_scuc_subproblem_struct_dic)) entries"
	else
		@info "Single-cut mode: using single aggregated subproblem"
		batch_scuc_subproblem_struct_dic = OrderedDict(1 => sub_model_struct)
	end

	# batch_scuc_subproblem_struct_dic = if (config_param.is_ConsiderMultiCUTs == 1)
	# 	@info "Generating batch subproblems for multi-cut scenarios"
	# 	subproblems = get_batch_scuc_subproblems_for_scenario(scuc_subproblem, sub_model_struct, winds, config_param, NS, NT, NW)
	# 	@info "Batch subproblem dictionary created with $(length(subproblems)) entries"
	# 	subproblems
	# else
	# 	@info "Single-cut mode: using single aggregated subproblem"
	# 	OrderedDict(1 => sub_model_struct)
	# end

	# Return all relevant model structures and data
	return scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_struct_dic,
	config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras
end
