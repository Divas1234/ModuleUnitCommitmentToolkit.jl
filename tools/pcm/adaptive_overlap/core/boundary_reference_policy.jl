# 滚动边界参考策略
# 衡量滚动边界偏差，并构造局部参考机组组合。

"""
		commitment_boundary_deviation(units::unit, x_0_curr::AbstractVector{<:Real}, x_ref_curr::Union{Nothing, AbstractVector{<:Real}} = nothing)

	Return capacity-weighted and count-based measures of how strongly the
	inherited rolling-boundary commitment differs from a local reference
	commitment. The preferred reference is the first-period commitment from a
	subproblem solved at the same start time while ignoring the prior interval's
	boundary conditions. If no reference is supplied, fall back to the original
	input boundary state.
	"""

function commitment_boundary_deviation(units::unit, x_0_curr::AbstractVector{<:Real}, x_ref_curr::Union{Nothing, AbstractVector{<:Real}} = nothing)
    NG = length(units.index)
    total_capacity = sum(units.p_max)
    if total_capacity <= 0.0
        total_capacity = 1.0
    end
    x_ref = x_ref_curr === nothing ? units.x_0 : x_ref_curr
    x_base = Float64.(x_ref[1:NG] .> 0.5)
    x_curr = Float64.(x_0_curr[1:NG] .> 0.5)
    status_delta = abs.(x_curr .- x_base)
    X_delta_norm = clamp(sum(units.p_max[1:NG] .* status_delta) / total_capacity, 0.0, 1.0)
    X_switch_ratio = clamp(sum(status_delta) / NG, 0.0, 1.0)
    return X_delta_norm, X_switch_ratio
end

function commitment_deviation_decay_overlap(
        X_delta_norm::Float64, X_switch_ratio::Float64, epsilon_state::Float64, min_overlap::Int64, max_overlap::Int64; alpha_state::Float64 = 0.25)
    A0 = clamp(max(X_delta_norm, X_switch_ratio), 0.0, 1.0)
    if A0 <= epsilon_state
        return min_overlap
    end
    # Boundary commitment deviation is treated as an initial disturbance
    # amplitude A0. Its residual influence after H overlap hours follows
    # A(H) = A0 * (1 - alpha_state)^H. Larger inherited commitment
    # deviations therefore impose a longer steady-state overlap floor.
    H_state = ceil(Int64, log(epsilon_state / A0) / log(1.0 - alpha_state))
    return clamp(max(min_overlap, H_state), min_overlap, max_overlap)
end

"""
    solve_local_reference_commitment(...)

Solve a local economic reference subproblem for the same rolling interval
while intentionally ignoring the prior interval's inherited boundary
conditions. Its first-period commitment is used as `x_ref_curr`, the local
benchmark for measuring boundary-state deviation in T_steady.
"""
function solve_local_reference_commitment(
        loads::load, winds::wind, units::unit, lines::transmissionline, DataCentras::data_centra, config_param::config,
        stroges::Any, scenarios_prob::Float64, hydros::hydro, start_time::Int64, exec_NT::Int64, max_overlap::Int64,
        NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64, interval_scheduling_id::Int64 = 1)
    total_time_avail = size(loads.load_curve, 2)
    remaining_overlap = total_time_avail - (start_time + exec_NT - 1)
    reference_overlap = max(0, min(max_overlap, remaining_overlap))
    total_NT_ref = exec_NT + reference_overlap
    ref_units, ref_loads, ref_winds = update_adaptive_boundary_conditions(1, NG, exec_NT, total_NT_ref, start_time, units, loads, winds, nothing)
    ref_results = each_period_scucmodel_modules(total_NT_ref, NB, NG, ND, NC, ND2, ref_units, ref_loads, ref_winds, lines, DataCentras,
        config_param, stroges, scenarios_prob, NL, interval_scheduling_id, hydros, NH)
    if ref_results === nothing || !haskey(ref_results, "x₀")
        return nothing
    end
    return Float64.(ref_results["x₀"][:, 1] .> 0.5)
end

function load_following_commitment(units::unit, target_capacity::Float64)
    NG = length(units.index)
    x = zeros(Float64, NG)
    order = sortperm(units.p_max; rev = true)
    online_capacity = 0.0
    for i ∈ order
        x[i] = 1.0
        online_capacity += units.p_max[i]
        if online_capacity >= target_capacity
            break
        end
    end
    return x
end
