# Distributionally robust renewable uncertainty utilities for the C&CG solver.
#
# The ambiguity set is a finite-support Wasserstein ball around the empirical
# renewable scenario distribution. Scenario distance is computed from normalized
# wind-power trajectories, and separation solves a transport LP to identify the
# worst-case probability distribution.

function ccg_dro_enabled()
	return ccg_env_bool("CCG_DRO_ENABLED", true)
end

function ccg_dro_radius()
	return max(0.0, parse(Float64, get(ENV, "CCG_DRO_RADIUS", "0.05")))
end

function ccg_wasserstein_power()
	power = parse(Float64, get(ENV, "CCG_WASSERSTEIN_POWER", "1.0"))
	power > 0 || throw(ArgumentError("CCG_WASSERSTEIN_POWER must be positive; got $power"))
	return power
end

function build_renewable_dro_model(winds::wind)
	validate_wind_scenario_data(winds)
	scenario_count = Int64(winds.scenarios_nums)
	nominal_probability = fill(1.0 / scenario_count, scenario_count)
	distance_matrix = renewable_wasserstein_distance_matrix(winds; power = ccg_wasserstein_power())
	return (
		enabled = ccg_dro_enabled(),
		metric = "wasserstein",
		radius = ccg_dro_radius(),
		nominal_probability = nominal_probability,
		distance_matrix = distance_matrix,
		scenario_count = scenario_count,
	)
end

function validate_wind_scenario_data(winds::wind)
	winds.scenarios_nums > 0 || throw(ArgumentError("wind.scenarios_nums must be positive; got $(winds.scenarios_nums)"))
	size(winds.scenarios_curve, 1) == winds.scenarios_nums ||
		throw(ArgumentError("wind.scenarios_curve row count ($(size(winds.scenarios_curve, 1))) must match wind.scenarios_nums ($(winds.scenarios_nums))"))
	size(winds.scenarios_curve, 2) > 0 ||
		throw(ArgumentError("wind.scenarios_curve must contain at least one time period"))
	all(isfinite, winds.scenarios_curve) ||
		throw(ArgumentError("wind.scenarios_curve contains NaN or Inf values"))
	all(winds.scenarios_curve .>= 0) ||
		throw(ArgumentError("wind.scenarios_curve contains negative renewable availability values"))
	length(winds.p_max) == length(winds.index) ||
		throw(ArgumentError("wind.p_max length ($(length(winds.p_max))) must match wind.index length ($(length(winds.index)))"))
	all(isfinite, winds.p_max) ||
		throw(ArgumentError("wind.p_max contains NaN or Inf values"))
	all(winds.p_max .>= 0) ||
		throw(ArgumentError("wind.p_max contains negative capacity values"))
	return nothing
end

function normalize_probability(probability::Vector{Float64})
	!isempty(probability) || throw(ArgumentError("probability vector cannot be empty"))
	all(isfinite, probability) || throw(ArgumentError("probability vector contains NaN or Inf values"))
	all(probability .>= 0) || throw(ArgumentError("probability vector contains negative values"))
	total_probability = sum(probability)
	if total_probability <= eps(Float64)
		return fill(1.0 / length(probability), length(probability))
	end
	return probability ./ total_probability
end

function active_nominal_probability(dro_model, selected_scenarios::Vector{Int64})
	validate_selected_scenarios(selected_scenarios, dro_model.scenario_count)
	return normalize_probability(dro_model.nominal_probability[selected_scenarios])
end

function active_wasserstein_distance(dro_model, selected_scenarios::Vector{Int64})
	validate_selected_scenarios(selected_scenarios, dro_model.scenario_count)
	return dro_model.distance_matrix[selected_scenarios, selected_scenarios]
end

function validate_selected_scenarios(selected_scenarios::Vector{Int64}, scenario_count::Int64)
	!isempty(selected_scenarios) || throw(ArgumentError("selected_scenarios cannot be empty"))
	all(1 .<= selected_scenarios .<= scenario_count) ||
		throw(ArgumentError("selected_scenarios must be in 1:$scenario_count; got $selected_scenarios"))
	length(unique(selected_scenarios)) == length(selected_scenarios) ||
		throw(ArgumentError("selected_scenarios contains duplicated scenario ids: $selected_scenarios"))
	return nothing
end

function renewable_wasserstein_distance_matrix(winds::wind; power::Float64 = 1.0)
	validate_wind_scenario_data(winds)
	power > 0 || throw(ArgumentError("Wasserstein distance power must be positive; got $power"))
	curves = winds.scenarios_curve
	scenario_count = size(curves, 1)
	distance_matrix = zeros(Float64, scenario_count, scenario_count)
	for i in 1:scenario_count
		for j in (i + 1):scenario_count
			distance = sum(abs.(curves[i, :] .- curves[j, :]) .^ power)^(1.0 / power)
			distance_matrix[i, j] = distance
			distance_matrix[j, i] = distance
		end
	end
	scale = maximum(distance_matrix)
	if scale > eps(Float64)
		distance_matrix ./= scale
	end
	return distance_matrix
end

function validate_wasserstein_inputs(
	costs::Vector{Float64},
	nominal_probability::Vector{Float64},
	radius::Float64,
	distance_matrix::Matrix{Float64},
)
	!isempty(costs) || throw(ArgumentError("cost vector cannot be empty"))
	all(isfinite, costs) || throw(ArgumentError("cost vector contains NaN or Inf values"))
	radius >= 0 || throw(ArgumentError("Wasserstein radius must be nonnegative; got $radius"))
	probability = normalize_probability(nominal_probability)
	length(costs) == length(probability) ||
		throw(ArgumentError("cost vector length ($(length(costs))) must match probability length ($(length(probability)))"))
	size(distance_matrix) == (length(costs), length(costs)) ||
		throw(ArgumentError("distance matrix size $(size(distance_matrix)) must match scenario count $(length(costs))"))
	all(isfinite, distance_matrix) ||
		throw(ArgumentError("distance matrix contains NaN or Inf values"))
	all(distance_matrix .>= -1e-10) ||
		throw(ArgumentError("distance matrix contains negative entries"))
	isapprox(distance_matrix, transpose(distance_matrix); atol = 1e-8) ||
		throw(ArgumentError("distance matrix must be symmetric"))
	all(abs(distance_matrix[i, i]) <= 1e-8 for i in axes(distance_matrix, 1)) ||
		throw(ArgumentError("distance matrix diagonal must be zero"))
	return probability
end

function worst_case_probabilities(
	costs::Vector{Float64},
	nominal_probability::Vector{Float64},
	radius::Float64,
	distance_matrix::Matrix{Float64},
)
	probability = validate_wasserstein_inputs(costs, nominal_probability, radius, distance_matrix)
	length(costs) == 1 && return probability
	radius <= eps(Float64) && return probability

	model = Model(Gurobi.Optimizer)
	set_silent(model)
	set_optimizer_attribute(model, "OutputFlag", 0)
	set_optimizer_attribute(model, "Threads", 1)

	scenario_count = length(costs)
	@variable(model, transport[1:scenario_count, 1:scenario_count] >= 0)
	@constraint(model, [i = 1:scenario_count], sum(transport[i, j] for j in 1:scenario_count) == probability[i])
	@constraint(model, sum(distance_matrix[i, j] * transport[i, j] for i in 1:scenario_count, j in 1:scenario_count) <= radius)
	@objective(model, Max, sum(costs[j] * transport[i, j] for i in 1:scenario_count, j in 1:scenario_count))

	optimize!(model)
	if termination_status(model) != MOI.OPTIMAL
		@warn "Wasserstein worst-distribution LP did not solve to optimality; using nominal distribution" status = termination_status(model)
		return probability
	end

	worst_probability = [sum(value(transport[i, j]) for i in 1:scenario_count) for j in 1:scenario_count]
	return normalize_probability(worst_probability)
end

function worst_case_expected_value(
	costs::Vector{Float64},
	nominal_probability::Vector{Float64},
	radius::Float64,
	distance_matrix::Matrix{Float64},
)
	probability = worst_case_probabilities(costs, nominal_probability, radius, distance_matrix)
	return sum(probability .* costs), probability
end

function renewable_netload_scores(data)
	wind_capacity = sum(data.winds.p_max)
	load_by_time = vec(sum(data.loads.load_curve; dims = 1))
	return [maximum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity) +
			0.05 * sum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity)
			for s in 1:data.NS]
end

function set_dro_ccg_master_objective!(
	model::Model,
	data,
	NS_active::Int64,
	nominal_probability::Vector{Float64},
	radius::Float64,
	distance_matrix::Matrix{Float64},
)
	NS_active > 0 || throw(ArgumentError("NS_active must be positive; got $NS_active"))
	validate_wasserstein_inputs(zeros(Float64, NS_active), nominal_probability, radius, distance_matrix)
	haskey(JuMP.object_dictionary(model), :x) ||
		throw(ArgumentError("DRO objective requires decision variables to be defined before calling set_dro_ccg_master_objective!"))

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

	@variable(model, dro_lambda >= 0)
	@variable(model, dro_eta[1:NS_active])
	for i in 1:NS_active
		for j in 1:NS_active
			@constraint(model, dro_eta[i] >= scenario_cost[j] - dro_lambda * distance_matrix[i, j])
		end
	end

	first_stage_cost = sum(su[i, t] + sd[i, t] for i in 1:data.NG, t in 1:data.NT)
	@objective(
		model,
		Min,
		first_stage_cost + radius * dro_lambda + sum(nominal_probability[i] * dro_eta[i] for i in 1:NS_active),
	)
	return model
end
