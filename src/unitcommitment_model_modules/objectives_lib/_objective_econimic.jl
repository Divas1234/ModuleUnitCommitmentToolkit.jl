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

export set_objective_economic!

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
		refcost,
		eachslope,
)
	# ========================================================================
	# Cost Parameters
	# ========================================================================
	c₀ = config_param.is_CoalPrice      # Base cost of coal
	pₛ = scenarios_prob                 # Probability of each scenario

	# Penalty coefficients for curtailment (very high for load, moderate for wind)
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	# Reserve cost coefficients
	ρ⁺ = c₀ * 2  # Upward reserve cost
	ρ⁻ = c₀ * 2  # Downward reserve cost

	# ========================================================================
	# Get Decision Variables
	# ========================================================================
	x = scuc[:x]      # Unit commitment status
	su₀ = scuc[:su₀]  # Startup cost
	sd₀ = scuc[:sd₀]  # Shutdown cost
	pgₖ = scuc[:pgₖ] # Piecewise linear power segments
	sr⁺ = scuc[:sr⁺] # Upward spinning reserve
	sr⁻ = scuc[:sr⁻] # Downward spinning reserve
	Δpd = scuc[:Δpd] # Load curtailment
	Δpw = scuc[:Δpw] # Wind curtailment

	# ========================================================================
	# Build Objective Function
	# ========================================================================
	@objective(scuc,
		Min,
		# Component 1: Startup and shutdown costs (deterministic)
		sum(sum(su₀[i, t] + sd₀[i, t] for i ∈ 1:NG) for t ∈ 1:NT) +

		# Component 2: Expected fuel costs (stochastic)
		pₛ *
		c₀ *
		(
		# Piecewise linear fuel costs
			sum(
				sum(
					sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t ∈ 1:NT)) for
				s ∈ 1:NS
				) for i ∈ 1:NG
			) +
			# Reference cost (at minimum power)
			sum(sum(sum(x[:, t] .* refcost[:, 1] for t ∈ 1:NT)) for s ∈ 1:NS) +
			# Reserve costs
			sum(
				sum(
					sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t] for i ∈ 1:NG) for
				t ∈ 1:NT
				) for s ∈ 1:NS
			)
		) +

		# Component 3: Expected load curtailment penalty
		pₛ *
		load_curtailment_penalty *
		sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t ∈ 1:NT) for s ∈ 1:NS) +

		# Component 4: Expected wind curtailment penalty
		pₛ *
		wind_curtailment_penalty *
		sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t ∈ 1:NT) for s ∈ 1:NS))

	println("objective_function")
	println("\t MILP_type objective_function \t\t\t\t\t\t done")
end
