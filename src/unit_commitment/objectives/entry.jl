include("economic.jl")

"""
Sets the objective function for the Security-Constrained Unit Commitment (SCUC) model.

This function serves as a wrapper for the economic objective function.

# Arguments
- `scuc::Model`: The JuMP model for the SCUC problem.
- `NT`: Number of time periods.
- `NG`: Number of generators.
- `ND`: Number of loads.
- `NW`: Number of wind power generators.
- `NS`: Number of scenarios.
- `units`: Unit information.
- `config_param`: Configuration parameters.
- `scenarios_prob`: Scenario probabilities.
- `refcost`: Reference cost.
- `eachslope`: Each slope.
"""
function set_objective!(scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
    return set_objective_economic!(scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
end

if lowercase(strip(get(ENV, "MODULE_UC_VERBOSE_LOAD", "0"))) in ("1", "true", "yes", "y", "on")
    println("\t\u2192 objective functions exported.")
end
