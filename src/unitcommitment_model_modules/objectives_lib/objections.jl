include("_objective_econimic.jl")

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
function set_objective!(
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
		eachslope
)
	# Ensure scuc is a JuMP.Model
	@assert scuc isa Model "scuc must be a JuMP.Model"

	# Use Symbol key (was String) for consistency with error message and typical config param usage
	objtype = config_param.is_SchedulingObjFuncType
	if objtype === nothing
		error("config_param must have field :is_SchedulingObjFuncType")
	end

	if objtype == 2
		return set_objective_lowcarbon!(
			scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope
		)
	elseif objtype == 1
		return set_objective_economic!(
			scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope
		)
	else
		error("Unsupported SchedulingObjFuncType: $objtype")
	end
end

println("\t→ Objective functions module loaded and exported.")
