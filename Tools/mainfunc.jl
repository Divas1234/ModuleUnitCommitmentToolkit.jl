
using MathOptInterface
using Printf

include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));

include("define_master_sub_problems/construct_rmp_sub_models.jl")
include("construct_multicuts_lib/construct_multicuts.jl")
include("benderdecomposition_module.jl")

function main()
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data, HydroData, HydroCurve = readxlssheet()

	config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
		DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data, HydroData, HydroCurve
	)

	# Wind scenarios: genscenario only supports up to 24 periods, so we generate in chunks
	CHUNK_SIZE = 24
	NW = 0
	scenarios_nums = 0
	combined_curves = Float64[]
	combined_pmax = Float64[]
	combined_index = Int64[]
	combined_locatebus = Int64[]
	combined_scenarios_prob = Float64[]
	wind_chunk_ref = nothing

	for chunk_start in 1:CHUNK_SIZE:NT
		chunk_end = min(chunk_start + CHUNK_SIZE - 1, NT)
		chunk_NT = chunk_end - chunk_start + 1
		wind_chunk, NW_chunk = genscenario(WindsFreqParam, 1, chunk_NT)
		if NW == 0
			NW = NW_chunk
			scenarios_nums = wind_chunk.scenarios_nums
			combined_pmax = wind_chunk.p_max
			combined_index = wind_chunk.index
			combined_locatebus = wind_chunk.locatebus
			combined_scenarios_prob = [wind_chunk.scenarios_prob]
			combined_curves = wind_chunk.scenarios_curve
			wind_chunk_ref = wind_chunk
		else
			combined_curves = hcat(combined_curves, wind_chunk.scenarios_curve)
		end
	end

	winds = wind_chunk_ref
	winds.scenarios_curve = combined_curves

	scenarios_prob = 1.0 / scenarios_nums
	NS = Int64(scenarios_nums)

	refcost, eachslope = linearizationfuelcurve(units, NG)
	scuc_masterproblem, master_model_struct = bd_masterfunction(
		NT, NB, NG, ND, NC, ND2, NS, units, config_param, scenarios_prob
	)
	scuc_subproblem, sub_model_struct = bd_subfunction(
		NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, winds, loads, lines, DataCentras, stroges, scenarios_prob, config_param
	)

	if config_param.is_ConsiderMultiCUTs == 1
		@info "Generating batch subproblems for multi-cut scenarios"
		batch_scuc_subproblem_struct_dic = get_batch_scuc_subproblems_for_scenario(scuc_subproblem, sub_model_struct, winds, config_param, NS)
		@info "Batch subproblem dictionary created with $(length(batch_scuc_subproblem_struct_dic)) entries"
	else
		@info "Single-cut mode: using single aggregated subproblem"
		batch_scuc_subproblem_struct_dic = OrderedDict(1 => sub_model_struct)
	end

	return scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_struct_dic,
	config_param, units, lines, loads, winds, stroges, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras
end

scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_struct_dic, config_param, units, lines, loads, winds, stroges, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct, batch_scuc_subproblem_struct_dic, winds, config_param, NG, NT, NW, ND, NL)
