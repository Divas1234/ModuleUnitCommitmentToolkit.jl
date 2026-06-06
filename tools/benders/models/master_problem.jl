# include(joinpath(pwd(), "src", "environment_config.jl"))
include(joinpath(pwd(), "src", "unit_commitment", "unit_commitment_model.jl"))

"""
`bd_masterfunction(...)`

Main entry point for constructing the Benders Master Problem. 
This function initializes the JuMP model, defines first-stage decision variables 
(commitment, startup, shutdown), adds basic operational constraints, and sets the 
lower-bound objective.

# Returns
- A tuple: `(scuc_masterproblem::Model, master_scuc_struct::SCUCM_Model)`
"""
function bd_masterfunction(
    NT::Int64,
    NB::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NS::Int64,
    NW::Int64,
    units::unit,
    loads::load,
    winds::wind,
    config_param::config,
    scenarios_prob::Float64,
)
    println("Initializing Benders Master Problem construction...")
    Δp_contingency = define_contingency_size(units, NG)
    scuc_masterproblem = Model(Gurobi.Optimizer)
    set_silent(scuc_masterproblem)

    # set_silent(scuc_masterproblem)
    # --- Define Variables ---
    # Define decision variables for the optimization model
    scuc_masterproblem, x, u, v, su₀, sd₀, κ⁺, κ⁻, α, β, θ =
        define_masterproblem_decision_variables!(scuc_masterproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
    pg₀ = sr⁺ = sr⁻ = Δpd = Δpw = pc⁺ = pc⁻ = qc = pss_sumchargeenergy = Matrix{VariableRef}(undef, 0, 0)
    pgₖ = Array{VariableRef, 3}(undef, 0, 0, 0)
    # NOTE - save the decision variables in a dictionary for easy access
    # master_vars = SCUCModel_decision_variables(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β, θ)
    master_vars = build_decision_variables(; u, x, v, su₀, sd₀, κ⁺, κ⁻, α, β, θ)

    # --- Set Objective ---
    # Set the objective function to be minimized
    scuc_masterproblem, obj =
        set_masterproblem_objective_economic!(scuc_masterproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)

    # NOTE - save the objective function in a dictionary for easy access
    master_obj = SCUCModel_objective_function(obj)

    # println("subject to.") # Indicate the start of constraint definitions

    # M = 1e3
    all_constr_sets = []
    onoffinit = calculate_initial_unit_status(units, NG)

    # --- Add Constraints ---
    # Add the constraints to the optimization model
    scuc_masterproblem,
    _units_minuptime_constr,
    _units_mindowntime_constr,
    _units_init_stateslogic_consist_constr,
    _units_states_consist_constr,
    _units_init_shutup_cost_constr,
    _units_init_shutdown_cost_constr,
    _units_shutup_cost_constr,
    _units_shutdown_cost_constr = add_unit_operation_constraints!(scuc_masterproblem, NT, NG, units, onoffinit)
    _master_supply_adequacy_constr = add_master_supply_adequacy_constraints!(scuc_masterproblem, NT, NG, ND, NW, units, loads, winds)
    _master_storage_binary_constr = add_master_storage_binary_constraints!(scuc_masterproblem, NT, NC, NS, config_param)
    # add_curtailment_constraints!(scuc_masterproblem, NT, ND, NW, NS, loads, winds)
    # add_generator_power_constraints!(scuc_masterproblem, NT, NG, NS, units)
    # add_reserve_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, loads, winds, config_param)
    # add_power_balance_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
    # add_ramp_constraints!(scuc_masterproblem, NT, NG, NS, units, onoffinit)
    # add_pwl_constraints!(scuc_masterproblem, NT, NG, NS, units)
    # add_transmission_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras)
    # add_storage_constraints!(scuc_masterproblem, NT, NC, NS, config_param, stroges)
    # add_datacentra_constraints!(scuc_masterproblem, NT, NS, config_param, ND2, DataCentras)
    # add_frequency_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)

    if get(ENV, "BENDERS_SHOW_MODEL_SUMMARY", "0") == "1"
        println("\n")
        @show scuc_masterproblem
        println("\n")
    end

    all_constraints_dict = Dict{Symbol, Any}()
    all_constraints_dict[:key_units_minuptime_constr] = vec(_units_minuptime_constr)
    all_constraints_dict[:key_units_mindowntime_constr] = vec(_units_mindowntime_constr)
    all_constraints_dict[:key_units_init_stateslogic_consist_constr] = vec(_units_init_stateslogic_consist_constr)
    all_constraints_dict[:key_units_states_consist_constr] = vec(_units_states_consist_constr)
    all_constraints_dict[:key_units_init_shutup_cost_constr] = vec(_units_init_shutup_cost_constr)
    all_constraints_dict[:key_units_init_shutdown_cost_constr] = vec(_units_init_shutdown_cost_constr)
    all_constraints_dict[:key_units_shutup_cost_constr] = vec(collect(Iterators.flatten(_units_shutup_cost_constr.data)))
    all_constraints_dict[:key_units_shutdown_cost_constr] = vec(collect(Iterators.flatten(_units_shutdown_cost_constr.data)))
    fields = [Symbol(string(k)[5:end]) for k in keys(all_constraints_dict) if startswith(string(k), "key_")]
    master_cons = build_constraints(; (f => all_constraints_dict[Symbol("key_", f)] for f in fields)...)

    # NOTE - save the reformated constraints in a dictionary for easy access
    all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets = reorginze_constraints_sets(all_constraints_dict)
    master_reformat_cons = SCUCModel_reformat_constraints(all_constr_equalto_sets, all_constr_greaterthan_sets, all_constr_lessthan_sets)

    # all_reorginzed_constraints_dict = Dict{Symbol, Any}()
    # all_reorginzed_constraints_dict[:LessThan] = collect(Iterators.flatten(all_constr_lessthan_sets))
    # all_reorginzed_constraints_dict[:GreaterThan] = collect(Iterators.flatten(all_constr_greaterthan_sets))
    # all_reorginzed_constraints_dict[:EqualTo] = collect(Iterators.flatten(all_constr_equalto_sets))

    # master_reformat_cons = SCUCModel_reformat_constraints(
    # 	[vec(all_reorginzed_constraints_dict[key])
    # 	 for key in [
    # 		:EqualTo, :GreaterThan, :LessThan
    # 	]]...
    # )

    # NOTE - save all scuc model components in struct! SCUC_model
    master_scuc_struct = SCUC_Model(
        scuc_masterproblem::Model,
        master_vars::SCUCModel_decision_variables,
        master_obj::SCUCModel_objective_function,
        master_cons::SCUCModel_constraints,
        master_reformat_cons::SCUCModel_reformat_constraints,
    )

    return scuc_masterproblem, master_scuc_struct
end

function add_master_storage_binary_constraints!(scuc_masterproblem::Model, NT::Int64, NC::Int64, NS::Int64, config_param::config)
    if config_param.is_ConsiderBESS == 0 || NC == 0
        return nothing
    end
    κ⁺ = scuc_masterproblem[:κ⁺]
    κ⁻ = scuc_masterproblem[:κ⁻]
    α = scuc_masterproblem[:α]
    β = scuc_masterproblem[:β]

    exclusion = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t] <= 1)
    start_logic = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], α[(s - 1) * NC + c, t] >= κ⁺[(s - 1) * NC + c, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]))
    stop_logic = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], β[(s - 1) * NC + c, t] >= ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]) - κ⁺[(s - 1) * NC + c, t])
    start_state_upper = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], α[(s - 1) * NC + c, t] <= κ⁺[(s - 1) * NC + c, t])
    start_prev_upper = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], α[(s - 1) * NC + c, t] <= (t == 1 ? 1 : 1 - κ⁺[(s - 1) * NC + c, t - 1]))
    stop_prev_upper = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], β[(s - 1) * NC + c, t] <= (t == 1 ? 0 : κ⁺[(s - 1) * NC + c, t - 1]))
    stop_state_upper = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], β[(s - 1) * NC + c, t] <= 1 - κ⁺[(s - 1) * NC + c, t])
    start_cycle_limit = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC], sum(α[(s - 1) * NC + c, t] for t in 1:NT) <= 5)
    stop_cycle_limit = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC], sum(β[(s - 1) * NC + c, t] for t in 1:NT) <= 5)

    println("\t constraints: master storage binary logic\t\t\t\t done")
    return (
        exclusion = exclusion,
        start_logic = start_logic,
        stop_logic = stop_logic,
        start_state_upper = start_state_upper,
        start_prev_upper = start_prev_upper,
        stop_prev_upper = stop_prev_upper,
        stop_state_upper = stop_state_upper,
        start_cycle_limit = start_cycle_limit,
        stop_cycle_limit = stop_cycle_limit,
    )
end

function add_master_supply_adequacy_constraints!(scuc_masterproblem::Model, NT::Int64, NG::Int64, ND::Int64, NW::Int64, units::unit, loads::load, winds::wind)
    x = scuc_masterproblem[:x]
    wind_capacity = sum(winds.p_max[:, 1])
    conservative_wind = [minimum(winds.scenarios_curve[:, t]) * wind_capacity for t in 1:NT]
    demand = [sum(loads.load_curve[d, t] for d in 1:ND) for t in 1:NT]

    supply_adequacy = @constraint(
        scuc_masterproblem,
        [t = 1:NT],
        sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) + conservative_wind[t] >= demand[t]
    )
    reserve_adequacy = @constraint(
        scuc_masterproblem,
        [i = 1:NG, t = 1:NT],
        sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) + conservative_wind[t] >= demand[t] + 0.5 * units.p_max[i, 1] * x[i, t]
    )
    println("\t constraints: master supply adequacy cuts\t\t\t\t done")
    return (supply = supply_adequacy, reserve = reserve_adequacy)
end

# Helper function to define first-stage decision variables
"""
`define_masterproblem_decision_variables!(...)`

Adds first-stage variables to the master problem:
- `x`, `u`, `v`: Binary variables for unit status, startup, and shutdown.
- `su₀`, `sd₀`: Non-negative variables for modeling startup/shutdown costs.
- `θ`: The future cost approximation variable (Benders cut interface).
"""
function define_masterproblem_decision_variables!(scuc_masterproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
    # --- Binary Decision Variables ---
    # x: Unit on/off state; u: Startup flag; v: Shutdown flag
    @variable(scuc_masterproblem, x[1:NG, 1:NT], Bin)
    @variable(scuc_masterproblem, u[1:NG, 1:NT], Bin)
    @variable(scuc_masterproblem, v[1:NG, 1:NT], Bin)

    # --- Continuous Decision Variables ---
    # su0/sd0: Explicit startup/shutdown cost auxiliary variables
    @variable(scuc_masterproblem, su₀[1:NG, 1:NT] >= 0)
    @variable(scuc_masterproblem, sd₀[1:NG, 1:NT] >= 0)

    if config_param.is_ConsiderMultiCUTs == 1
        @variable(scuc_masterproblem, θ[1:NS] >= 0)
    else
        @variable(scuc_masterproblem, θ >= 0)
    end

    # @variable(scuc_masterproblem, pg[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, sr⁺[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, sr⁻[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, Δpd[1:(ND * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, Δpw[1:(NW * NS), 1:NT]>=0)

    if config_param.is_ConsiderBESS == 1 && NC > 0
        @variable(scuc_masterproblem, κ⁺[1:(NC * NS), 1:NT], Bin)
        @variable(scuc_masterproblem, κ⁻[1:(NC * NS), 1:NT], Bin)
        @variable(scuc_masterproblem, α[1:(NC * NS), 1:NT], Bin)
        @variable(scuc_masterproblem, β[1:(NC * NS), 1:NT], Bin)
    else
        κ⁺ = Matrix{VariableRef}(undef, 0, 0)
        κ⁻ = Matrix{VariableRef}(undef, 0, 0)
        α = Matrix{VariableRef}(undef, 0, 0)
        β = Matrix{VariableRef}(undef, 0, 0)
    end

    # if config_param.is_ConsiderDataCentra == 1
    # 	@variable(scuc_masterproblem, dc_p[1:(ND2 * NS), 1:NT]>=0)
    # 	@variable(scuc_masterproblem, dc_f[1:(ND2 * NS), 1:NT]>=0)
    # 	# @variable(scuc_masterproblem, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
    # 	@variable(scuc_masterproblem, dc_v²[1:(ND2 * NS), 1:NT]>=0)
    # 	@variable(scuc_masterproblem, dc_λ[1:(ND2 * NS), 1:NT]>=0)
    # 	@variable(scuc_masterproblem, dc_Δu1[1:(ND2 * NS), 1:NT]>=0)
    # 	@variable(scuc_masterproblem, dc_Δu2[1:(ND2 * NS), 1:NT]>=0)
    # end

    # # Frequency control related variables (assuming these might be needed based on later constraints)
    # # Check if these are actually used/defined in the constraints file later
    # if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
    # 	@variable(scuc_masterproblem, Δf_nadir[1:NS]>=0)
    # 	@variable(scuc_masterproblem, Δf_qss[1:NS]>=0)
    # 	@variable(scuc_masterproblem, Δp_imbalance[1:NS]>=0) # Placeholder, adjust as needed based on full constraints
    # end

    # println("\t Variables defined.")
    return scuc_masterproblem, x, u, v, su₀, sd₀, κ⁺, κ⁻, α, β, θ
end

"""
`set_masterproblem_objective_economic!(...)`

Defines the master problem's objective function (minimizing startup/shutdown costs + the recourse cost θ).
"""
function set_masterproblem_objective_economic!(scuc_masterproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)
    # Economic parameters
    c₀ = config_param.is_CoalPrice  # Reference fuel/coal price factor

    # Penalty weights for load shed and wind curtailment (often used in subproblem recourse)
    load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
    wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

    # Penalty coefficients for violations
    ρ⁺ = c₀ * 2
    ρ⁻ = c₀ * 2

    x = scuc_masterproblem[:x]
    su₀ = scuc_masterproblem[:su₀]
    sd₀ = scuc_masterproblem[:sd₀]
    θ = scuc_masterproblem[:θ]
    # pgₖ = scuc_masterproblem[:pgₖ]
    # sr⁺ = scuc_masterproblem[:sr⁺]
    # sr⁻ = scuc_masterproblem[:sr⁻]
    # Δpd = scuc_masterproblem[:Δpd]
    # Δpw = scuc_masterproblem[:Δpw]

    # @objective(scuc_masterproblem,
    # 	Min,
    # 	sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) + pₛ * c₀ * sum(sum(sum(θ[((s - 1) * NG + 1):(s * NG), t] for t in 1:NT) for s in 1:NS)))
    recourse_approx = config_param.is_ConsiderMultiCUTs == 1 ? sum(θ[s] for s in 1:NS) : θ
    obj = @objective(scuc_masterproblem, Min, sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) + recourse_approx)

    println("\t MILP_type objective_function \t\t\t\t\t\t done")
    return scuc_masterproblem, obj
end
