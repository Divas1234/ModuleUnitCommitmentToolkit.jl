"""
`get_batch_scuc_subproblems_for_scenario(...)`

Generates a collection of scenario-specific subproblems by cloning a base subproblem
and updating its right-hand side (RHS) values to reflect different wind power realizations.

# Arguments

  - `scuc_subproblem`: The template JuMP model for the recourse stage.
  - `sub_model_struct`: Structural metadata for the subproblem.
  - `winds`: Stochastic wind generation data.
  - `NS`: Number of scenarios to generate.

# Returns

  - A dictionary mapping scenario IDs to updated `SCUC_Model` structures.
"""
function get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, sub_model_struct::SCUC_Model, winds::wind, config_param::config, NS::Int64, NT::Int64, NW::Int64)

	# batch_scuc_subproblem_dic = OrderedDict{Int64, Any}()
	batch_scuc_model_strcuture_dic = OrderedDict{Int64, SCUC_Model}()

	@assert config_param.is_ConsiderMultiCUTs == 1

	for s in 1:NS
		# Deep copy both the JuMP model and the tracking structure to ensure scenario independence
		ref_subproblem_struct = deepcopy(sub_model_struct)
		set_optimizer(ref_subproblem_struct.model, Gurobi.Optimizer)
		set_silent(ref_subproblem_struct.model)

		# Extract the wind curve for the current scenario
		scenarios_curve = winds.scenarios_curve[s, :]

		# Update the RHS of wind curtailment constraints in the cloned model
		modified_model, modified_constr = modify_winds_constr_rhs!(ref_subproblem_struct.model, winds, scenarios_curve, NT, NW)

		# Update internal constraint references after modification
		ref_subproblem_struct.constraints.winds_curt_constr = modified_constr

		# Ensure the reformatted constraint dictionary (used for Benders cut generation) is synced
		ref_subproblem_struct.reformated_constraints._smaller_than[:key_winds_curt_constr] = modified_constr

		batch_scuc_model_strcuture_dic[s] = ref_subproblem_struct
	end

	return batch_scuc_model_strcuture_dic
end

function get_batch_scuc_subproblems_for_scenario(
		NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NW::Int64, units::unit, winds::wind, loads::load,
		lines::transmissionline, DataCentras::data_centra, psses::pss, scenarios_prob::Float64, config_param::config,
)
	@assert config_param.is_ConsiderMultiCUTs == 1

	batch_scuc_model_structure_dic = OrderedDict{Int64, SCUC_Model}()
	for s in 1:Int64(winds.scenarios_nums)
		scenario_winds = build_single_scenario_wind(winds, s, scenarios_prob)
		_, scenario_subproblem_struct = bd_subfunction(
			NT, NB, NL, NG, ND, NC, ND2, Int64(1), NW, units, scenario_winds, loads, lines, DataCentras, psses, scenarios_prob, config_param,)
		batch_scuc_model_structure_dic[s] = scenario_subproblem_struct
	end

	return batch_scuc_model_structure_dic
end

"""
`modify_winds_constr_rhs!(...)`

Updates the normalized RHS of wind curtailment constraints based on a specific
scenario realization. This avoids rebuilding the model from scratch for each scenario.
"""
function modify_winds_constr_rhs!(scuc_subproblem, winds, scenarios_curve, NT::Int64, NW::Int64)

	# Retrieve the constraint reference for wind curtailment
	modified_constr = scuc_subproblem[:winds_curt_constr_for_eachscenario]

	# Batch update normalized RHS using vectorized operations: p_wind <= Capacity * Scalar realization
	wind_rhs = vec([scenarios_curve[t] * winds.p_max[w, 1] for t in 1:NT, w in 1:NW])
	set_normalized_rhs.(vec([modified_constr[1, t][w] for t in 1:NT, w in 1:NW]), wind_rhs)

	# Return the flattened constraint vector for easier tracking
	modified_constr = vec(collect(Iterators.flatten(modified_constr)))
	return scuc_subproblem, modified_constr
end

function build_mean_scenario_wind(winds::wind, scenarios_prob::Float64 = 1.0)
	mean_curve = vec(sum(winds.scenarios_curve; dims = 1)) ./ size(winds.scenarios_curve, 1)
	return wind(
		winds.index, winds.locatebus, winds.p_max, scenarios_prob, Int64(1), reshape(mean_curve, 1, length(mean_curve)), winds.Fcmode, winds.Kw, winds.Rw, winds.Mw, winds.Dw, winds.Tw,)
end

function build_single_scenario_wind(winds::wind, scenario_index::Int64, scenarios_prob::Float64)
	return wind(
		winds.index, winds.locatebus, winds.p_max, scenarios_prob, Int64(1), reshape(winds.scenarios_curve[scenario_index, :], 1, size(winds.scenarios_curve, 2)), winds.Fcmode, winds.Kw, winds.Rw, winds.Mw, winds.Dw, winds.Tw,
	)
end

function build_jensen_subproblem_for_mean_scenario(
		NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NW::Int64, units::unit, winds::wind, loads::load, lines::transmissionline, DataCentras::data_centra, psses::pss, config_param::config,
)
	mean_winds = build_mean_scenario_wind(winds, 1.0)
	_, jensen_subproblem_struct = bd_subfunction(
		NT, NB, NL, NG, ND, NC, ND2, Int64(1), NW, units, mean_winds, loads, lines, DataCentras, psses, 1.0, config_param,
	)
	return jensen_subproblem_struct
end
