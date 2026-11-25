# Environment configuration is loaded by the Benders setup entry point.
isdefined(@__MODULE__, :SUC_scucmodel) || include(joinpath(@__DIR__, "..", "..", "..", "unit_commitment", "scuc_model.jl"))

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
    scenarios_prob::Float64;
    storages = nothing,
)
    println("Initializing Benders Master Problem construction...")
    Δp_contingency = define_contingency_size(units, NG)
    scuc_masterproblem = build_uc_model(; silent = true)

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
    _master_supply_adequacy_constr =
        add_master_supply_adequacy_constraints!(
            scuc_masterproblem, NT, NG, ND, NW, units, loads, winds;
            storages = storages, NC = NC, NS = NS, consider_bess = config_param.consider_bess,
        )
    _master_storage_binary_constr = add_master_storage_binary_constraints!(scuc_masterproblem, NT, NC, NS, config_param)
    _frequency_constr = add_frequency_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, nothing, config_param, Δp_contingency; winds = winds)
    _master_freq_feas_constr = add_master_frequency_feasibility_cuts!(scuc_masterproblem, NT, NG, units, config_param; Δp_contingency = Δp_contingency)
    _master_freq_logic_constr = add_master_frequency_logic_cuts!(scuc_masterproblem, NT, NG, units, config_param; winds = winds, Δp_contingency = Δp_contingency)
    # add_curtailment_constraints!(scuc_masterproblem, NT, ND, NW, NS, loads, winds)
    # add_generator_power_constraints!(scuc_masterproblem, NT, NG, NS, units)
    # add_reserve_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, loads, winds, config_param)
    # add_power_balance_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
    # add_ramp_constraints!(scuc_masterproblem, NT, NG, NS, units, onoffinit)
    # add_pwl_constraints!(scuc_masterproblem, NT, NG, NS, units)
    # add_transmission_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, storages, Gsdf, config_param, ND2, data_centers)
    # add_storage_constraints!(scuc_masterproblem, NT, NC, NS, config_param, storages)
    # Data-center response variables are operational recourse variables. They are
    # not introduced in the first-stage Benders master; the subproblem uses the
    # continuous response-weight relaxation so dual cuts are available.
    # add_datacentra_constraints!(scuc_masterproblem, NT, NS, config_param, ND2, data_centers)
    # add_frequency_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, storages, config_param, Δp_contingency)

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
    all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets = reorganize_constraints_sets(all_constraints_dict)
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

"""Canonical BlueStyle alias for `bd_masterfunction` (标准命名入口: 构建 Benders 主问题)."""
const build_benders_master = bd_masterfunction

function add_master_storage_binary_constraints!(scuc_masterproblem::Model, NT::Int64, NC::Int64, NS::Int64, config_param::config)
    if config_param.consider_bess == 0 || NC == 0
        return nothing
    end
    κ⁺ = scuc_masterproblem[:κ⁺]
    κ⁻ = scuc_masterproblem[:κ⁻]
    α = scuc_masterproblem[:α]
    β = scuc_masterproblem[:β]

    exclusion = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t] <= 1)
    start_logic = @constraint(
        scuc_masterproblem,
        [s = 1:NS, c = 1:NC, t = 1:NT],
        α[(s - 1) * NC + c, t] >= κ⁺[(s - 1) * NC + c, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1])
    )
    stop_logic = @constraint(
        scuc_masterproblem,
        [s = 1:NS, c = 1:NC, t = 1:NT],
        β[(s - 1) * NC + c, t] >= ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]) - κ⁺[(s - 1) * NC + c, t]
    )
    start_state_upper = @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], α[(s - 1) * NC + c, t] <= κ⁺[(s - 1) * NC + c, t])
    start_prev_upper =
        @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], α[(s - 1) * NC + c, t] <= (t == 1 ? 1 : 1 - κ⁺[(s - 1) * NC + c, t - 1]))
    stop_prev_upper =
        @constraint(scuc_masterproblem, [s = 1:NS, c = 1:NC, t = 1:NT], β[(s - 1) * NC + c, t] <= (t == 1 ? 0 : κ⁺[(s - 1) * NC + c, t - 1]))
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

function add_master_supply_adequacy_constraints!(
    scuc_masterproblem::Model,
    NT::Int64,
    NG::Int64,
    ND::Int64,
    NW::Int64,
    units::unit,
    loads::load,
    winds::wind;
    storages = nothing,
    NC::Int64 = 0,
    NS::Int64 = 1,
    consider_bess::Int64 = 0,
)
    x = scuc_masterproblem[:x]
    wind_capacity = isempty(winds.p_max) ? 0.0 : sum(winds.p_max[:, 1])
    conservative_wind = [minimum(winds.scenarios_curve[:, t]) * wind_capacity for t in 1:NT]
    demand = [ND == 0 ? 0.0 : sum(loads.load_curve[d, t] for d in 1:ND) for t in 1:NT]
    max_fleet_pmax = sum(units.p_max[:, 1])
    use_bess = consider_bess == 1 && NC > 0 && storages !== nothing && !isempty(storages.p⁻) && haskey(JuMP.object_dictionary(scuc_masterproblem), :κ⁻)
    max_bess_discharge = use_bess ? sum(storages.p⁻; init = 0.0) : 0.0
    if any(t -> max_fleet_pmax + max_bess_discharge + conservative_wind[t] < demand[t], 1:NT)
        return nothing
    end

    if use_bess
        κ⁻ = scuc_masterproblem[:κ⁻]
        supply_adequacy = @constraint(
            scuc_masterproblem,
            [s = 1:NS, t = 1:NT],
            sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) +
            sum(storages.p⁻[c] * κ⁻[(s - 1) * NC + c, t] for c in 1:NC) +
            conservative_wind[t] >= demand[t]
        )
        reserve_adequacy = @constraint(
            scuc_masterproblem,
            [s = 1:NS, i = 1:NG, t = 1:NT],
            sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) +
            sum(storages.p⁻[c] * κ⁻[(s - 1) * NC + c, t] for c in 1:NC) +
            conservative_wind[t] >= demand[t] + 0.5 * units.p_max[i, 1] * x[i, t]
        )
    else
        supply_adequacy = @constraint(scuc_masterproblem, [t = 1:NT], sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) + conservative_wind[t] >= demand[t])
        reserve_adequacy = @constraint(
            scuc_masterproblem,
            [i = 1:NG, t = 1:NT],
            sum(units.p_max[g, 1] * x[g, t] for g in 1:NG) + conservative_wind[t] >= demand[t] + 0.5 * units.p_max[i, 1] * x[i, t]
        )
    end
    println("\t constraints: master supply adequacy cuts\t\t\t\t done")
    return (supply = supply_adequacy, reserve = reserve_adequacy)
end

function add_master_frequency_feasibility_cuts!(
    scuc_masterproblem::Model,
    NT::Int64,
    NG::Int64,
    units::unit,
    config_param::config;
    Δp_contingency::Real = maximum(units.p_max),
)
    if config_param.consider_frequency_control == 0 || !haskey(JuMP.object_dictionary(scuc_masterproblem), :x)
        return nothing
    end
    x = scuc_masterproblem[:x]
    frequency_base_hz = frequency_env_float("FREQUENCY_BASE_HZ", 50.0)
    qss_limit_hz = frequency_env_float("FREQUENCY_QSS_LIMIT_HZ", 5.0)
    nadir_limit_hz = max(frequency_env_float("FREQUENCY_NADIR_LIMIT_HZ", qss_limit_hz), eps(Float64))
    fcr_threshold = frequency_env_float("FREQUENCY_FCR_THRESHOLD", 0.025)
    qss_contingency = frequency_contingency_size(units, Δp_contingency)
    damping_pu = qss_limit_hz / max(frequency_base_hz, eps(Float64))

    # Exact first-stage projections of subproblem (sr⁺, x) frequency reserve bounds:
    # 1) Per-unit SFR reserve lower bound <= generator headroom (p_max - p_min)
    sfr_unit_feas = ConstraintRef[]
    for i in 1:NG
        sfr_req = unit_primary_response_coeff(units, i) * nadir_limit_hz * fcr_threshold
        headroom = max(0.0, safe_frequency_coeff(units.p_max, i) - safe_frequency_coeff(units.p_min, i))
        if sfr_req > headroom + 1.0e-9
            for t in 1:NT
                push!(sfr_unit_feas, @constraint(scuc_masterproblem, x[i, t] == 0))
            end
        end
    end

    # 2) System QSS headroom + damping >= contingency
    qss_headroom = @constraint(
        scuc_masterproblem,
        [t = 1:NT],
        sum(
            (max(0.0, safe_frequency_coeff(units.p_max, i) - safe_frequency_coeff(units.p_min, i)) +
             safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * damping_pu) * x[i, t] for i in 1:NG
        ) >= qss_contingency
    )
    println("\t constraints: master frequency reserve feasibility cuts\t\t done")
    return (sfr_unit_feas = sfr_unit_feas, qss_headroom = qss_headroom)
end

function _min_cardinality_for_threshold(weights::Vector{Float64}, threshold::Float64)
    threshold <= 1.0e-9 && return 0
    sorted = sort(weights; rev = true)
    acc = 0.0
    for (k, w) in enumerate(sorted)
        acc += max(0.0, w)
        acc + 1.0e-9 >= threshold && return k
    end
    return length(weights) + 1
end

function _collect_cover_logic_masks!(covers::Set{BitVector}, weights::Vector{Float64}, threshold::Float64)
    NG = length(weights)
    (NG == 0 || threshold <= 1.0e-9) && return covers
    total_w = sum(max.(0.0, weights))
    total_w + 1.0e-9 < threshold && return covers

    # 1. Greedy maximal infeasible subset (ascending weight) -> minimal cover on complement
    asc = sortperm(weights)
    acc = 0.0
    in_S = falses(NG)
    for i in asc
        w = max(0.0, weights[i])
        if acc + w < threshold - 1.0e-9
            acc += w
            in_S[i] = true
        else
            break
        end
    end
    cover = .!in_S
    if any(cover) && count(cover) < NG
        push!(covers, cover)
    end

    # 2. Leave-one-out mandatory units: if total_w - w_j < threshold, unit j must be online
    for j in 1:NG
        if total_w - max(0.0, weights[j]) < threshold - 1.0e-9
            unit_cover = falses(NG)
            unit_cover[j] = true
            push!(covers, unit_cover)
        end
    end
    return covers
end

"""
    add_master_frequency_logic_cuts!(scuc_masterproblem, NT, NG, units, config_param; winds = nothing, Δp_contingency = maximum(units.p_max))

Exploit the commitment-only, monotone structure of frequency security constraints
(`RoCoF`, `QSS`, and `H–D` cuts depend solely on `x[:, t]`) to add exact logic cuts:
1. Minimum online-unit cardinality cut: `sum(x[:, t]) >= k_min` for all `t`.
2. Mandatory critical-unit & minimal cover logic cuts: `sum(x[i, t] for i in cover) >= 1` for all `t`.
"""
function add_master_frequency_logic_cuts!(
    scuc_masterproblem::Model,
    NT::Int64,
    NG::Int64,
    units::unit,
    config_param::config;
    winds = nothing,
    Δp_contingency::Real = maximum(units.p_max),
)
    if config_param.consider_frequency_control == 0 ||
       !haskey(JuMP.object_dictionary(scuc_masterproblem), :x) ||
       !uc_env_bool("BENDERS_ENABLE_FREQUENCY_LOGIC_CUTS", true)
        return nothing
    end
    x = scuc_masterproblem[:x]
    f0_hz = frequency_env_float("FREQUENCY_BASE_HZ", 50.0)
    rocof_limit = frequency_env_float("FREQUENCY_ROCOF_LIMIT_HZ_PER_S", 5.0)
    qss_limit = frequency_env_float("FREQUENCY_QSS_LIMIT_HZ", 5.0)
    contingency = frequency_contingency_size(units, Δp_contingency)
    wind_support = wind_frequency_capacity_support(winds)
    damping_pu = qss_limit / max(f0_hz, eps(Float64))

    inertia_weights = [2.0 * safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) for i in 1:NG]
    rocof_req = max(0.0, contingency * f0_hz / max(rocof_limit, eps(Float64)) - wind_support.inertia)

    qss_weights = [
        max(0.0, safe_frequency_coeff(units.p_max, i) - safe_frequency_coeff(units.p_min, i)) +
        safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * damping_pu for i in 1:NG
    ]

    k_min = max(
        _min_cardinality_for_threshold(inertia_weights, rocof_req),
        _min_cardinality_for_threshold(qss_weights, contingency),
    )

    covers = Set{BitVector}()
    _collect_cover_logic_masks!(covers, inertia_weights, rocof_req)
    _collect_cover_logic_masks!(covers, qss_weights, contingency)

    if frequency_model_mode() in (:hd_region, :hybrid) && isdefined(@__MODULE__, :extract_uc_hd_parameters)
        hd_params = extract_uc_hd_parameters(units, winds, Δp_contingency)
        hd_region = assess_hd_frequency_region(hd_params)
        if !isempty(hd_region.feasible_indices)
            hd_cuts = build_hd_linear_cuts(hd_region; max_cuts = max(1, floor(Int, frequency_env_float("FREQUENCY_HD_MAX_CUTS", 6.0))))
            s_base = frequency_sum_apparent_power(units, winds)
            h_pu = [safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) / s_base for i in 1:NG]
            d_pu = [safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) / s_base for i in 1:NG]
            k_min = max(k_min, _min_cardinality_for_threshold(h_pu, hd_cuts.H_min_sync))
            _collect_cover_logic_masks!(covers, h_pu, hd_cuts.H_min_sync)
            if hd_cuts.D_min_sync > 0.0
                k_min = max(k_min, _min_cardinality_for_threshold(d_pu, hd_cuts.D_min_sync))
                _collect_cover_logic_masks!(covers, d_pu, hd_cuts.D_min_sync)
            end
            for m in eachindex(hd_cuts.alpha)
                combo = h_pu .+ hd_cuts.beta[m] .* d_pu
                k_min = max(k_min, _min_cardinality_for_threshold(combo, hd_cuts.alpha[m]))
                _collect_cover_logic_masks!(covers, combo, hd_cuts.alpha[m])
            end
        end
    end

    cardinality_constr = if 1 <= k_min <= NG
        @constraint(scuc_masterproblem, [t = 1:NT], sum(x[i, t] for i in 1:NG) >= k_min)
    else
        nothing
    end

    cover_constrs = ConstraintRef[]
    for cover in covers
        idxs = findall(cover)
        isempty(idxs) && continue
        for t in 1:NT
            push!(cover_constrs, @constraint(scuc_masterproblem, sum(x[i, t] for i in idxs) >= 1))
        end
    end
    println("\t constraints: master frequency logic cuts (k_min=$(k_min), covers=$(length(covers)))\t done")
    return (k_min = k_min, cardinality = cardinality_constr, covers = cover_constrs)
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

    if config_param.consider_multi_cuts == 1
        @variable(scuc_masterproblem, θ[1:NS] >= 0)
    else
        @variable(scuc_masterproblem, θ >= 0)
    end

    # @variable(scuc_masterproblem, pg[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, sr⁺[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, sr⁻[1:(NG * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, Δpd[1:(ND * NS), 1:NT]>=0)
    # @variable(scuc_masterproblem, Δpw[1:(NW * NS), 1:NT]>=0)

    if config_param.consider_bess == 1 && NC > 0
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

    # # Frequency control related variables (assuming these might be needed based on later constraints)
    # # Check if these are actually used/defined in the constraints file later
    # if config_param.consider_frequency_control == 1 # Assuming flag exists
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
    c₀ = config_param.coal_price  # Reference fuel/coal price factor

    # Penalty weights for load shed and wind curtailment (often used in subproblem recourse)
    load_curtailment_penalty = uc_load_curtailment_penalty(config_param)
    wind_curtailment_penalty = uc_wind_curtailment_penalty(config_param)

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
    recourse_approx = config_param.consider_multi_cuts == 1 ? sum(θ[s] for s in 1:NS) : θ
    obj = @objective(scuc_masterproblem, Min, sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) + recourse_approx)

    println("\t MILP_type objective_function \t\t\t\t\t\t done")
    return scuc_masterproblem, obj
end
