include("economic_objective.jl")

export set_objective!

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
    # Check if the input model is a JuMP Model
    @assert typeof(scuc) == Model "scuc must be a JuMP Model"

    result = set_objective_economic!(scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

    if isdefined(@__MODULE__, :_UC_OBJECTIVE_HOOKS) && !isempty(_UC_OBJECTIVE_HOOKS)
        ctx = (
            NT = NT, NG = NG, ND = ND, NW = NW, NS = NS,
            units = units, config_param = config_param,
            scenarios_prob = scenarios_prob, refcost = refcost, eachslope = eachslope,
        )
        base_obj = objective_function(scuc)
        extra_terms = Any[]
        for (_, hook_fn) in _UC_OBJECTIVE_HOOKS
            term = hook_fn(scuc, ctx)
            term !== nothing && push!(extra_terms, term)
        end
        if !isempty(extra_terms)
            @objective(scuc, Min, base_obj + sum(extra_terms))
        end
    end

    return result
end

if lowercase(strip(get(ENV, "MODULE_UC_VERBOSE_LOAD", "0"))) in ("1", "true", "yes", "y", "on")
    println("\t\u2192 objective functions exported.")
end
