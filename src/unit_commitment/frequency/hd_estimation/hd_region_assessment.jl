"""
    hd_estimation/hd_region_assessment.jl

Inertia–Damping (H–D) Frequency Security Region (FRSR) assessment, minimum
inertia demand `H_min(D)`, minimum damping demand `D_min`, quadratic boundary
fitting (pure LinearAlgebra, no GLM dependency), and feasible region vertices.
"""

using DataFrames
using LinearAlgebra

"""
    HDFrequencyParameters

Equivalent single-area SFR parameters for H–D frequency security region assessment.
Includes an optional `area_id` field reserved for future multi-area extension.
"""
Base.@kwdef struct HDFrequencyParameters
    area_id::Int = 1
    f0_hz::Float64 = 50.0
    rocof_limit_hz_per_s::Float64 = 4.5
    nadir_limit_hz::Float64 = 0.5
    qss_limit_hz::Float64 = 0.5
    delta_p_pu::Float64 = 0.1
    droop_gain_K::Float64 = 16.0
    turbine_fraction_FH::Float64 = 0.25
    reheat_time_T::Float64 = 8.0
    H_vsm::Float64 = 0.0
    D_vsm::Float64 = 0.0
    K_conv::Float64 = 0.0
    damping_min::Float64 = 0.0
    damping_max::Float64 = 15.0
    damping_points::Int = 61
    inertia_max::Float64 = Inf
    nadir_search_grid::Int = 25
end

"""
    HDFrequencyRegionResult

Complete assessment result of the H–D Frequency Security Region (FRSR), including
explicit minimum/maximum inertia and damping bounds and feasible boundary curves.
"""
struct HDFrequencyRegionResult
    params::HDFrequencyParameters
    damping_grid::Vector{Float64}
    underdamped_lower::Vector{Float64}
    underdamped_upper::Vector{Float64}
    nadir_critical_inertia::Vector{Float64}
    required_inertia::Vector{Float64}
    rocof_min_inertia_total::Float64
    rocof_min_inertia_sync::Float64
    qss_min_damping_total::Float64
    qss_min_damping_sync::Float64
    nadir_min_damping_sync::Float64
    min_damping_demand::Float64
    max_damping_bound::Float64
    min_inertia_demand::Float64
    max_inertia_bound::Float64
    quadratic_fit_coeffs::Vector{Float64}
    feasible_indices::Vector{Int}
    vertices::Vector{Tuple{Float64, Float64}}
end

function _validate_hd_parameters(p::HDFrequencyParameters)
    p.f0_hz > 0.0 || throw(ArgumentError("f0_hz must be positive; got $(p.f0_hz)"))
    p.rocof_limit_hz_per_s > 0.0 || throw(ArgumentError("rocof_limit_hz_per_s must be positive"))
    p.nadir_limit_hz > 0.0 || throw(ArgumentError("nadir_limit_hz must be positive"))
    p.qss_limit_hz > 0.0 || throw(ArgumentError("qss_limit_hz must be positive"))
    p.delta_p_pu >= 0.0 || throw(ArgumentError("delta_p_pu must be non-negative"))
    p.droop_gain_K > 0.0 || throw(ArgumentError("droop_gain_K must be positive"))
    (0.0 <= p.turbine_fraction_FH < 1.0) || throw(ArgumentError("turbine_fraction_FH must be in [0, 1)"))
    p.reheat_time_T > 0.0 || throw(ArgumentError("reheat_time_T must be positive"))
    p.damping_min >= 0.0 || throw(ArgumentError("damping_min must be non-negative"))
    p.damping_max > p.damping_min || throw(ArgumentError("damping_max must exceed damping_min"))
    p.damping_points >= 3 || throw(ArgumentError("damping_points must be >= 3"))
    return nothing
end

function _largest_contiguous_true_run(mask::AbstractVector{Bool})
    isempty(mask) && return Int[]
    best_start = 0
    best_end = -1
    run_start = 0
    for idx in eachindex(mask)
        if mask[idx]
            run_start = run_start == 0 ? idx : run_start
            if idx == lastindex(mask) || !mask[idx + 1]
                if best_start == 0 || (idx - run_start) > (best_end - best_start)
                    best_start = run_start
                    best_end = idx
                end
                run_start = 0
            end
        else
            run_start = 0
        end
    end
    return best_start == 0 ? Int[] : collect(best_start:best_end)
end

"""
    hd_fit_quadratic_boundary(damping, inertia) -> Vector{Float64}

Pure-LinearAlgebra least-squares quadratic fit `H = c + b*D + a*D^2`, returning
`[c, b, a]`. Skips non-finite/non-positive points; returns `[NaN, NaN, NaN]`
when fewer than 3 valid points exist.
"""
function hd_fit_quadratic_boundary(damping::AbstractVector{<:Real}, inertia::AbstractVector{<:Real})
    d = Float64.(damping)
    h = Float64.(inertia)
    length(d) == length(h) || throw(DimensionMismatch("damping and inertia must have equal length"))
    keep = isfinite.(h) .& (h .> 0.0) .& isfinite.(d) .& (d .>= 0.0)
    if count(keep) < 3
        return fill(NaN, 3)
    end
    dk = d[keep]
    hk = h[keep]
    A = hcat(ones(Float64, length(dk)), dk, dk .^ 2)
    return A \ hk
end

"""
    hd_evaluate_nadir_critical_inertia(D_sync, p::HDFrequencyParameters) -> (H_crit, H_win_lo, H_win_hi)

For a given synchronous damping `D_sync`, compute the under-damped window
`[H_win_lo, H_win_hi]` on the synchronous inertia axis and find the minimum
synchronous inertia `H_crit >= 0` meeting `f0 * Δf_nadir(H_crit, D_sync) <= nadir_limit_hz`.
Returns `H_crit = Inf` if the nadir limit cannot be met at `D_sync`.
"""
function hd_evaluate_nadir_critical_inertia(D_sync::Float64, p::HDFrequencyParameters)
    D_conv = p.D_vsm + p.K_conv
    D_eff = D_sync + D_conv
    lo_eff, hi_eff = hd_sfr_underdamped_window(D_eff, p.droop_gain_K, p.reheat_time_T, p.turbine_fraction_FH)
    H_win_lo = max(0.0, lo_eff - p.H_vsm)
    H_win_hi = max(H_win_lo + 1.0e-9, hi_eff - p.H_vsm)

    threshold_pu = hd_nadir_threshold_pu(p.nadir_limit_hz; f0 = p.f0_hz)
    if p.delta_p_pu <= eps(Float64)
        return 0.0, H_win_lo, H_win_hi
    end

    # Even in the over-damped limit (H -> infinity), Δf >= ΔP / (D_eff + K).
    qss_pu = p.delta_p_pu / (D_eff + p.droop_gain_K)
    if qss_pu > threshold_pu + 1.0e-12
        return Inf, H_win_lo, H_win_hi
    end

    nadir_at(H) = hd_effective_nadir_pu(
        H,
        D_sync,
        p.droop_gain_K,
        p.reheat_time_T,
        p.turbine_fraction_FH,
        p.delta_p_pu;
        H_vsm = p.H_vsm,
        D_vsm = p.D_vsm,
        K_conv = p.K_conv,
        include_overdamped = true,
    )

    # Scan from a small positive inertia up to H_win_hi (zero-allocation lazy range)
    H_start = 1.0e-4
    grid = range(H_start, H_win_hi; length = max(25, p.nadir_search_grid))
    first_ok = nothing
    for (idx, h_val) in enumerate(grid)
        v = nadir_at(h_val)
        if isfinite(v) && v <= threshold_pu
            first_ok = idx
            break
        end
    end

    if first_ok === nothing
        v_hi = nadir_at(H_win_hi)
        return (isfinite(v_hi) && v_hi <= threshold_pu) ? H_win_hi : Inf, H_win_lo, H_win_hi
    elseif first_ok == 1
        return 0.0, H_win_lo, H_win_hi
    else
        lo, hi = grid[first_ok - 1], grid[first_ok]
        for _ in 1:60
            mid = 0.5 * (lo + hi)
            v = nadir_at(mid)
            if isfinite(v) && v <= threshold_pu
                hi = mid
            else
                lo = mid
            end
            (hi - lo) < 1.0e-6 && break
        end
        return hi, H_win_lo, H_win_hi
    end
end

"""
    assess_hd_frequency_region(p::HDFrequencyParameters) -> HDFrequencyRegionResult

Evaluate the Inertia–Damping (H–D) Frequency Security Region, computing:
1. RoCoF minimum inertia demand (`rocof_min_inertia_total`, `rocof_min_inertia_sync`);
2. QSS minimum damping demand (`qss_min_damping_total`, `qss_min_damping_sync`);
3. Nadir-critical inertia curve `H_nadir(D)` across `damping_grid` via bisection;
4. Combined required inertia envelope `H_req(D) = max(H_rocof_sync, H_nadir(D))`;
5. Global minimum damping demand `D_min` and minimum inertia demand `H_min`;
6. Pure-LinearAlgebra quadratic fit `[c, b, a]` and closed feasible region vertices.
"""
function assess_hd_frequency_region(p::HDFrequencyParameters)
    _validate_hd_parameters(p)
    damping_grid = collect(range(p.damping_min, p.damping_max; length = p.damping_points))
    n = length(damping_grid)

    underdamped_lower = Vector{Float64}(undef, n)
    underdamped_upper = Vector{Float64}(undef, n)
    nadir_critical = Vector{Float64}(undef, n)

    if Threads.nthreads() > 1 && n >= 8
        Threads.@threads :static for i in 1:n
            h_crit, h_lo, h_hi = hd_evaluate_nadir_critical_inertia(damping_grid[i], p)
            @inbounds nadir_critical[i] = h_crit
            @inbounds underdamped_lower[i] = h_lo
            @inbounds underdamped_upper[i] = h_hi
        end
    else
        for i in 1:n
            h_crit, h_lo, h_hi = hd_evaluate_nadir_critical_inertia(damping_grid[i], p)
            @inbounds nadir_critical[i] = h_crit
            @inbounds underdamped_lower[i] = h_lo
            @inbounds underdamped_upper[i] = h_hi
        end
    end

    H_rocof_total = hd_rocof_min_inertia(p.delta_p_pu, p.rocof_limit_hz_per_s; f0 = p.f0_hz)
    H_rocof_sync = hd_rocof_min_inertia_axis(p.delta_p_pu, p.rocof_limit_hz_per_s, p.H_vsm; f0 = p.f0_hz)

    D_qss_total = hd_qss_min_damping(p.delta_p_pu, p.qss_limit_hz, p.droop_gain_K; f0 = p.f0_hz)
    D_qss_sync = max(0.0, D_qss_total - (p.D_vsm + p.K_conv))

    required_inertia = max.(H_rocof_sync, nadir_critical)

    # Minimum damping where nadir is feasible
    nadir_feasible_idx = findall(isfinite, nadir_critical)
    D_nadir_min = isempty(nadir_feasible_idx) ? Inf : damping_grid[first(nadir_feasible_idx)]
    min_damping_demand = max(D_qss_sync, D_nadir_min)

    effective_upper = isfinite(p.inertia_max) ? min.(underdamped_upper, p.inertia_max) : underdamped_upper

    feasible_mask = isfinite.(required_inertia) .&
                    isfinite.(effective_upper) .&
                    (damping_grid .>= min_damping_demand - 1.0e-9) .&
                    (required_inertia .<= effective_upper .+ 1.0e-9)
    feasible_indices = _largest_contiguous_true_run(feasible_mask)

    min_inertia_demand = isempty(feasible_indices) ? Inf : minimum(required_inertia[feasible_indices])
    finite_uppers = filter(isfinite, effective_upper)
    fallback_upper = isfinite(p.inertia_max) ? p.inertia_max : (isempty(finite_uppers) ? Inf : maximum(finite_uppers))
    max_inertia_bound = isempty(feasible_indices) ? fallback_upper : maximum(effective_upper[feasible_indices])
    max_damping_bound = isempty(feasible_indices) ? p.damping_max : damping_grid[last(feasible_indices)]

    quad_coeffs = hd_fit_quadratic_boundary(damping_grid, nadir_critical)

    # Extract closed polygon vertices (D, H) using effective_upper as upper boundary
    vertices = Tuple{Float64, Float64}[]
    if !isempty(feasible_indices)
        d_sub = damping_grid[feasible_indices]
        h_bot = required_inertia[feasible_indices]
        h_top = max.(effective_upper[feasible_indices], h_bot .+ 1.0e-3)
        for i in eachindex(d_sub)
            push!(vertices, (d_sub[i], h_bot[i]))
        end
        for i in length(d_sub):-1:1
            push!(vertices, (d_sub[i], h_top[i]))
        end
    end

    return HDFrequencyRegionResult(
        p,
        damping_grid,
        underdamped_lower,
        effective_upper,
        nadir_critical,
        required_inertia,
        H_rocof_total,
        H_rocof_sync,
        D_qss_total,
        D_qss_sync,
        D_nadir_min,
        min_damping_demand,
        max_damping_bound,
        min_inertia_demand,
        max_inertia_bound,
        quad_coeffs,
        feasible_indices,
        vertices,
    )
end

"""
    hd_region_summary_dataframe(res::HDFrequencyRegionResult) -> DataFrame

Return a structured DataFrame summarizing minimum inertia demand, minimum damping
demand, converter support, and H–D security region statistics.
"""
function hd_region_summary_dataframe(res::HDFrequencyRegionResult)
    p = res.params
    return DataFrame(
        metric = [
            "Area ID",
            "Base Frequency f0 (Hz)",
            "Contingency ΔP (pu)",
            "Equivalent Droop Gain K (pu)",
            "Turbine Fraction F_H",
            "Reheat Time Constant T (s)",
            "Converter Support (H_vsm / D_vsm / K_conv)",
            "RoCoF Limit (Hz/s) -> Min Inertia Total / Sync (s)",
            "QSS Limit (Hz) -> Min Damping Total / Sync (pu)",
            "Nadir Limit (Hz) -> Nadir Min Damping (pu)",
            "Overall Min / Max Damping Bound D_min / D_max (pu)",
            "Overall Min / Max Inertia Bound H_min / H_max (s)",
            "Feasible Grid Points",
        ],
        value = [
            string(p.area_id),
            string(round(p.f0_hz; digits = 2)),
            string(round(p.delta_p_pu; digits = 4)),
            string(round(p.droop_gain_K; digits = 4)),
            string(round(p.turbine_fraction_FH; digits = 4)),
            string(round(p.reheat_time_T; digits = 4)),
            "$(round(p.H_vsm; digits = 4)) / $(round(p.D_vsm; digits = 4)) / $(round(p.K_conv; digits = 4))",
            "$(round(p.rocof_limit_hz_per_s; digits = 2)) -> $(round(res.rocof_min_inertia_total; digits = 4)) / $(round(res.rocof_min_inertia_sync; digits = 4))",
            "$(round(p.qss_limit_hz; digits = 2)) -> $(round(res.qss_min_damping_total; digits = 4)) / $(round(res.qss_min_damping_sync; digits = 4))",
            "$(round(p.nadir_limit_hz; digits = 2)) -> $(round(res.nadir_min_damping_sync; digits = 4))",
            "$(round(res.min_damping_demand; digits = 4)) / $(round(res.max_damping_bound; digits = 4))",
            "$(round(res.min_inertia_demand; digits = 4)) / $(round(res.max_inertia_bound; digits = 4))",
            "$(length(res.feasible_indices)) / $(length(res.damping_grid))",
        ],
    )
end
