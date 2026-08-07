# ============================================================================
# Adaptive Overlapping Rolling-Horizon Unit Commitment Modules
#
# This module implements:
# 1. Classification of slow-start vs fast-start generators
# 2. Boundary sensitivity decay factor calculation for steady state
# 3. Strong net-load ramping event detection for tight-balance periods
# 4. Composite adaptive overlapping window calculation
# 5. Boundary condition transmission from committed execution windows
# ============================================================================

include("period_scuc_modules.jl")

"""
    classify_generator_speed(units::unit; slow_threshold::Float64 = 4.0)

Classify generators into slow-start and fast-start units based on minimum up/down times.

# Returns
- `slow_unit_indices::Vector{Int64}`: Indices of slow-start units
- `fast_unit_indices::Vector{Int64}`: Indices of fast-start units
- `T_unit_overlap::Int64`: Required overlap time to cover slow unit dwell constraints
"""
function classify_generator_speed(units::unit; slow_threshold::Float64 = 4.0)
    NG = length(units.index)
    slow_unit_indices = Int64[]
    fast_unit_indices = Int64[]
    max_slow_dwell = 0.0

    for i in 1:NG
        max_dwell = max(units.min_shutup_time[i], units.min_shutdown_time[i])
        if max_dwell >= slow_threshold
            push!(slow_unit_indices, i)
            if max_dwell > max_slow_dwell
                max_slow_dwell = max_dwell
            end
        else
            push!(fast_unit_indices, i)
        end
    end

    T_unit_overlap = Int64(ceil(max_slow_dwell))
    return slow_unit_indices, fast_unit_indices, T_unit_overlap
end

"""
    calculate_boundary_sensitivity_decay(alpha::Float64, epsilon::Float64)

Calculate steady-state overlap window length based on boundary sensitivity decay factor alpha.
Decay formula: S(k) = (1 - alpha)^k <= epsilon.

# Returns
- `T_steady_overlap::Int64`: Minimum steady-state overlap window size
"""
function calculate_boundary_sensitivity_decay(alpha::Float64, epsilon::Float64)
    if alpha <= 0.0 || alpha >= 1.0
        error("Boundary sensitivity decay factor alpha must be in (0, 1). Got: $alpha")
    end
    # (1 - alpha)^k <= epsilon  =>  k >= log(epsilon) / log(1 - alpha)
    k = ceil(Int64, log(epsilon) / log(1.0 - alpha))
    return max(1, k)
end

"""
    detect_ramp_events_and_overlap(loads::load, winds::wind, start_time::Int64, exec_NT::Int64, max_lookahead::Int64, ramp_threshold_ratio::Float64 = 1.25)

Detect net-load ramping / tight-balance events in the lookahead horizon and calculate required adaptive ramp overlap window.

# Returns
- `is_ramp_event::Bool`: Whether a strong ramping event is detected in the lookahead horizon
- `T_ramp_overlap::Int64`: Required overlap window length to envelop the ramping event
"""
function detect_ramp_events_and_overlap(
    loads::load,
    winds::wind,
    start_time::Int64,
    exec_NT::Int64,
    max_lookahead::Int64,
    ramp_threshold_ratio::Float64 = 1.25,
)
    total_time_avail = size(loads.load_curve, 2)
    end_horizon = min(total_time_avail, start_time + exec_NT + max_lookahead - 1)
    
    if end_horizon <= start_time + exec_NT
        return false, 0
    end

    # Aggregate system net load P_net(t) = P_load(t) - P_wind_mean(t)
    total_load = sum(loads.load_curve[:, start_time:end_horizon], dims = 1)[1, :]
    total_wind = sum(winds.p_max) .* winds.scenarios_curve[1, start_time:end_horizon]
    net_load = total_load .- total_wind

    # Compute absolute ramp rates
    N_pts = length(net_load)
    ramp_rates = [abs(net_load[t+1] - net_load[t]) for t in 1:(N_pts - 1)]

    mean_ramp = mean(ramp_rates)
    ramp_threshold = ramp_threshold_ratio * mean_ramp

    # Check lookahead region (past execution window)
    lookahead_start_idx = exec_NT
    lookahead_ramp_rates = ramp_rates[lookahead_start_idx:end]

    peak_ramp_idx = findfirst(r -> r >= ramp_threshold, lookahead_ramp_rates)

    if peak_ramp_idx !== nothing
        # Required lookahead overlap to cover the ramping event (relative to exec_NT) plus 2h buffer
        T_ramp_overlap = peak_ramp_idx + 2
        T_ramp_overlap = min(T_ramp_overlap, max_lookahead)
        return true, T_ramp_overlap
    else
        return false, 0
    end
end

"""
    compute_adaptive_overlap_window(
        loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64,
        alpha::Float64, epsilon::Float64, min_overlap::Int64, max_overlap::Int64
    )

Compute composite adaptive overlapping window size considering:
1. Steady-state boundary sensitivity decay
2. Slow-start generator dwell requirements
3. Strong net-load ramping event coverage
"""
function compute_adaptive_overlap_window(
    loads::load,
    winds::wind,
    units::unit,
    start_time::Int64,
    exec_NT::Int64,
    alpha::Float64 = 0.25,
    epsilon::Float64 = 0.05,
    min_overlap::Int64 = 2,
    max_overlap::Int64 = 12,
)
    # 1. Steady-state decay window
    T_steady = calculate_boundary_sensitivity_decay(alpha, epsilon)

    # 2. Slow unit dwell requirement
    _, _, T_unit = classify_generator_speed(units; slow_threshold = 4.0)

    # 3. Strong ramping event detection
    is_ramp, T_ramp = detect_ramp_events_and_overlap(loads, winds, start_time, exec_NT, max_overlap)

    # Composite overlap calculation
    T_overlap_raw = max(T_steady, T_unit, T_ramp)
    T_overlap = clamp(T_overlap_raw, min_overlap, max_overlap)

    # Ensure total window does not exceed remaining simulation time
    total_time_avail = size(loads.load_curve, 2)
    max_possible_overlap = total_time_avail - (start_time + exec_NT - 1)
    T_overlap = max(0, min(T_overlap, max_possible_overlap))

    return T_overlap, is_ramp, T_steady, T_unit, T_ramp
end

"""
    update_adaptive_boundary_conditions(
        interval_scheduling_id::Int64,
        NG::Int64,
        exec_NT::Int64,
        total_NT::Int64,
        start_time::Int64,
        units::unit,
        loads::load,
        winds::wind,
        results::Union{Dict{String, Array{Float64}}, Nothing}
    )

Update initial boundary conditions and slice time-series inputs for an adaptive window simulation.
Boundary conditions (x_0, p_0, t_0, t_1) are extracted from time step `exec_NT` of previous results.
"""
function update_adaptive_boundary_conditions(
    interval_scheduling_id::Int64,
    NG::Int64,
    exec_NT::Int64,
    total_NT::Int64,
    start_time::Int64,
    units::unit,
    loads::load,
    winds::wind,
    results::Union{Dict{String, Array{Float64}}, Nothing},
)
    mini_units = deepcopy(units)
    
    if interval_scheduling_id != 1 && results !== nothing
        # Extract initial state from end of committed execution window (exec_NT) of prior interval
        mini_units.x_0 = results["x₀"][:, exec_NT]
        mini_units.p_0 = results["p₀"][:, exec_NT]

        # Calculate remaining dwell times up to step exec_NT
        u_sub = results["u₀"][:, 1:exec_NT]
        v_sub = results["v₀"][:, 1:exec_NT]
        res_up, res_down = get_generators_upoff_durations(units, u_sub, v_sub, NG)
        mini_units.t_0 = res_up[:, 1]
        mini_units.t_1 = res_down[:, 1]
    end

    to_time = start_time + total_NT - 1

    mini_loads = deepcopy(loads)
    mini_loads.load_curve = loads.load_curve[:, start_time:to_time]

    mini_winds = deepcopy(winds)
    mini_winds.scenarios_curve = winds.scenarios_curve[:, start_time:to_time]

    return mini_units, mini_loads, mini_winds
end

"""
    truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)

Extract and return only the committed execution period (1:exec_NT) from total window results.
"""
function truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)
    committed_results = Dict{String, Array{Float64}}()
    for (k, v) in results
        if ndims(v) == 2 && size(v, 2) >= exec_NT
            committed_results[k] = v[:, 1:exec_NT]
        elseif ndims(v) == 3 && size(v, 2) >= exec_NT
            committed_results[k] = v[:, 1:exec_NT, :]
        elseif ndims(v) == 1
            committed_results[k] = v
        else
            committed_results[k] = v
        end
    end
    return committed_results
end

"""
    compute_committed_cost(
        committed_results::Dict{String, Array{Float64}},
        exec_NT::Int64,
        units::unit,
        loads::load,
        winds::wind,
        lines::transmissionline,
        DataCentras::data_centra,
        config_param::config,
        interval_scheduling_id::Int64,
        hydros::hydro,
        scenarios_prob::Float64
    )

Compute 1x7 scheduling cost vector for the committed execution period (1:exec_NT).
"""
function compute_committed_cost(
    committed_results::Dict{String, Array{Float64}},
    exec_NT::Int64,
    units::unit,
    loads::load,
    winds::wind,
    lines::transmissionline,
    DataCentras::data_centra,
    config_param::config,
    interval_scheduling_id::Int64,
    hydros::hydro,
    scenarios_prob::Float64
)
    NS = winds.scenarios_nums
    NW = length(winds.index)
    NG = length(units.index)
    NB = length(units.locatebus)
    ND = length(loads.locatebus)
    NC = 0
    ND2 = length(DataCentras.locatebus)
    NH = length(hydros.locatebus)

    refcost, eachslope = linearizationfuelcurve(units, NG)

    committed_winds = deepcopy(winds)
    committed_winds.scenarios_curve = winds.scenarios_curve[:, 1:exec_NT]

    su_cost = committed_results["su_cost"]
    sd_cost = committed_results["sd_cost"]
    pgₖ = committed_results["pₖ"]
    pg₀ = committed_results["p₀"]
    x₀ = committed_results["x₀"]
    seq_sr⁺ = committed_results["seq_sr⁺"]
    seq_sr⁻ = committed_results["seq_sr⁻"]
    pᵨ = committed_results["pᵨ"]
    pᵩ = committed_results["pᵩ"]

    # Set global scenarios_prob if required by exported_scheduling_cost
    global scenarios_prob = scenarios_prob

    str = exported_scheduling_cost(
        NS, exec_NT, NB, NG, ND, NC, ND2, NH,
        units, loads, committed_winds, lines, DataCentras, config_param,
        interval_scheduling_id, su_cost, sd_cost, pgₖ, pg₀, x₀,
        seq_sr⁺, seq_sr⁻, pᵨ, pᵩ, eachslope, refcost
    )
    return str
end
