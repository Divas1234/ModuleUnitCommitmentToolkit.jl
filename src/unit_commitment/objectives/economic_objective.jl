"""
`set_objective_economic!(...)`

Defines the overall mixed-integer linear programming (MILP) objective function for 
the SCUC model. The objective is to minimize the total expected system cost 
over the planning horizon.

# Cost Components
1. **Startup/Shutdown Costs**: Costs incurred when changing a unit's status.
2. **Variable Fuel Costs**: Approximated via piecewise linear segments.
3. **Fixed Operation Costs**: Costs associated with a unit being online.
4. **Reserve Costs**: Expected costs for maintaining spinning reserves.
5. **Reliability Penalties**: Large penalties for load shedding or wind curtailment 
   to prioritize system security.
"""
function set_objective_economic!(scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
    # Cost parameters
    c₀ = config_param.is_CoalPrice  # Base cost of coal
    pₛ = scenarios_prob  # Probability of scenarios

    # Penalty coefficients for load and wind curtailment
    load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e4
    wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

    ρ⁺ = c₀ * 2
    ρ⁻ = c₀ * 2

    # --- Variable Mapping ---
    x = scuc[:x]     # Commitment status
    su₀ = scuc[:su₀] # Startup costs
    sd₀ = scuc[:sd₀] # Shutdown costs
    pgₖ = scuc[:pgₖ] # Power segments
    sr⁺ = scuc[:sr⁺] # Up-reserve
    sr⁻ = scuc[:sr⁻] # Down-reserve
    Δpd = scuc[:Δpd] # Load shedding
    Δpw = scuc[:Δpw] # Wind curtailment

    @objective(
        scuc,
        Min,
        # 1) Aggregate Startup and Shutdown Costs (Scenario-independent)
        sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) +
        pₛ *
        c₀ *
        (
            # 2) Variable Fuel Costs (Piecewise Segments)
            sum(sum(sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT)) for s in 1:NS) for i in 1:NG) +
            # 3) Fixed Generation Costs (No-load costs)
            sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS) +
            # 4) Expected Spinning Reserve Costs
            sum(sum(sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT) for s in 1:NS)
        ) +
        pₛ *
        # 5) Load Shedding Penalties (High priority)
        load_curtailment_penalty *
        sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS) +
        pₛ *
        # 6) Renewable Curtailment Penalties
        wind_curtailment_penalty *
        sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
    )
    println("objective_function")
    return println("\t MILP_type objective_function \t\t\t\t\t\t done")
end
