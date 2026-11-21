using JuMP, Gurobi, DelimitedFiles

#---------------------------------------------------------------------------------------------------
# Module Dependencies and Includes
#---------------------------------------------------------------------------------------------------

# Include necessary model components
include("constraints/constraints.jl")
include("objectives/objectives.jl")
include("utilities/utilities.jl")
include("validation/validation.jl")
"""
	SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, storages, scenarios_prob, NL)

Stochastic Unit Commitment (SUC) model for power system optimization (Refactored & Modularized).

#NOTE -  Arguments
- `NT::Int64`: Number of time periods
- `NB::Int64`: Number of buses
- `NG::Int64`: Number of generators
- `ND::Int64`: Number of demands/loads
- `NC::Int64`: Number of energy storage units
- `ND2::Int64`: Number of data centers
- `units::unit`: Generator unit data
- `loads::load`: Load data
- `winds::wind`: Wind generation data
- `lines::transmissionline`: Transmission line data
- `data_centers::DataCenters`: Data center data
- `config_param::config`: Configuration parameters
- `storages::Any`: Storage system data (Type Any for flexibility, consider defining a specific struct)
- `scenarios_prob::Float64`: Probability of scenarios (Assumed equal for now if calculated as 1/NS)
- `NL::Int64`: Number of transmission lines

# Returns
- Dictionary containing optimization results, or nothing if optimization fails.
"""

# NOTE - function module

function _report_infeasibility_conflict(scuc::Model)
    println("Computing Gurobi conflict (IIS) to diagnose infeasibility...")
    try
        JuMP.compute_conflict!(scuc)
        println("Conflict computation completed. Conflicting constraints:")
        for (F, S) in list_of_constraint_types(scuc)
            for con in all_constraints(scuc, F, S)
                try
                    if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                        println("  IN_CONFLICT: ", con)
                    end
                catch
                end
            end
        end
    catch err
        println("Failed to compute conflict (IIS): ", err)
    end
    return nothing
end

function SUC_scucmodel(
    NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64,
    units::unit, loads::load, winds::wind, lines::transmissionline, data_centers::DataCenters, config_param::config, psses::Any,
    scenarios_prob::Float64, NL::Int64,
)
    println("Step-3: Creating dispatching model (Refactored & Modularized)")

    # --- Input Validation ---
    if !validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, psses, scenarios_prob, NL)
        error("Input validation failed. Check your data.")
    end

    # --- Initialization ---
    NS = winds.scenarios_nums
    NW = length(winds.index)
    Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

    # Linearize fuel cost curve (assuming function is in linearization.jl)
    refcost, eachslope = linearizationfuelcurve(units, NG; num_segments = config_param.num_segments)

    onoffinit = calculate_initial_unit_status(units, NG)

    # --- Model Creation ---
    Δp_contingency = define_contingency_size(units, NG)
    scuc = build_uc_model()
    # set_silent(scuc)
    # --- Define Variables ---
    # Define decision variables for the optimization model
    define_decision_variables!(scuc, NT, NG, ND, NC, ND2, NS, NW, config_param)

    # --- Set Objective ---
    # Set the objective function to be minimized
    set_objective!(scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

    println("subject to.") # Indicate the start of constraint definitions

    # --- Add Constraints ---
    # Add the constraints to the optimization model using the modular activator
    apply_scuc_constraints!(
        scuc, NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, loads, winds, lines, data_centers, psses, config_param, onoffinit, Gsdf, Δp_contingency,
    )

    # --- Solve and Extract Results ---
    # Solve the optimization model and extract the results
    try
        # Attempt to solve the SCUC model
        results = solve_and_extract_results(
            scuc, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob, eachslope, refcost, config_param, units, loads, winds, lines, data_centers;
            NB = NB,
        )

        # --- Return Results ---
        # Check if the optimization was successful
        if results !== nothing
            return results # Return the dictionary containing the optimization results
        else
            println("Optimization failed.")
            _report_infeasibility_conflict(scuc)
            return nothing
        end
    catch e
        # Catch any errors that occur during the optimization process
        println("An error occurred during optimization: ", e)
        _report_infeasibility_conflict(scuc)
        return nothing
    end
end # end SUC_scucmodel function
