"""
    hd_estimation/hd_linear_cuts.jl

Conservative piecewise-linear inner approximation of the H–D Frequency Security
Region (FRSR) lower and upper boundaries for pure-MILP Unit Commitment models.

- Box bounds:
    H_min_sync <= H_sync <= H_max_sync
    D_min_sync <= D_sync <= D_max_sync
- Lower H–D coupling cuts (Nadir lower envelope):
    H_sync + beta[m] * D_sync >= alpha[m],   beta[m] >= 0
- Upper H–D coupling cuts (ζ=1 / inertia-ceiling upper envelope):
    H_sync - beta_upper[m] * D_sync <= alpha_upper[m],   beta_upper[m] >= 0
"""

using DataFrames

"""
    HDLinearCutSet

Linearized H–D frequency security box bounds and coupling cuts ready for JuMP MILP embedding.
"""
struct HDLinearCutSet
    H_min_sync::Float64
    H_max_sync::Float64
    D_min_sync::Float64
    D_max_sync::Float64
    alpha::Vector{Float64}
    beta::Vector{Float64}
    alpha_upper::Vector{Float64}
    beta_upper::Vector{Float64}
    support_damping::Vector{Float64}
    support_inertia::Vector{Float64}
    max_conservatism_s::Float64
    max_violation_s::Float64
end

"""
    build_hd_linear_cuts(res::HDFrequencyRegionResult; max_cuts = 6, safety_margin = 1e-6) -> HDLinearCutSet

Construct conservative piecewise-linear lower and upper boundary cut sets from
`res::HDFrequencyRegionResult`:
- Lower envelope: `H_sync + beta[m] * D_sync >= alpha[m]` (never undercuts `H_req(D)`).
- Upper envelope: `H_sync - beta_upper[m] * D_sync <= alpha_upper[m]` (tracks the
  concave upper inertia boundary `H_upper(D)` without exceeding it).
"""
function build_hd_linear_cuts(
    res::HDFrequencyRegionResult;
    max_cuts::Int = 6,
    safety_margin::Float64 = 1.0e-6,
)
    max_cuts >= 1 || throw(ArgumentError("max_cuts must be >= 1; got $(max_cuts)"))

    H_floor = res.rocof_min_inertia_sync
    H_ceil = res.max_inertia_bound
    D_floor = isfinite(res.min_damping_demand) ? res.min_damping_demand : res.qss_min_damping_sync
    D_ceil = res.max_damping_bound

    if isempty(res.feasible_indices)
        @warn "H-D frequency security region has no feasible (H, D) points; nadir linear cuts cannot be generated."
        return HDLinearCutSet(H_floor, H_ceil, res.min_damping_demand, D_ceil, Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], 0.0, Inf)
    end

    d_pts = res.damping_grid[res.feasible_indices]
    h_pts = res.required_inertia[res.feasible_indices]
    h_up_pts = res.underdamped_upper[res.feasible_indices]

    # --- 1. Lower H-D coupling cuts (Nadir-dominated region) ---
    alpha = Float64[]
    beta = Float64[]
    sup_d = Float64[]
    sup_h = Float64[]

    active_idx = findall(h -> h > H_floor + 1.0e-7, h_pts)
    if !isempty(active_idx)
        last_active = min(length(d_pts), last(active_idx) + 1)
        d_act = d_pts[first(active_idx):last_active]
        h_act = h_pts[first(active_idx):last_active]

        if length(d_act) == 1
            push!(alpha, h_act[1] + safety_margin)
            push!(beta, 0.0)
            push!(sup_d, d_act[1])
            push!(sup_h, h_act[1])
        else
            n_seg = min(max_cuts, length(d_act) - 1)
            knot_indices = unique(round.(Int, range(1, length(d_act); length = n_seg + 1)))
            for k in 1:(length(knot_indices) - 1)
                i1 = knot_indices[k]
                i2 = knot_indices[k + 1]
                d1, h1 = d_act[i1], h_act[i1]
                d2, h2 = d_act[i2], h_act[i2]
                denom = max(d2 - d1, eps(Float64))
                b_k = max(0.0, -(h2 - h1) / denom)
                a_k = max(h1 + b_k * d1, h2 + b_k * d2)
                max_interior_lift = maximum(h_act[j] - (a_k - b_k * d_act[j]) for j in i1:i2)
                a_k += max(0.0, max_interior_lift) + safety_margin
                push!(alpha, a_k)
                push!(beta, b_k)
                push!(sup_d, 0.5 * (d1 + d2))
                push!(sup_h, 0.5 * (h1 + h2))
            end
        end
    end

    # Verify global lower envelope across all feasible points
    max_viol = 0.0
    max_cons = 0.0
    for j in eachindex(d_pts)
        env_val = H_floor
        for m in eachindex(alpha)
            env_val = max(env_val, alpha[m] - beta[m] * d_pts[j])
        end
        diff = env_val - h_pts[j]
        if diff < 0.0
            max_viol = max(max_viol, -diff)
        else
            max_cons = max(max_cons, diff)
        end
    end
    if max_viol > 1.0e-9 && !isempty(alpha)
        alpha .+= (max_viol + safety_margin)
        max_cons += (max_viol + safety_margin)
        max_viol = 0.0
    end

    # --- 2. Upper H-D coupling cuts (non-flat portion of concave upper boundary) ---
    alpha_upper = Float64[]
    beta_upper = Float64[]
    if length(d_pts) >= 2 && all(isfinite, h_up_pts) && (maximum(h_up_pts) - minimum(h_up_pts)) > 1.0e-4
        n_seg_u = min(max_cuts, length(d_pts) - 1)
        knot_u = unique(round.(Int, range(1, length(d_pts); length = n_seg_u + 1)))
        for k in 1:(length(knot_u) - 1)
            i1 = knot_u[k]
            i2 = knot_u[k + 1]
            d1, h1 = d_pts[i1], h_up_pts[i1]
            d2, h2 = d_pts[i2], h_up_pts[i2]
            denom = max(d2 - d1, eps(Float64))
            b_u = max(0.0, (h2 - h1) / denom)
            # Secant through endpoints; for concave H_upper(D) this forms a valid inner upper bound
            a_u = min(h1 - b_u * d1, h2 - b_u * d2)
            # Ensure the upper cut never drops below the required lower curve anywhere
            min_clearance = minimum((a_u + b_u * d_pts[j]) - h_pts[j] for j in eachindex(d_pts))
            if min_clearance >= 0.0
                push!(alpha_upper, a_u)
                push!(beta_upper, b_u)
            end
        end
    end

    return HDLinearCutSet(H_floor, H_ceil, D_floor, D_ceil, alpha, beta, alpha_upper, beta_upper, sup_d, sup_h, max_cons, max_viol)
end

"""
    hd_cuts_dataframe(cuts::HDLinearCutSet) -> DataFrame

Return a DataFrame listing all generated lower (`H + beta * D >= alpha`) and
upper (`H - beta * D <= alpha`) H–D linear cuts.
"""
function hd_cuts_dataframe(cuts::HDLinearCutSet)
    bounds = vcat(fill("lower (>=)", length(cuts.alpha)), fill("upper (<=)", length(cuts.alpha_upper)))
    ids = vcat(collect(1:length(cuts.alpha)), collect(1:length(cuts.alpha_upper)))
    alphas = vcat(cuts.alpha, cuts.alpha_upper)
    betas = vcat(cuts.beta, cuts.beta_upper)
    return DataFrame(
        bound = bounds,
        cut_id = ids,
        alpha = round.(alphas; digits = 5),
        beta = round.(betas; digits = 5),
    )
end
