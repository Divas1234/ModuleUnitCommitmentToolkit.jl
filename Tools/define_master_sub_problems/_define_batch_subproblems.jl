
function get_batch_scuc_subproblems_for_scenario(
		scuc_subproblem::Model,
		sub_model_struct::SCUC_Model,
		winds::wind,
		config_param::config,
		NS::Int64)

	batch_scuc_model_strcuture_dic = OrderedDict{Int64, SCUC_Model}()

	for s in 1:NS
		ref_subproblem = JuMP.copy_model(scuc_subproblem)
		ref_subproblem_struct = deepcopy(sub_model_struct)

		scenarios_curve = winds.scenarios_curve[s, :]
		modified_model, modified_constr = modify_winds_constr_rhs!(ref_subproblem_struct.model, winds, scenarios_curve)
		ref_subproblem_struct.constraints.winds_curt_constr = modified_constr
		ref_subproblem_struct.reformated_constraints._smaller_than[:key_winds_curt_constr] = modified_constr

		batch_scuc_model_strcuture_dic[s] = ref_subproblem_struct
	end

	return batch_scuc_model_strcuture_dic
end

function modify_winds_constr_rhs!(
		scuc_subproblem,
		winds,
		scenarios_curve)
	# Get the constraint by the correct key
	modified_constr = scuc_subproblem[:winds_curt_constr]
	NW = length(winds.p_max)
	NT = length(scenarios_curve)
	set_normalized_rhs.(
		[modified_constr[s, t] for s in 1:size(modified_constr, 1), t in 1:size(modified_constr, 2)],
		scenarios_curve .* sum(winds.p_max)
	)
	modified_constr = vec(collect(Iterators.flatten(modified_constr)))
	return scuc_subproblem, modified_constr
end
