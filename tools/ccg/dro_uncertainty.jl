# Distributionally robust renewable uncertainty utilities for the C&CG solver.
#
# The ambiguity set is a finite-support total-variation ball around the
# renewable scenario empirical distribution. Separation evaluates all candidate
# renewable scenarios and shifts probability mass toward expensive recourse
# outcomes.

function ccg_dro_enabled()
	return ccg_env_bool("CCG_DRO_ENABLED", true)
end

function ccg_dro_radius()
	return clamp(parse(Float64, get(ENV, "CCG_DRO_RADIUS", "0.2")), 0.0, 2.0)
end

function build_renewable_dro_model(winds::wind)
	scenario_count = Int64(winds.scenarios_nums)
	nominal_probability = fill(1.0 / scenario_count, scenario_count)
	return (
		enabled = ccg_dro_enabled(),
		radius = ccg_dro_radius(),
		nominal_probability = nominal_probability,
		scenario_count = scenario_count,
	)
end

function normalize_probability(probability::Vector{Float64})
	total_probability = sum(probability)
	if total_probability <= eps(Float64)
		return fill(1.0 / length(probability), length(probability))
	end
	return probability ./ total_probability
end

function active_nominal_probability(dro_model, selected_scenarios::Vector{Int64})
	return normalize_probability(dro_model.nominal_probability[selected_scenarios])
end

function worst_case_probabilities(costs::Vector{Float64}, nominal_probability::Vector{Float64}, radius::Float64)
	probability = copy(normalize_probability(nominal_probability))
	length(costs) == length(probability) || error("cost and probability vectors must have the same length")
	length(costs) == 1 && return probability

	remaining_mass = min(radius / 2.0, sum(probability) - minimum(probability))
	remaining_mass <= eps(Float64) && return probability

	low_order = sortperm(costs; rev = false)
	high_order = sortperm(costs; rev = true)
	low_cursor = 1
	high_cursor = 1

	while remaining_mass > eps(Float64) && low_cursor <= length(costs) && high_cursor <= length(costs)
		low_id = low_order[low_cursor]
		high_id = high_order[high_cursor]
		if costs[high_id] <= costs[low_id] + eps(Float64)
			break
		end

		available = probability[low_id]
		available <= eps(Float64) && (low_cursor += 1; continue)
		shift = min(available, remaining_mass)
		probability[low_id] -= shift
		probability[high_id] += shift
		remaining_mass -= shift
		if probability[low_id] <= eps(Float64)
			low_cursor += 1
		end
		high_cursor += probability[high_id] >= 1.0 - eps(Float64) ? 1 : 0
	end

	return normalize_probability(probability)
end

function worst_case_expected_value(costs::Vector{Float64}, nominal_probability::Vector{Float64}, radius::Float64)
	probability = worst_case_probabilities(costs, nominal_probability, radius)
	return sum(probability .* costs), probability
end

function renewable_netload_scores(data)
	wind_capacity = sum(data.winds.p_max)
	load_by_time = vec(sum(data.loads.load_curve; dims = 1))
	return [maximum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity) +
			0.05 * sum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity)
			for s in 1:data.NS]
end

function set_dro_ccg_master_objective!(model::Model, data, NS_active::Int64, nominal_probability::Vector{Float64}, radius::Float64)
	c0 = data.config_param.is_CoalPrice
	load_curtailment_penalty = data.config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = data.config_param.is_WindsCuttingCoefficient * 1e0
	reserve_cost_positive = 2 * c0
	reserve_cost_negative = 2 * c0
	refcost, eachslope = linearizationfuelcurve(data.units, data.NG)

	x = model[:x]
	su = model[:su₀]
	sd = model[:sd₀]
	pgk = model[:pgₖ]
	sr_pos = model[:sr⁺]
	sr_neg = model[:sr⁻]
	delta_pd = model[:Δpd]
	delta_pw = model[:Δpw]

	scenario_cost = Vector{AffExpr}(undef, NS_active)
	for s in 1:NS_active
		generator_rows = (1 + (s - 1) * data.NG):(s * data.NG)
		load_rows = (1 + (s - 1) * data.ND):(s * data.ND)
		wind_rows = (1 + (s - 1) * data.NW):(s * data.NW)
		scenario_cost[s] = c0 * (
							   sum(sum(pgk[i, t, k] * eachslope[k, local_i] for k in axes(pgk, 3), t in 1:data.NT) for (local_i, i) in enumerate(generator_rows)) +
							   sum(sum(x[:, t] .* refcost[:, 1]) for t in 1:data.NT) +
							   sum(reserve_cost_positive * sr_pos[i, t] + reserve_cost_negative * sr_neg[i, t] for i in generator_rows, t in 1:data.NT)
						   ) +
						   load_curtailment_penalty * sum(delta_pd[i, t] for i in load_rows, t in 1:data.NT) +
						   wind_curtailment_penalty * sum(delta_pw[i, t] for i in wind_rows, t in 1:data.NT)
	end

	@variable(model, dro_theta[1:NS_active] >= 0)
	@variable(model, dro_upper >= 0)
	@variable(model, dro_lower >= 0)
	for s in 1:NS_active
		@constraint(model, dro_theta[s] >= scenario_cost[s])
		@constraint(model, dro_upper >= dro_theta[s])
		@constraint(model, dro_lower <= dro_theta[s])
	end

	first_stage_cost = sum(su[i, t] + sd[i, t] for i in 1:data.NG, t in 1:data.NT)
	@objective(model,
		Min,
		first_stage_cost +
		sum(nominal_probability[s] * dro_theta[s] for s in 1:NS_active) +
		(radius / 2.0) * (dro_upper - dro_lower))
	return model
end
