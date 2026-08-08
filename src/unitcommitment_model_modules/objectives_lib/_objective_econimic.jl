# ============================================================================
# Economic Objective Function
#
# This module defines the economic objective function for the unit commitment
# optimization problem. The objective minimizes total system cost including:
# - Generator startup and shutdown costs
# - Fuel costs (piecewise linear approximation)
# - Reserve costs
# - Load and wind curtailment penalties
# ============================================================================

using JuMP

export set_objective_economic!, set_objective_lowcarbon!
"""
		set_objective_lowcarbon!(scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope, emission_factors, carbon_price)

Set the low-carbon dispatch objective function.
This objective adds carbon emission cost to the economic objective, enabling low-carbon dispatch.

# Arguments

	- `scuc::Model`: JuMP optimization model
	- `NT::Int`: Number of time periods
	- `NG::Int`: Number of generators
	- `ND::Int`: Number of load nodes
	- `NW::Int`: Number of wind farms
	- `NS::Int`: Number of scenarios
	- `units::unit`: Generator unit data
	- `config_param::config`: Configuration parameters
	- `scenarios_prob::Float64`: Probability of each scenario (typically 1/NS)
	- `refcost::Vector{Float64}`: Reference cost at minimum power (NG × 1)
	- `eachslope::Matrix{Float64}`: Slopes of piecewise linear segments (3 × NG)
	- `emission_factors::Vector{Float64}`: Generator carbon emission factors (NG × 1, tCO2/MWh)
	- `carbon_price::Float64`: Carbon price (CNY/tCO2)

# Objective Function Structure

Economic cost + carbon emission cost:

```
Objective = Economic cost + pₛ * carbon_price * ∑_{s=1}^{NS} ∑_{i=1}^{NG} ∑_{t=1}^{NT} emission_factors[i] * (∑_{k=1}^{K} pgₖ[i+(s-1)*NG, t, k])
```
"""
function set_objective_lowcarbon!(
		scuc::Model,
		NT,
		NG,
		ND,
		NW,
		NS,
		units,
		config_param,
		scenarios_prob,
		refcost::AbstractVector,
		eachslope::AbstractMatrix,
		emission_factors::AbstractVector,
		carbon_price::Float64
)
	c₀ = config_param.is_CoalPrice
	pₛ = scenarios_prob
	ρ⁺ = 2c₀
	ρ⁻ = 2c₀
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0
	K = size(eachslope, 1)

	x = scuc[:x]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]
	pgₖ = scuc[:pgₖ]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]

	startup_shutdown = sum(su₀[i, t] + sd₀[i, t] for i in 1:NG, t in 1:NT)

	piecewise_sum = K > 0 ? sum(pgₖ[i + (s - 1) * NG, t, k] * eachslope[k, i] for s in 1:NS, i in 1:NG, t in 1:NT, k in 1:K) : 0.0
	fuel_piecewise = c₀ * (
		sum(refcost[i] * x[i, t] for i in 1:NG, t in 1:NT) +
		pₛ * piecewise_sum +
		pₛ * sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
		for s in 1:NS, i in 1:NG, t in 1:NT)
	)

	load_penalty = pₛ * load_curtailment_penalty *
				   sum(Δpd[d + (s - 1) * ND, t] for s in 1:NS, d in 1:ND, t in 1:NT)

	wind_penalty = (NW > 0) ? pₛ * wind_curtailment_penalty *
				   sum(Δpw[w + (s - 1) * NW, t] for s in 1:NS, w in 1:NW, t in 1:NT) : 0.0

	# Carbon emission cost
	carbon_cost = (K > 0) ? pₛ * carbon_price * sum(
		emission_factors[i] * sum(pgₖ[i + (s - 1) * NG, t, k] for k in 1:K)
	for s in 1:NS, i in 1:NG, t in 1:NT) : 0.0

	@objective(scuc, Min,
		startup_shutdown +
		fuel_piecewise +
		load_penalty +
		wind_penalty +
		carbon_cost)

	println("objective_function\n\tMILP low-carbon objective set")
	return nothing
end

"""
	set_objective_economic!(scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

Set the economic objective function for the stochastic unit commitment problem.

The objective minimizes the expected total cost across all scenarios, including:

 1. Startup and shutdown costs (first-stage decisions)
 2. Fuel costs (piecewise linear approximation)
 3. Reserve costs
 4. Load curtailment penalties
 5. Wind curtailment penalties

# Arguments

  - `scuc::Model`: JuMP optimization model
  - `NT::Int`: Number of time periods
  - `NG::Int`: Number of generators
  - `ND::Int`: Number of loads
  - `NW::Int`: Number of wind farms
  - `NS::Int`: Number of scenarios
  - `units::unit`: Generator unit data
  - `config_param::config`: Configuration parameters
  - `scenarios_prob::Float64`: Probability of each scenario (typically 1/NS)
  - `refcost::Vector{Float64}`: Reference cost at minimum power (NG × 1)
  - `eachslope::Matrix{Float64}`: Slopes of piecewise linear segments (3 × NG)

# Objective Function Components

## 1. Startup and Shutdown Costs

```
∑_{t=1}^{NT} ∑_{i=1}^{NG} (su₀[i,t] + sd₀[i,t])
```

## 2. Fuel Costs (Piecewise Linear)

```
pₛ * c₀ * [∑_{s=1}^{NS} ∑_{i=1}^{NG} ∑_{t=1}^{NT} (refcost[i] * x[i,t] +
			∑_{k=1}^{3} pgₖ[i+(s-1)*NG, t, k] * eachslope[k, i])]
```

## 3. Reserve Costs

```
pₛ * c₀ * ∑_{s=1}^{NS} ∑_{i=1}^{NG} ∑_{t=1}^{NT} (ρ⁺ * sr⁺[i+(s-1)*NG, t] +
			ρ⁻ * sr⁻[i+(s-1)*NG, t])
```

## 4. Curtailment Penalties

```
pₛ * [load_penalty * ∑_{s=1}^{NS} ∑_{t=1}^{NT} ∑_{d=1}^{ND} Δpd[d+(s-1)*ND, t] +
	  wind_penalty * ∑_{s=1}^{NS} ∑_{t=1}^{NT} ∑_{w=1}^{NW} Δpw[w+(s-1)*NW, t]]
```

# Note

  - `c₀`: Base coal price (from config_param.is_CoalPrice)
  - `ρ⁺`, `ρ⁻`: Reserve cost coefficients (typically 2 * c₀)
  - Load curtailment penalty is very high (1e10) to discourage load shedding
  - Wind curtailment penalty is lower (1e0) as it's more acceptable
"""
function set_objective_economic!(
		scuc::Model,
		NT,
		NG,
		ND,
		NW,
		NS,
		units,
		config_param,
		scenarios_prob,
		refcost::AbstractVector,
		eachslope::AbstractMatrix
)
	c₀ = config_param.is_CoalPrice
	pₛ = scenarios_prob
	ρ⁺ = 2c₀
	ρ⁻ = 2c₀
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0
	K = size(eachslope, 1)
	
	println("DEBUG set_objective_economic!: NT=$NT, NG=$NG, ND=$ND, NW=$NW, NS=$NS, K=$K, size(refcost)=$(size(refcost)), size(eachslope)=$(size(eachslope))")

	x = scuc[:x]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]
	pgₖ = scuc[:pgₖ]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]

	startup_shutdown = sum(su₀[i, t] + sd₀[i, t] for i in 1:NG, t in 1:NT)

	piecewise_sum = K > 0 ? sum(pgₖ[i + (s - 1) * NG, t, k] * eachslope[k, i] for s in 1:NS, i in 1:NG, t in 1:NT, k in 1:K) : 0.0
	fuel_piecewise = c₀ * (
	# Reference (min output) cost: first-stage only
		sum(refcost[i] * x[i, t] for i in 1:NG, t in 1:NT) +
		# Piecewise linear segment costs (second-stage)
		pₛ * piecewise_sum +
		# Reserve costs
		pₛ * sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
		for s in 1:NS, i in 1:NG, t in 1:NT)
	)

	load_penalty = pₛ * load_curtailment_penalty *
				   sum(Δpd[d + (s - 1) * ND, t] for s in 1:NS, d in 1:ND, t in 1:NT)

	wind_penalty = (NW > 0) ? pₛ * wind_curtailment_penalty *
				   sum(Δpw[w + (s - 1) * NW, t] for s in 1:NS, w in 1:NW, t in 1:NT) : 0.0

	@objective(scuc, Min,
		startup_shutdown +
		fuel_piecewise +
		load_penalty +
		wind_penalty)

	println("objective_function\n\tMILP economic objective set")
	return nothing
end
