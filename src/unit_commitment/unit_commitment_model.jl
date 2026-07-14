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
	SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)

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
- `DataCentras::data_centra`: Data center data
- `config_param::config`: Configuration parameters
- `stroges::Any`: Storage system data (Type Any for flexibility, consider defining a specific struct)
- `scenarios_prob::Float64`: Probability of scenarios (Assumed equal for now if calculated as 1/NS)
- `NL::Int64`: Number of transmission lines

# Returns
- Dictionary containing optimization results, or nothing if optimization fails.
"""

# NOTE - function module

function SUC_scucmodel(
    NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64,
    units::unit, loads::load, winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config, stroges::Any,
    scenarios_prob::Float64, NL::Int64,
)
    println("Step-3: Creating dispatching model (Refactored & Modularized)")

    # --- Input Validation ---
    if !validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)
        error("Input validation failed. Check your data.")
    end

    # --- Initialization ---
    NS = winds.scenarios_nums
    NW = length(winds.index)
    Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

    # Linearize fuel cost curve (assuming function is in linearization.jl)
    refcost, eachslope = linearizationfuelcurve(units, NG)

    onoffinit = calculate_initial_unit_status(units, NG)

    # --- Model Creation ---
    Δp_contingency = define_contingency_size(units, NG)
    scuc = Model(Gurobi.Optimizer)
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
        scuc, NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, loads, winds, lines, DataCentras, stroges, config_param, onoffinit, Gsdf, Δp_contingency,
    )

    # --- Solve and Extract Results ---
    # Solve the optimization model and extract the results
    try
        # Attempt to solve the SCUC model
        results = solve_and_extract_results(
            scuc, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob, eachslope, refcost, config_param, units, loads, winds, lines, DataCentras,
        )

        # --- Return Results ---
        # Check if the optimization was successful
        if results !== nothing
            return results # Return the dictionary containing the optimization results
        else
            # Handle optimization failure
            println("Optimization failed. Computing Gurobi IIS...")
            try
                compute_iis(scuc)
                write_iis(scuc, "model.iis")
                println("IIS written to model.iis:")
                for line in readlines("model.iis")[1:min(100, end)]
                    println(line)
                end
            catch err
                println("Failed to compute IIS: ", err)
            end
            return nothing
        end
    catch e
        # Catch any errors that occur during the optimization process
        println("An error occurred during optimization: ", e)
        println("Computing Gurobi IIS to diagnose infeasibility...")
        try
            JuMP.compute_conflict!(scuc)
            println("IIS computation completed. Conflicting constraints:")
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
            println("Failed to compute IIS: ", err)
        end
        return nothing
    end
end # end SUC_scucmodel function
