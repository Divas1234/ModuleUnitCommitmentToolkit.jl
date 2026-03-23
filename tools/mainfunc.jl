# Enforce ASCII console output for cross-platform compatibility

ENV["JULIA_SHOW_ASCII"] = true

# Load environment configurations, simulation modules, and data readers
include(joinpath(pwd(), "src", "environment_config.jl"))
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"))
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"))
# include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"))

# Load Benders Decomposition formulation and multi-cut libraries

include("define_master_sub_problems/construct_rmp_sub_models.jl")
include("construct_multicuts_lib/construct_multicuts.jl")
include("benderdecomposition_module.jl")

"""
	`main()`

	Main execution pipeline mapping raw data to the stochastic SCUC formulation.
	Reads system data, defines wind scenarios, and initializes the master and subproblem elements for Benders Decomposition.

	# Returns
	A tuple containing all formulated JuMP models, internal data structures, and topological scenario dimensions.
"""

function main()
	# Read raw system data from Excel sheets
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

	# Structure matrices and topological parameters for the SCUC model formulation
	config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

	# Generate stochastic wind scenarios
	winds, NW = genscenario(WindsFreqParam, 1)

	# Apply unit and node boundary limit conditions (Reserved function)
	# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

	# Define assumed scenario probability (assuming equal distribution)
	scenarios_prob = 1.0 / winds.scenarios_nums
	NS = Int64(winds.scenarios_nums)

	# Linearize generator fuel cost curves
	refcost, eachslope = linearizationfuelcurve(units, NG)

	# Construct the Benders Master Problem algebraically
	scuc_masterproblem, master_model_struct = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS, units, config_param, scenarios_prob)

	# Construct the Benders Base Subproblem algebraically
	scuc_subproblem, sub_model_struct = bd_subfunction(NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, winds, loads, lines, DataCentras, psses, scenarios_prob, config_param)

	# Fallback initialization validation for scenario probabilities
	if !@isdefined(scenarios_prob)
		println("Warning: scenarios_prob not defined, forcing to default uniform value")
		scenarios_prob = 1.0 / NS
	end

	# Initialize dictionaries for decoupled scenario subsets based on iteration cuts
	if config_param.is_ConsiderMultiCUTs == 1
		# Create discrete subproblem instances explicitly for multi-cut logic evaluation
		batch_scuc_subproblem_struct_dic = OrderedDict{Int64, SCUC_Model}()
		batch_scuc_subproblem_struct_dic = if (config_param.is_ConsiderMultiCUTs == 1)
			get_batch_scuc_subproblems_for_scenario(scuc_subproblem, sub_model_struct, winds, config_param, NS)
		else
			OrderedDict(1 => sub_model_struct)
		end
		@info "Generating batch subproblems for multi-cut scenarios"
		@info "Batch subproblem dictionary successfully created with $(length(batch_scuc_subproblem_struct_dic)) independent entries."
	else
		@info "Single subproblem mode activated, skipping batch SCUC model multicut initialization."
	end

	# Output constructed structs, models, constraints, and optimization environment settings
	return scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_struct_dic, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras
end
