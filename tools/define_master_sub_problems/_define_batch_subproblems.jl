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
function get_batch_scuc_subproblems_for_scenario(
		scuc_subproblem::Model,
		sub_model_struct::SCUC_Model,
		winds::wind,
		config_param::config,
		NS::Int64)

	# batch_scuc_subproblem_dic = OrderedDict{Int64, Any}()
	batch_scuc_model_strcuture_dic = OrderedDict{Int64, SCUC_Model}()

	@assert config_param.is_ConsiderMultiCUTs == 1

	for s in 1:NS
		# Deep copy both the JuMP model and the tracking structure to ensure scenario independence
		ref_subproblem = JuMP.copy_model(scuc_subproblem)
		ref_subproblem_struct = deepcopy(sub_model_struct)

		# Extract the wind curve for the current scenario
		scenarios_curve = winds.scenarios_curve[s, :]
		
		# Update the RHS of wind curtailment constraints in the cloned model
		modified_model, modified_constr = modify_winds_constr_rhs!(ref_subproblem_struct.model, winds, scenarios_curve)
		
		# Update internal constraint references after modification
		ref_subproblem_struct.constraints.winds_curt_constr = modified_constr
		
		# Ensure the reformatted constraint dictionary (used for Benders cut generation) is synced
		ref_subproblem_struct.reformated_constraints._smaller_than[:key_winds_curt_constr] = modified_constr

		batch_scuc_model_strcuture_dic[s] = ref_subproblem_struct
	end

	return batch_scuc_model_strcuture_dic
end

"""
`modify_winds_constr_rhs!(...)`

Updates the normalized RHS of wind curtailment constraints based on a specific 
scenario realization. This avoids rebuilding the model from scratch for each scenario.
"""
function modify_winds_constr_rhs!(
		scuc_subproblem,
		winds,
		scenarios_curve)
	
	# Retrieve the constraint reference for wind curtailment
	modified_constr = scuc_subproblem[:winds_curt_constr_for_eachscenario]
	
	# Batch update normalized RHS using vectorized operations: p_wind <= Capacity * Scalar realization
	set_normalized_rhs.(
		[modified_constr[1, t][w] for t in 1:NT, w in 1:NW],
		scenarios_curve .* winds.p_max[:, 1]'
	)
	
	# Return the flattened constraint vector for easier tracking
	modified_constr = vec(collect(Iterators.flatten(modified_constr)))
	return scuc_subproblem, modified_constr
end

