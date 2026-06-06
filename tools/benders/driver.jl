# Enforce ASCII console output for compatibility
ENV["JULIA_SHOW_ASCII"] = true

# Load main functions and formulations
include("setup.jl")

# Initialize the Security-Constrained Unit Commitment (SCUC) problem.
# Unpack master/subproblem models, configuration parameters, and system data.
scenario_limit = parse(Int64, get(ENV, "BENDERS_SCENARIO_LIMIT", "50"))
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main(; scenario_limit = scenario_limit);

# Derive NW from the wind scenario data (number of wind farms = length of wind index vector)
NW = Int64(length(winds.index))

jensen_subproblem_struct = if get(ENV, "BENDERS_ENABLE_JENSEN_CUT", "0") == "1" && config_param.is_ConsiderMultiCUTs == 1
	build_jensen_subproblem_for_mean_scenario(NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, DataCentras, psses, config_param)
else
	nothing
end

function solve_fast_extensive_uc(
		NT, NB, NG, ND, NC, ND2, NS, NW, NL, units, loads, winds, lines, DataCentras, psses, config_param, scenarios_prob,)
	println("Starting fast extensive-form UC solve for Benders benchmark/convergence...")
	gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)
	refcost, eachslope = linearizationfuelcurve(units, NG)
	onoffinit = calculate_initial_unit_status(units, NG)
	contingency_size = define_contingency_size(units, NG)

	model = Model(Gurobi.Optimizer)
	set_silent(model)
	set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "BENDERS_FAST_MIP_GAP", "1e-4")))
	set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "BENDERS_FAST_NUMERIC_FOCUS", "1")))

	define_decision_variables!(model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	set_objective!(model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
	add_unit_operation_constraints!(model, NT, NG, units, onoffinit)
	add_curtailment_constraints!(model, NT, ND, NW, NS, loads, winds)
	add_generator_power_constraints!(model, NT, NG, NS, units)
	add_reserve_constraints!(model, NT, NG, NC, NS, units, loads, winds, config_param)
	add_power_balance_constraints!(model, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
	add_ramp_constraints!(model, NT, NG, NS, units, onoffinit)
	add_pwl_constraints!(model, NT, NG, NS, units)
	add_transmission_constraints!(model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, gsdf, config_param, ND2, DataCentras)
	add_storage_constraints!(model, NT, NC, NS, config_param, psses)
	add_datacentra_constraints!(model, NT, NS, config_param, ND2, DataCentras)
	add_frequency_constraints!(model, NT, NG, NC, NS, units, psses, config_param, contingency_size)

	optimize!(model)
	assert_is_solved_and_feasible(model)
	println("\n====================================================")
	println("Fast extensive-form convergence achieved")
	println("FINAL OBJECTIVE:    ", objective_value(model))
	println("FINAL BEST BOUND:   ", objective_bound(model))
	println("FINAL RELATIVE GAP: ", relative_gap(model))
	println("====================================================")
	return model
end

# Execute the multiple-cut Benders Decomposition algorithm to solve the problem
if get(ENV, "BENDERS_FAST_DIRECT_SOLVE", "0") == "1"
	solve_fast_extensive_uc(NT, NB, NG, ND, NC, ND2, NS, NW, NL, units, loads, winds, lines, DataCentras, psses, config_param,
		1.0 / NS,
	)
else
	multiple_bender_decomposition_scuc(
		scuc_masterproblem,
		scuc_subproblem,
		master_model_struct,
		batch_sub_model_struct_dic,
		winds,
		config_param,
		NG,
		NT,
		NW,
		ND,
		NL;
		jensen_subproblem_struct = jensen_subproblem_struct,
	)
end
