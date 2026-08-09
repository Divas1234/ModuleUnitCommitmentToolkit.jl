# 机组运行特征与净负荷事件识别
# 负责机组快慢分类、边界衰减系数和爬坡事件检测。

## 
"""
	classify_generator_speed(units::unit; slow_threshold::Float64 = 4.0)

Classify generators into slow-start and fast-start units based on minimum up/down times.

# Arguments
- `units`: A struct containing unit information
- `slow_threshold`: The threshold for classifying slow-start units

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

    for i ∈ 1:NG
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

## SECTION
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
    detect_ramp_events_and_overlap(loads::load, winds::wind, start_time::Int64, exec_NT::Int64, max_lookahead::Int64, ramp_threshold_ratio::Float64 = 1.25, uncertainty_threshold_ratio::Float64 = 1.20)

Detect net-load ramping and multi-scenario uncertainty events in the lookahead horizon and calculate required adaptive ramp/uncertainty overlap window.

# Net Load Perspective (净负荷视角):

Net Load for scenario s at time t:
P_net(s, t) = sum_d P_load,d(t) - sum_w P_wind_max,w * scenarios_curve(s, t)

Both net-load ramp rate variations (|P_net(s, t+1) - P_net(s, t)|) and multi-scenario net-load volatility/uncertainty (std_s(P_net(s, t))) are evaluated to determine the lookahead overlap window (交叠窗).

# Returns

  - `is_ramp_event::Bool`: Whether a strong net-load ramp/uncertainty event is detected in the lookahead horizon
  - `T_ramp_overlap::Int64`: Required overlap window length to envelop the net-load event
"""
function detect_ramp_events_and_overlap(loads::load, winds::wind, start_time::Int64, exec_NT::Int64, max_lookahead::Int64,
        ramp_threshold_ratio::Float64 = 2.0, uncertainty_threshold_ratio::Float64 = 1.50)
    total_time_avail = size(loads.load_curve, 2)
    end_horizon = min(total_time_avail, start_time + exec_NT + max_lookahead - 1)

    if end_horizon <= start_time + exec_NT
        return false, 0
    end

    # Aggregate system load P_load(t) across all buses
    total_load = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
    horizon_len = length(total_load)

    # Multi-scenario Wind Power & Net Load Matrix: NS × horizon_len
    NS = winds.scenarios_nums
    total_wind_cap = sum(winds.p_max)

    # Calculate multi-scenario Net Load: P_net(s, t) = P_load(t) - P_wind(s, t)
    net_load_matrix = zeros(NS, horizon_len)
    for s ∈ 1:NS
        net_load_matrix[s, :] = total_load .- (total_wind_cap .* winds.scenarios_curve[s, start_time:end_horizon])
    end

    # 1. Ramping rates of Net Load calculated scenario-by-scenario
    # R(s, t) = |P_net(s, t+1) - P_net(s, t)|
    # Find the earliest ramping event in the lookahead horizon across all scenarios
    lookahead_start_idx = exec_NT
    earliest_ramp_idx = nothing
    strongest_ramp_ratio = 0.0

    for s ∈ 1:NS
        # Ramping rates for this specific scenario
        scen_ramps = [abs(net_load_matrix[s, t + 1] - net_load_matrix[s, t]) for t ∈ 1:(horizon_len - 1)]
        # Use a robust background-ramp estimate. A mean over a profile with many
        # extreme events rises with the events themselves and can suppress the
        # detector. The absolute 90% net-load floor deliberately identifies
        # extreme operational events, rather than ordinary daily load changes.
        background_ramp = median(scen_ramps)
        net_load_scale = max(mean(abs.(net_load_matrix[s, :])), eps())
        extreme_ramp_floor = parse(Float64, get(ENV, "PCM_EXTREME_RAMP_RATIO", "0.90"))
        scen_threshold = max(ramp_threshold_ratio * background_ramp, extreme_ramp_floor * net_load_scale)

        # Lookahead ramp rates for this specific scenario
        lookahead_scen_ramps = scen_ramps[lookahead_start_idx:end]

        # Find first lookahead index exceeding the scenario-specific threshold
        scen_ramp_idx = findfirst(r -> r >= scen_threshold, lookahead_scen_ramps)
        if scen_ramp_idx !== nothing
            strongest_ramp_ratio = max(strongest_ramp_ratio, maximum(lookahead_scen_ramps) / net_load_scale)
            if earliest_ramp_idx === nothing
                earliest_ramp_idx = scen_ramp_idx
            else
                earliest_ramp_idx = min(earliest_ramp_idx, scen_ramp_idx)
            end
        end
    end

    # 2. Multi-scenario Net Load Uncertainty (standard deviation across scenarios)
    net_load_std = [std(net_load_matrix[:, t]) for t ∈ 1:horizon_len]
    mean_std = mean(net_load_std)
    std_threshold = uncertainty_threshold_ratio * mean_std
    lookahead_stds = net_load_std[lookahead_start_idx:end]

    # filter the possible strong ramping or high uncertainty events in the lookahead horizon.
    high_uncertainty_idx = findfirst(s_val -> s_val >= std_threshold && std_threshold > 1e-4, lookahead_stds)

    event_indices = Int64[]
    if earliest_ramp_idx !== nothing
        push!(event_indices, earliest_ramp_idx)
    end
    if high_uncertainty_idx !== nothing
        push!(event_indices, high_uncertainty_idx)
    end

    if !isempty(event_indices)
        first_event_idx = minimum(event_indices)
        # Cover the event and reserve preparation time proportional to severity.
        # A >=40% hourly net-load swing therefore requests the full 12h window,
        # while moderate events retain a shorter event-position-based window.
        severity_window = ceil(Int, max_lookahead * clamp(strongest_ramp_ratio / 0.40, 0.0, 1.0))
        T_ramp_overlap = max(first_event_idx + 2, severity_window)
        T_ramp_overlap = min(T_ramp_overlap, max_lookahead)
        if adaptive_overlap_verbose()
            println("[AdaptiveOverlap][RampCriterion] start=$(start_time) event_indices=$(event_indices) first_event=$(first_event_idx) strongest_ratio=$(round(strongest_ramp_ratio; digits=4)) severity_window=$(severity_window) -> T_ramp=$(T_ramp_overlap)")
        end
        return true, T_ramp_overlap
    else
        adaptive_overlap_verbose() && println("[AdaptiveOverlap][RampCriterion] start=$(start_time) no ramp/uncertainty event in lookahead; T_ramp=0")
        return false, 0
    end
end
