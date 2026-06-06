# Column-and-Constraint Generation (C&CG) driver for finite-scenario SCUC.
#
# The master solves an extensive-form UC over a dynamically selected scenario
# subset. The separation step fixes the first-stage unit commitment and solves
# single-scenario recourse MIPs over the candidate scenario pool, then adds the
# worst uncovered scenarios to the master.

include(joinpath(@__DIR__, "..", "benders", "setup.jl"))

function solve_ccg_unit_commitment(; scenario_limit::Int64 = 20)
	data = load_ccg_data(scenario_limit)
	initial_count = clamp(parse(Int64, get(ENV, "CCG_INITIAL_SCENARIOS", string(min(3, data.NS)))), 1, data.NS)
	scenarios_per_iteration = max(1, parse(Int64, get(ENV, "CCG_SCENARIOS_PER_ITERATION", "2")))
	max_iterations = parse(Int64, get(ENV, "CCG_MAX_ITERATIONS", "50"))
	gap_tolerance = parse(Float64, get(ENV, "CCG_GAP_TOL", "1e-3"))
	numerical_tolerance = 1e-6

	selected = choose_initial_ccg_scenarios(data, initial_count)
	best_upper_bound = Inf
	best_lower_bound = -Inf
	best_model = nothing
	best_evaluation = nothing

	println("Starting C&CG unit commitment solver")
	println("candidate scenarios: ", data.NS)
	println("initial scenarios:   ", selected)
	println("parallel recourse:   ", ccg_parallel_recourse_enabled(), " (Julia threads: ", Threads.nthreads(), ")")
	println("====================================================")
	println("ITER \t ACTIVE \t LOWER_bound \t UPPER_bound \t GAP \t ADDED")
	println("----------------------------------------------------")

	for iteration in 1:max_iterations
		master_model = solve_ccg_master(data, selected)
		first_stage = extract_first_stage_solution(master_model)
		evaluation = evaluate_ccg_recourse_pool(data, first_stage)

		current_lower_bound = objective_bound(master_model)
		current_upper_bound = first_stage.cost + sum(result.recourse_cost for result in values(evaluation))
		best_lower_bound = max(best_lower_bound, current_lower_bound)
		if current_upper_bound < best_upper_bound
			best_upper_bound = current_upper_bound
			best_model = master_model
			best_evaluation = evaluation
		end

		gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance)
		inactive_scenarios = setdiff(collect(1:data.NS), selected)
		scenarios_to_add = choose_ccg_scenarios_to_add(evaluation, inactive_scenarios, scenarios_per_iteration)
		print_ccg_iteration(iteration, length(selected), best_lower_bound, best_upper_bound, gap, scenarios_to_add)

		if gap <= gap_tolerance || isempty(scenarios_to_add)
			println("\n====================================================")
			println("C&CG convergence achieved")
			println("FINAL ACTIVE SCENARIOS: ", selected)
			println("FINAL UPPER BOUND:      ", best_upper_bound)
			println("FINAL LOWER BOUND:      ", best_lower_bound)
			println("FINAL GAP:              ", gap)
			println("====================================================")
			return (
				model = best_model,
				evaluation = best_evaluation,
				active_scenarios = selected,
				upper_bound = best_upper_bound,
				lower_bound = best_lower_bound,
				gap = gap,
			)
		end

		append!(selected, scenarios_to_add)
		sort!(unique!(selected))
	end

	println("\n====================================================")
	println("C&CG stopped at maximum iterations")
	println("FINAL ACTIVE SCENARIOS: ", selected)
	println("FINAL UPPER BOUND:      ", best_upper_bound)
	println("FINAL LOWER BOUND:      ", best_lower_bound)
	println("FINAL GAP:              ", abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance))
	println("====================================================")
	return (
		model = best_model,
		evaluation = best_evaluation,
		active_scenarios = selected,
		upper_bound = best_upper_bound,
		lower_bound = best_lower_bound,
		gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance),
	)
end

function ccg_env_bool(name::String, default::Bool)
	value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
	return value in ("1", "true", "yes", "y", "on")
end

function ccg_parallel_recourse_enabled()
	return ccg_env_bool("CCG_PARALLEL_RECOURSE", Threads.nthreads() > 1)
end

function ccg_optimizer_threads(env_name::String, default_value::Int64)
	return parse(Int64, get(ENV, env_name, string(default_value)))
end

function choose_initial_ccg_scenarios(data, initial_count::Int64)
	policy = lowercase(strip(get(ENV, "CCG_INITIAL_POLICY", "netload")))
	if policy == "first"
		return collect(1:initial_count)
	end

	wind_capacity = sum(data.winds.p_max)
	load_by_time = vec(sum(data.loads.load_curve; dims = 1))
	scores = [
		(maximum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity) +
			0.05 * sum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity), s)
		for s in 1:data.NS
	]
	sort!(scores; by = item -> item[1], rev = true)
	selected = [s for (_, s) in first(scores, initial_count)]
	sort!(selected)
	return selected
end

function load_ccg_data(scenario_limit::Int64)
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()
	config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
		forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)
	winds, NW = genscenario(WindsFreqParam, 1; scenario_limit = scenario_limit)
	NS = Int64(winds.scenarios_nums)
	return (
		config_param = config_param,
		units = units,
		lines = lines,
		loads = loads,
		winds = winds,
		psses = psses,
		DataCentras = DataCentras,
		NB = NB,
		NG = NG,
		NL = NL,
		ND = ND,
		NT = NT,
		NC = NC,
		ND2 = ND2,
		NW = NW,
		NS = NS,
		full_scenario_probability = 1.0 / NS,
	)
end

function solve_ccg_master(data, selected_scenarios::Vector{Int64})
	active_winds = build_ccg_subset_wind(data.winds, selected_scenarios, data.full_scenario_probability)
	model = build_ccg_extensive_model(data, active_winds, length(selected_scenarios), data.full_scenario_probability)
	optimize!(model)
	assert_is_solved_and_feasible(model)
	return model
end

function build_ccg_extensive_model(data, winds_subset::wind, NS_active::Int64, scenarios_prob::Float64)
	gsdf = calculate_gsdf(data.config_param, data.NL, data.units, data.lines, data.loads, data.NG, data.NB, data.ND)
	refcost, eachslope = linearizationfuelcurve(data.units, data.NG)
	onoffinit = calculate_initial_unit_status(data.units, data.NG)
	contingency_size = define_contingency_size(data.units, data.NG)

	model = Model(Gurobi.Optimizer)
	set_silent(model)
	set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "CCG_MASTER_MIP_GAP", "1e-4")))
	set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "CCG_NUMERIC_FOCUS", "1")))
	set_optimizer_attribute(model, "Threads", ccg_optimizer_threads("CCG_MASTER_THREADS", 0))

	define_decision_variables!(model, data.NT, data.NG, data.ND, data.NC, data.ND2, NS_active, data.NW, data.config_param)
	set_objective!(model, data.NT, data.NG, data.ND, data.NW, NS_active, data.units, data.config_param, scenarios_prob, refcost, eachslope)
	add_unit_operation_constraints!(model, data.NT, data.NG, data.units, onoffinit)
	add_curtailment_constraints!(model, data.NT, data.ND, data.NW, NS_active, data.loads, winds_subset)
	add_generator_power_constraints!(model, data.NT, data.NG, NS_active, data.units)
	add_reserve_constraints!(model, data.NT, data.NG, data.NC, NS_active, data.units, data.loads, winds_subset, data.config_param)
	add_power_balance_constraints!(model, data.NT, data.NG, data.ND, data.NC, data.NW, NS_active, data.loads, winds_subset, data.config_param, data.ND2)
	add_ramp_constraints!(model, data.NT, data.NG, NS_active, data.units, onoffinit)
	add_pwl_constraints!(model, data.NT, data.NG, NS_active, data.units)
	add_transmission_constraints!(model, data.NT, data.NG, data.ND, data.NC, data.NW, data.NL, NS_active, data.units, data.loads, winds_subset, data.lines, data.psses, gsdf, data.config_param, data.ND2, data.DataCentras)
	add_storage_constraints!(model, data.NT, data.NC, NS_active, data.config_param, data.psses)
	add_datacentra_constraints!(model, data.NT, NS_active, data.config_param, data.ND2, data.DataCentras)
	add_frequency_constraints!(model, data.NT, data.NG, data.NC, NS_active, data.units, data.psses, data.config_param, contingency_size)
	return model
end

function evaluate_ccg_recourse_pool(data, first_stage)
	if !ccg_parallel_recourse_enabled() || data.NS == 1
		results = OrderedDict{Int64, Any}()
		for scenario_id in 1:data.NS
			results[scenario_id] = solve_ccg_single_scenario_recourse(data, first_stage, scenario_id)
		end
		return results
	end

	result_vector = Vector{Any}(undef, data.NS)
	Threads.@threads for scenario_id in 1:data.NS
		result_vector[scenario_id] = solve_ccg_single_scenario_recourse(data, first_stage, scenario_id)
	end
	return OrderedDict(scenario_id => result_vector[scenario_id] for scenario_id in 1:data.NS)
end

function solve_ccg_single_scenario_recourse(data, first_stage, scenario_id::Int64)
	scenario_winds = build_single_scenario_wind(data.winds, scenario_id, data.full_scenario_probability)
	model = build_ccg_recourse_model(data, scenario_winds, data.full_scenario_probability)
	fix_first_stage_commitment!(model, first_stage)
	optimize!(model)
	assert_is_solved_and_feasible(model)
	return (
		recourse_cost = objective_value(model),
		objective_bound = objective_bound(model),
		status = termination_status(model),
	)
end

function build_ccg_recourse_model(data, scenario_winds::wind, scenarios_prob::Float64)
	gsdf = calculate_gsdf(data.config_param, data.NL, data.units, data.lines, data.loads, data.NG, data.NB, data.ND)
	onoffinit = calculate_initial_unit_status(data.units, data.NG)
	contingency_size = define_contingency_size(data.units, data.NG)

	model = Model(Gurobi.Optimizer)
	set_silent(model)
	set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "CCG_RECOURSE_MIP_GAP", "1e-4")))
	set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "CCG_NUMERIC_FOCUS", "1")))
	set_optimizer_attribute(model, "Threads", ccg_optimizer_threads("CCG_RECOURSE_THREADS", ccg_parallel_recourse_enabled() ? 1 : 0))

	define_decision_variables!(model, data.NT, data.NG, data.ND, data.NC, data.ND2, Int64(1), data.NW, data.config_param)
	set_ccg_recourse_objective!(model, data, Int64(1), scenarios_prob)
	add_curtailment_constraints!(model, data.NT, data.ND, data.NW, Int64(1), data.loads, scenario_winds)
	add_generator_power_constraints!(model, data.NT, data.NG, Int64(1), data.units)
	add_reserve_constraints!(model, data.NT, data.NG, data.NC, Int64(1), data.units, data.loads, scenario_winds, data.config_param)
	add_power_balance_constraints!(model, data.NT, data.NG, data.ND, data.NC, data.NW, Int64(1), data.loads, scenario_winds, data.config_param, data.ND2)
	add_ramp_constraints!(model, data.NT, data.NG, Int64(1), data.units, onoffinit)
	add_pwl_constraints!(model, data.NT, data.NG, Int64(1), data.units)
	add_transmission_constraints!(model, data.NT, data.NG, data.ND, data.NC, data.NW, data.NL, Int64(1), data.units, data.loads, scenario_winds, data.lines, data.psses, gsdf, data.config_param, data.ND2, data.DataCentras)
	add_storage_constraints!(model, data.NT, data.NC, Int64(1), data.config_param, data.psses)
	add_datacentra_constraints!(model, data.NT, Int64(1), data.config_param, data.ND2, data.DataCentras)
	add_frequency_constraints!(model, data.NT, data.NG, data.NC, Int64(1), data.units, data.psses, data.config_param, contingency_size)
	return model
end

function set_ccg_recourse_objective!(model::Model, data, NS::Int64, scenarios_prob::Float64)
	c0 = data.config_param.is_CoalPrice
	load_curtailment_penalty = data.config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = data.config_param.is_WindsCuttingCoefficient * 1e0
	reserve_cost_positive = 2 * c0
	reserve_cost_negative = 2 * c0
	refcost, eachslope = linearizationfuelcurve(data.units, data.NG)

	x = model[:x]
	pgk = model[:pgₖ]
	sr_pos = model[:sr⁺]
	sr_neg = model[:sr⁻]
	delta_pd = model[:Δpd]
	delta_pw = model[:Δpw]

	@objective(
		model,
		Min,
		scenarios_prob * c0 *
		(
			sum(sum(sum(sum(pgk[i + (s - 1) * data.NG, t, :] .* eachslope[:, i] for t in 1:data.NT)) for s in 1:NS) for i in 1:data.NG) +
			sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:data.NT)) for s in 1:NS) +
			sum(sum(sum(reserve_cost_positive * sr_pos[i + (s - 1) * data.NG, t] + reserve_cost_negative * sr_neg[i + (s - 1) * data.NG, t] for i in 1:data.NG) for t in 1:data.NT) for s in 1:NS)
		) +
		scenarios_prob * load_curtailment_penalty * sum(sum(sum(delta_pd[(1 + (s - 1) * data.ND):(s * data.ND), t]) for t in 1:data.NT) for s in 1:NS) +
		scenarios_prob * wind_curtailment_penalty * sum(sum(sum(delta_pw[(1 + (s - 1) * data.NW):(s * data.NW), t]) for t in 1:data.NT) for s in 1:NS)
	)
	return model
end

function extract_first_stage_solution(model::Model)
	x = value.(model[:x])
	u = value.(model[:u])
	v = value.(model[:v])
	su = value.(model[:su₀])
	sd = value.(model[:sd₀])
	return (
		x = x,
		u = u,
		v = v,
		cost = sum(su) + sum(sd),
	)
end

function fix_first_stage_commitment!(model::Model, first_stage)
	fix.(model[:x], first_stage.x; force = true)
	fix.(model[:u], first_stage.u; force = true)
	fix.(model[:v], first_stage.v; force = true)
	return model
end

function choose_ccg_scenarios_to_add(evaluation, inactive_scenarios::Vector{Int64}, scenarios_per_iteration::Int64)
	isempty(inactive_scenarios) && return Int64[]
	candidates = [(evaluation[s].recourse_cost, s) for s in inactive_scenarios]
	sort!(candidates; by = item -> item[1], rev = true)
	return [s for (_, s) in first(candidates, min(scenarios_per_iteration, length(candidates)))]
end

function build_ccg_subset_wind(winds::wind, selected_scenarios::Vector{Int64}, scenarios_prob::Float64)
	return wind(
		winds.index,
		winds.locatebus,
		winds.p_max,
		scenarios_prob,
		length(selected_scenarios),
		winds.scenarios_curve[selected_scenarios, :],
		winds.Fcmode,
		winds.Kw,
		winds.Rw,
		winds.Mw,
		winds.Dw,
		winds.Tw,
	)
end

function print_ccg_iteration(iteration, active_count, lower_bound, upper_bound, gap, scenarios_to_add)
	println(
		rpad(iteration, 8),
		rpad(active_count, 9),
		rpad(@sprintf("%.6g", lower_bound), 16),
		rpad(@sprintf("%.6g", upper_bound), 15),
		rpad(@sprintf("%.6g", gap), 10),
		scenarios_to_add,
	)
	return nothing
end
