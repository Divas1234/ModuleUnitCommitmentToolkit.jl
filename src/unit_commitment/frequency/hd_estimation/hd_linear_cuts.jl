"""
    hd_estimation/hd_linear_cuts.jl

Conservative piecewise-linear inner approximation of the H–D Frequency Security
Region lower boundary `H >= H_req(D)` for pure-MILP Unit Commitment models.

Each linear cut takes the form:
    H_sync + beta_m * D_sync >= alpha_m
with `beta_m >= 0`, guaranteeing zero extra binary variables and strict
conservative security (`max_m (alpha_m - beta_m * D_j) >= H_req(D_j)` across all
feasible damping grid points).
"""

using DataFrames

"""
    HDLinearCutSet

Linearized H–D frequency security constraints ready for JuMP MILP embedding.
- `H_min_sync`: RoCoF minimum synchronous inertia floor (s).
- `D_min_sync`: Minimum synchronous damping floor (pu) from QSS and Nadir feasibility.
- `alpha`, `beta`: Vectors of length `M` defining `H_sync + beta[m] * D_sync >= alpha[m]`.
- `max_conservatism_s`: Maximum upward gap `max_j (max_m(alpha_m - beta_m D_j) - H_req(D_j))`.
- `max_violation_s`: Maximum under-estimation error (guaranteed <= 1e-9).
"""
struct HDLinearCutSet
    H_min_sync::Float64
    D_min_sync::Float64
    alpha::Vector{Float64}
    beta::Vector{Float64}
    support_damping::Vector{Float64}
    support_inertia::Vector{Float64}
    max_conservatism_s::Float64
    max_violation_s::Float64
end

"""
    build_hd_linear_cuts(res::HDFrequencyRegionResult; max_cuts = 6, safety_margin = 1e-6) -> HDLinearCutSet

Construct a conservative piecewise-linear lower-envelope cut set
`H_sync + beta_m * D_sync >= alpha_m` from `res::HDFrequencyRegionResult`.

Algorithm:
1. Extract the feasible points `(D_j, H_j)` on `res.feasible_indices`.
2. Build secant segments over `M = min(max_cuts, n_pts - 1)` evenly-spaced knots
   on the active nadir-dominated portion of the curve (where `H_req(D) > H_rocof_sync`).
3. For each segment `(D_a, H_a) -> (D_b, H_b)`, compute slope `beta = max(0, -(H_b - H_a)/(D_b - D_a))`
   and intercept `alpha = H_a + beta * D_a`.
4. Shift each cut upward if needed so the piecewise-linear envelope
   `H_env(D) = max(H_min_sync, max_m(alpha_m - beta_m * D))` never undercuts
   any sampled point `H_req(D_j)` by more than numerical tolerance (`safety_margin`).
"""
function build_hd_linear_cuts(
    res::HDFrequencyRegionResult;
    max_cuts::Int = 6,
    safety_margin::Float64 = 1.0e-6,
)
    max_cuts >= 1 || throw(ArgumentError("max_cuts must be >= 1; got $(max_cuts)"))

    H_floor = res.rocof_min_inertia_sync
    D_floor = isfinite(res.min_damping_demand) ? res.min_damping_demand : res.qss_min_damping_sync

    if isempty(res.feasible_indices)
        return HDLinearCutSet(H_floor, D_floor, Float64[], Float64[], Float64[], Float64[], 0.0, 0.0)
    end

    d_pts = res.damping_grid[res.feasible_indices]
    h_pts = res.required_inertia[res.feasible_indices]

    # Identify points where the nadir curve strictly dominates the flat RoCoF floor
    active_idx = findall(h -> h > H_floor + 1.0e-7, h_pts)
    if isempty(active_idx)
        # RoCoF floor dominates everywhere -> no extra H-D coupling cuts needed
        return HDLinearCutSet(H_floor, D_floor, Float64[], Float64[], Float64[], Float64[], 0.0, 0.0)
    end

    # Include one transition anchor immediately after the last active point if available
    last_active = min(length(d_pts), last(active_idx) + 1)
    d_act = d_pts[first(active_idx):last_active]
    h_act = h_pts[first(active_idx):last_active]

    alpha = Float64[]
    beta = Float64[]
    sup_d = Float64[]
    sup_h = Float64[]

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
            # Enforce non-negative slope (higher damping cannot require more inertia)
            b_k = max(0.0, -(h2 - h1) / denom)
            a_k = max(h1 + b_k * d1, h2 + b_k * d2)
            # Lift cut strictly above all interior sample points in [i1, i2] for conservative inner approximation
            max_interior_lift = maximum(h_act[j] - (a_k - b_k * d_act[j]) for j in i1:i2)
            a_k += max(0.0, max_interior_lift) + safety_margin
            push!(alpha, a_k)
            push!(beta, b_k)
            push!(sup_d, 0.5 * (d1 + d2))
            push!(sup_h, 0.5 * (h1 + h2))
        end
    end

    # Global envelope verification across all feasible points
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

    # If any residual violation exists (e.g. non-convex numerical wiggle), lift all cuts by max_viol
    if max_viol > 1.0e-9 && !isempty(alpha)
        alpha .+= (max_viol + safety_margin)
        max_cons += (max_viol + safety_margin)
        max_viol = 0.0
    end

    return HDLinearCutSet(H_floor, D_floor, alpha, beta, sup_d, sup_h, max_cons, max_viol)
end

"""
    hd_cuts_dataframe(cuts::HDLinearCutSet) -> DataFrame

Return a DataFrame listing all generated H–D linear cuts `H + beta * D >= alpha`.
"""
function hd_cuts_dataframe(cuts::HDLinearCutSet)
    n = length(cuts.alpha)
    return DataFrame(
        cut_id = collect(1:n),
        alpha = round.(cuts.alpha; digits = 5),
        beta = round.(cuts.beta; digits = 5),
        ref_D = round.(cuts.support_damping; digits = 4),
        ref_H = round.(cuts.support_inertia; digits = 4),
    )
end
