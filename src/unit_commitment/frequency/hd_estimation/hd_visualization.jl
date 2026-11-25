"""
    hd_estimation/hd_visualization.jl

Post-solve time-varying Inertia–Damping (H–D) binding curve evaluation, CSV
export, and publication-quality 2x2 diagnostic plotting for UC runs using the
H–D Frequency Security Region (`FREQUENCY_MODEL_MODE = "hd_region"` or `"hybrid"`).
"""

using CSV
using DataFrames
using Plots
using Printf
using Statistics

function _eval_lower_cut_envelope(cuts::HDLinearCutSet, d::Float64)
    val = cuts.H_min_sync
    for m in eachindex(cuts.alpha)
        val = max(val, cuts.alpha[m] - cuts.beta[m] * d)
    end
    return val
end

function _eval_upper_cut_envelope(cuts::HDLinearCutSet, d::Float64)
    val = cuts.H_max_sync
    for m in eachindex(cuts.alpha_upper)
        val = min(val, cuts.alpha_upper[m] + cuts.beta_upper[m] * d)
    end
    return val
end

function _extract_hourly_hd_params(units, winds, x_col::AbstractVector, base_params::HDFrequencyParameters)
    NG = length(units.index)
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    on_mask = [Float64(x_col[i]) >= 0.5 ? 1.0 : 0.0 for i in 1:NG]
    K_num = sum(unit_primary_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) * on_mask[i] for i in 1:NG)
    KF_num = sum(unit_turbine_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) * on_mask[i] for i in 1:NG)
    K_t = K_num > eps(Float64) ? max(K_num / sum_apparent_power, 1.0e-3) : base_params.droop_gain_K
    FH_t = K_num > eps(Float64) ? clamp(KF_num / K_num, 0.0, 0.99) : base_params.turbine_fraction_FH
    T_weights = [max(safe_frequency_coeff(units.p_max, i), 0.0) * on_mask[i] for i in 1:NG]
    T_vals = [safe_frequency_coeff(units.Tg, i; default = base_params.reheat_time_T) for i in 1:NG]
    T_t = sum(T_weights) > eps(Float64) ? max(sum(T_vals .* T_weights) / sum(T_weights), 0.1) : base_params.reheat_time_T
    return HDFrequencyParameters(
        area_id = base_params.area_id,
        f0_hz = base_params.f0_hz,
        rocof_limit_hz_per_s = base_params.rocof_limit_hz_per_s,
        nadir_limit_hz = base_params.nadir_limit_hz,
        qss_limit_hz = base_params.qss_limit_hz,
        delta_p_pu = base_params.delta_p_pu,
        droop_gain_K = K_t,
        turbine_fraction_FH = FH_t,
        reheat_time_T = T_t,
        H_vsm = base_params.H_vsm,
        D_vsm = base_params.D_vsm,
        K_conv = base_params.K_conv,
        damping_min = base_params.damping_min,
        damping_max = base_params.damping_max,
        damping_points = base_params.damping_points,
        inertia_max = base_params.inertia_max,
        nadir_search_grid = base_params.nadir_search_grid,
    )
end

"""
    evaluate_uc_hd_trajectory(units, winds, x_commitment; Δp_contingency = nothing)

Evaluate the time-varying H–D operating point `(D_sync[t], H_sync[t])`, dynamic
binding curves per operating mode, and exact post-dispatch frequency metrics
(`nadir_hz`, `rocof_hz_per_s`, `qss_hz`) across all hours `t = 1:NT`.

Returns a NamedTuple `(base_region, base_cuts, trajectory_df, binding_curves_df, mode_regions)`.
"""
function evaluate_uc_hd_trajectory(
    units,
    winds,
    x_commitment::AbstractMatrix;
    Δp_contingency::Union{Nothing, Real} = nothing,
)
    NG, NT = size(x_commitment)
    contingency_in = Δp_contingency === nothing ? define_contingency_size(units, NG) : Float64(Δp_contingency)
    base_params = extract_uc_hd_parameters(units, winds, contingency_in)
    base_region = assess_hd_frequency_region(base_params)
    max_cuts = max(1, floor(Int, frequency_env_float("FREQUENCY_HD_MAX_CUTS", 6.0)))
    base_cuts = build_hd_linear_cuts(base_region; max_cuts = max_cuts)

    sum_apparent_power = frequency_sum_apparent_power(units, winds)

    # Group distinct commitment operating modes to avoid redundant region sweeps
    mode_cache = Dict{Vector{Int}, NamedTuple}()
    mode_regions = NamedTuple[]

    hours = collect(1:NT)
    online_units = zeros(Int, NT)
    mode_ids = zeros(Int, NT)
    H_sync = zeros(Float64, NT)
    D_sync = zeros(Float64, NT)
    H_eff = zeros(Float64, NT)
    D_eff = zeros(Float64, NT)
    K_eff = zeros(Float64, NT)
    H_req_at_D = zeros(Float64, NT)
    H_upper_at_D = zeros(Float64, NT)
    H_cut_lower_at_D = zeros(Float64, NT)
    H_cut_upper_at_D = zeros(Float64, NT)
    inertia_margin_s = zeros(Float64, NT)
    rocof_hz_s = zeros(Float64, NT)
    nadir_hz = zeros(Float64, NT)
    qss_hz = zeros(Float64, NT)
    is_secure = falses(NT)

    for t in 1:NT
        x_col = [Float64(x_commitment[i, t]) >= 0.5 ? 1.0 : 0.0 for i in 1:NG]
        key = Int.(x_col)
        online_units[t] = sum(key)

        H_sync[t] = sum(safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) * x_col[i] for i in 1:NG) / sum_apparent_power
        D_sync[t] = sum(safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * x_col[i] for i in 1:NG) / sum_apparent_power
        H_eff[t] = H_sync[t] + base_params.H_vsm
        D_eff[t] = D_sync[t] + base_params.D_vsm + base_params.K_conv

        if !haskey(mode_cache, key)
            p_t = _extract_hourly_hd_params(units, winds, x_col, base_params)
            r_t = assess_hd_frequency_region(p_t)
            c_t = build_hd_linear_cuts(r_t; max_cuts = max_cuts)
            mid = length(mode_regions) + 1
            entry = (mode_id = mid, commitment = key, hours = Int[], params = p_t, region = r_t, cuts = c_t)
            mode_cache[key] = entry
            push!(mode_regions, entry)
        end
        entry = mode_cache[key]
        push!(entry.hours, t)
        mode_ids[t] = entry.mode_id

        p_t = entry.params
        K_eff[t] = p_t.droop_gain_K

        h_crit_t, _, h_hi_t = hd_evaluate_nadir_critical_inertia(D_sync[t], p_t)
        H_req_at_D[t] = max(entry.region.rocof_min_inertia_sync, h_crit_t)
        H_upper_at_D[t] = isfinite(p_t.inertia_max) ? min(h_hi_t, p_t.inertia_max) : h_hi_t
        H_cut_lower_at_D[t] = _eval_lower_cut_envelope(base_cuts, D_sync[t])
        H_cut_upper_at_D[t] = _eval_upper_cut_envelope(base_cuts, D_sync[t])
        inertia_margin_s[t] = H_sync[t] - H_req_at_D[t]

        rocof_hz_s[t] = H_eff[t] > eps(Float64) ? (p_t.f0_hz * p_t.delta_p_pu / (2.0 * H_eff[t])) : Inf
        nadir_pu = hd_effective_nadir_pu(
            H_sync[t],
            D_sync[t],
            p_t.droop_gain_K,
            p_t.reheat_time_T,
            p_t.turbine_fraction_FH,
            p_t.delta_p_pu;
            H_vsm = p_t.H_vsm,
            D_vsm = p_t.D_vsm,
            K_conv = p_t.K_conv,
            include_overdamped = true,
        )
        nadir_hz[t] = p_t.f0_hz * nadir_pu
        qss_hz[t] = p_t.f0_hz * p_t.delta_p_pu / max(D_eff[t] + p_t.droop_gain_K, eps(Float64))
        is_secure[t] = (rocof_hz_s[t] <= p_t.rocof_limit_hz_per_s + 1.0e-4) &&
                       (nadir_hz[t] <= p_t.nadir_limit_hz + 1.0e-4) &&
                       (qss_hz[t] <= p_t.qss_limit_hz + 1.0e-4)
    end

    trajectory_df = DataFrame(
        hour = hours,
        operating_mode = mode_ids,
        online_units = online_units,
        H_sync = round.(H_sync; digits = 5),
        D_sync = round.(D_sync; digits = 5),
        H_eff = round.(H_eff; digits = 5),
        D_eff = round.(D_eff; digits = 5),
        K_eff = round.(K_eff; digits = 4),
        H_min_sync = fill(round(base_cuts.H_min_sync; digits = 5), NT),
        H_max_sync = fill(round(base_cuts.H_max_sync; digits = 5), NT),
        D_min_sync = fill(round(base_cuts.D_min_sync; digits = 5), NT),
        D_max_sync = fill(round(base_cuts.D_max_sync; digits = 5), NT),
        H_req_at_D = round.(H_req_at_D; digits = 5),
        H_upper_at_D = round.(H_upper_at_D; digits = 5),
        H_cut_lower_at_D = round.(H_cut_lower_at_D; digits = 5),
        H_cut_upper_at_D = round.(H_cut_upper_at_D; digits = 5),
        inertia_margin_s = round.(inertia_margin_s; digits = 5),
        rocof_hz_per_s = round.(rocof_hz_s; digits = 4),
        nadir_hz = round.(nadir_hz; digits = 4),
        qss_hz = round.(qss_hz; digits = 4),
        is_secure = collect(is_secure),
    )

    # Binding curves table across damping grid (fleet base + each distinct operating mode)
    d_grid = base_region.damping_grid
    binding_curves_df = DataFrame(
        damping_D = round.(d_grid; digits = 5),
        H_rocof_floor = fill(round(base_region.rocof_min_inertia_sync; digits = 5), length(d_grid)),
        H_nadir_lower = round.(base_region.nadir_critical_inertia; digits = 5),
        H_req_lower = round.(base_region.required_inertia; digits = 5),
        H_upper_bound = round.(base_region.underdamped_upper; digits = 5),
        H_cut_lower_env = [round(_eval_lower_cut_envelope(base_cuts, d); digits = 5) for d in d_grid],
        H_cut_upper_env = [round(_eval_upper_cut_envelope(base_cuts, d); digits = 5) for d in d_grid],
    )
    for entry in mode_regions
        col_req = Symbol("mode_$(entry.mode_id)_H_req")
        col_up = Symbol("mode_$(entry.mode_id)_H_upper")
        binding_curves_df[!, col_req] = round.(entry.region.required_inertia; digits = 5)
        binding_curves_df[!, col_up] = round.(entry.region.underdamped_upper; digits = 5)
    end

    return (
        base_region = base_region,
        base_cuts = base_cuts,
        trajectory_df = trajectory_df,
        binding_curves_df = binding_curves_df,
        mode_regions = mode_regions,
    )
end

"""
    plot_hd_time_varying_region(analysis, save_path; title_suffix = "")

Render a clear 2x2 publication-style figure showing:
- (a) H–D Frequency Security Region (lower/upper binding curves, linear cuts,
      per-mode binding curves, and 24-hour operating trajectory);
- (b) Time-varying synchronous inertia `H_sync(t)` vs dynamic lower binding curve
      `H_req(t)` and RoCoF floor;
- (c) Time-varying synchronous damping `D_sync(t)` vs `[D_min, D_max]` bounds;
- (d) Post-dispatch physical frequency metrics (`Δf_nadir(t)`, `Δf_qss(t)`, `RoCoF(t)`).
"""
const _HD_PLOT_ENV_LOCK = ReentrantLock()

function plot_hd_time_varying_region(analysis, save_path::AbstractString; title_suffix::AbstractString = "")
    return lock(_HD_PLOT_ENV_LOCK) do
    prev_gks = get(ENV, "GKSwstype", nothing)
    ENV["GKSwstype"] = "100"
    try
        Plots.gr()
        traj = analysis.trajectory_df
        reg = analysis.base_region
        cuts = analysis.base_cuts
        p_cfg = reg.params

        hours = traj.hour
        D_traj = traj.D_sync
        H_traj = traj.H_sync

        # --- Panel (a): H-D Security Region & Time-Varying Operating Trajectory ---
        d_grid = reg.damping_grid
        feas = reg.feasible_indices
        # Zoom X-axis around the active operating range + mode nadir curves so trajectory is crisp
        max_d_traj = max(maximum(D_traj), 1.0e-3)
        d_hi_view = if max_d_traj < 0.25
            min(cuts.D_max_sync, max(max_d_traj * 4.0, 0.35))
        else
            min(cuts.D_max_sync, max(max_d_traj * 2.2 + 0.2, 1.0))
        end
        d_view_dense = collect(range(max(0.0, minimum(d_grid)), d_hi_view; length = 60))
        h_req_view = [max(reg.rocof_min_inertia_sync, hd_evaluate_nadir_critical_inertia(d, p_cfg)[1]) for d in d_view_dense]
        h_up_view = [begin
            _, _, h_hi = hd_evaluate_nadir_critical_inertia(d, p_cfg)
            isfinite(p_cfg.inertia_max) ? min(h_hi, p_cfg.inertia_max) : h_hi
        end for d in d_view_dense]
        h_cut_lo = [_eval_lower_cut_envelope(cuts, d) for d in d_view_dense]

        finite_req = filter(isfinite, h_req_view)
        y_top_a = max(maximum(H_traj) * 1.35, isempty(finite_req) ? 3.5 : maximum(finite_req) * 1.25, cuts.H_min_sync * 1.5, 1.0)
        h_up_clipped = min.(h_up_view, y_top_a)

        p1 = Plots.plot(
            xlabel = "Synchronous Damping D_sync (p.u.)",
            ylabel = "Synchronous Inertia H_sync (s)",
            title = "(a) H-D Security Region & 24h Trajectory" * (isempty(title_suffix) ? "" : " ($title_suffix)"),
            framestyle = :box,
            grid = true,
            gridalpha = 0.2,
            legend = :topright,
            legendfontsize = 7,
            titlefontsize = 10,
            guidefontsize = 9,
            ylims = (0.0, y_top_a),
            xlims = (0.0, d_hi_view),
        )

        # Shade feasible region inside zoomed view
        feas_dense = findall(i -> isfinite(h_req_view[i]) && h_req_view[i] <= h_up_clipped[i], eachindex(d_view_dense))
        if !isempty(feas_dense)
            Plots.plot!(
                p1,
                d_view_dense[feas_dense],
                h_up_clipped[feas_dense];
                fillrange = h_req_view[feas_dense],
                fillalpha = 0.14,
                fillcolor = :teal,
                lw = 0,
                label = "Feasible H-D Region",
            )
        end

        # Base lower & upper binding curves + linear cuts
        if any(isfinite, h_req_view)
            Plots.plot!(p1, d_view_dense, h_req_view; lw = 2.0, color = :crimson, label = "Fleet Lower Binding H_req(D)")
        end
        Plots.plot!(p1, d_view_dense, h_cut_lo; lw = 1.4, ls = :dashdot, color = :darkorange, label = "Linear Cut Envelope")
        Plots.hline!(p1, [cuts.H_min_sync]; lw = 1.2, ls = :dot, color = :firebrick, label = "RoCoF Floor H_min")
        if minimum(h_up_view) <= y_top_a
            Plots.plot!(p1, d_view_dense, h_up_clipped; lw = 1.6, ls = :dash, color = :steelblue, label = "Upper Binding H_upper(D)")
        end

        # Overlay distinct operating-mode lower binding curves (evaluated on dense zoomed damping grid)
        mode_colors = [:purple, :dodgerblue, :olive, :magenta]
        for (idx, entry) in enumerate(first(analysis.mode_regions, min(4, length(analysis.mode_regions))))
            h_mode = [max(entry.region.rocof_min_inertia_sync, hd_evaluate_nadir_critical_inertia(d, entry.params)[1]) for d in d_view_dense]
            any(isfinite, h_mode) || continue
            hrs_lbl = length(entry.hours) <= 3 ? join(entry.hours, ",") : "$(first(entry.hours))..$(last(entry.hours)) ($(length(entry.hours))h)"
            Plots.plot!(
                p1,
                d_view_dense,
                min.(h_mode, y_top_a);
                lw = 1.6,
                ls = :dash,
                color = mode_colors[idx],
                alpha = 0.9,
                label = "Mode $(entry.mode_id) [h:$(hrs_lbl)]",
            )
        end

        # Time-varying trajectory (D_sync[t], H_sync[t])
        Plots.plot!(p1, D_traj, H_traj; lw = 1.6, color = :gray35, alpha = 0.75, label = "")
        Plots.scatter!(
            p1,
            D_traj,
            H_traj;
            zcolor = Float64.(hours),
            c = :viridis,
            ms = 5.5,
            msw = 0.7,
            colorbar_title = "Hour",
            label = "Dispatched (D_t, H_t)",
        )
        # Annotate each distinct operating mode once with clean horizontal offset (zero overlap)
        for entry in first(analysis.mode_regions, min(6, length(analysis.mode_regions)))
            t_rep = first(entry.hours)
            lbl = "M$(entry.mode_id) ($(length(entry.hours))h)"
            Plots.annotate!(p1, D_traj[t_rep] + 0.025 * d_hi_view, H_traj[t_rep], Plots.text(lbl, 7.5, :black, :left))
        end

        # --- Panel (b): Time-Varying Inertia H_sync(t) vs Dynamic Binding Curves ---
        h_req_t = [isfinite(v) ? v : cuts.H_min_sync for v in traj.H_req_at_D]
        h_cut_t = traj.H_cut_lower_at_D
        y_top_b = max(maximum(H_traj), maximum(h_req_t), cuts.H_min_sync) * 1.25 + 0.1
        p2 = Plots.plot(
            xlabel = "Time Period t (h)",
            ylabel = "Synchronous Inertia H_sync (s)",
            title = "(b) Time-Varying Inertia vs Dynamic Lower Binding",
            framestyle = :box,
            grid = true,
            gridalpha = 0.2,
            legend = :topright,
            legendfontsize = 7,
            titlefontsize = 10,
            guidefontsize = 9,
            ylims = (0.0, y_top_b),
            xlims = (1, maximum(hours)),
        )
        Plots.plot!(p2, hours, H_traj; fillrange = h_req_t, fillalpha = 0.16, fillcolor = :dodgerblue, lw = 0, label = "Inertia Security Margin")
        Plots.plot!(p2, hours, H_traj; lw = 2.2, marker = :circle, ms = 3.5, color = :navy, label = "Dispatched H_sync(t)")
        Plots.plot!(p2, hours, h_req_t; lw = 2.0, color = :crimson, label = "Mode Binding H_req(t)")
        Plots.plot!(p2, hours, h_cut_t; lw = 1.4, ls = :dashdot, color = :darkorange, label = "Linear Cut Bound(t)")
        Plots.hline!(p2, [cuts.H_min_sync]; lw = 1.3, ls = :dash, color = :firebrick, label = @sprintf("RoCoF Floor (%.3f s)", cuts.H_min_sync))

        # --- Panel (c): Time-Varying Damping D_sync(t) & Online Units ---
        d_top_c = max(maximum(D_traj) * 1.45, cuts.D_min_sync * 1.5, 0.05)
        p3 = Plots.plot(
            xlabel = "Time Period t (h)",
            ylabel = "Synchronous Damping D_sync (p.u.)",
            title = "(c) Time-Varying Damping & Commitment Modes",
            framestyle = :box,
            grid = true,
            gridalpha = 0.2,
            legend = :topright,
            legendfontsize = 7,
            titlefontsize = 10,
            guidefontsize = 9,
            ylims = (0.0, d_top_c),
            xlims = (1, maximum(hours)),
        )
        Plots.plot!(p3, hours, D_traj; lw = 2.2, marker = :diamond, ms = 3.5, color = :seagreen, label = "Dispatched D_sync(t)")
        if cuts.D_min_sync > 0.0
            Plots.hline!(p3, [cuts.D_min_sync]; lw = 1.4, ls = :dash, color = :crimson, label = @sprintf("D_min (%.3f pu)", cuts.D_min_sync))
        end
        if isfinite(cuts.D_max_sync) && cuts.D_max_sync <= d_top_c * 1.2
            Plots.hline!(p3, [cuts.D_max_sync]; lw = 1.4, ls = :dot, color = :steelblue, label = @sprintf("D_max (%.3f pu)", cuts.D_max_sync))
        end
        # Mark operating-mode transitions
        for t in 2:length(hours)
            if traj.operating_mode[t] != traj.operating_mode[t - 1]
                Plots.vline!(p3, [t - 0.5]; lw = 0.9, ls = :dot, color = :gray55, alpha = 0.7, label = "")
            end
        end

        # --- Panel (d): Post-Dispatch Physical Frequency Metrics ---
        nadir_t = [isfinite(v) ? v : NaN for v in traj.nadir_hz]
        qss_t = [isfinite(v) ? v : NaN for v in traj.qss_hz]
        rocof_ratio = [isfinite(v) ? (v / p_cfg.rocof_limit_hz_per_s) * p_cfg.nadir_limit_hz : NaN for v in traj.rocof_hz_per_s]
        y_top_d = max(
            p_cfg.nadir_limit_hz * 1.25,
            maximum(filter(isfinite, nadir_t); init = 0.1) * 1.15,
            maximum(filter(isfinite, rocof_ratio); init = 0.1) * 1.15,
        )
        p4 = Plots.plot(
            xlabel = "Time Period t (h)",
            ylabel = "Frequency Deviation (Hz)",
            title = "(d) Post-Dispatch Frequency Security Verification",
            framestyle = :box,
            grid = true,
            gridalpha = 0.2,
            legend = :topright,
            legendfontsize = 7,
            titlefontsize = 10,
            guidefontsize = 9,
            ylims = (0.0, y_top_d),
            xlims = (1, maximum(hours)),
        )
        Plots.plot!(p4, hours, nadir_t; lw = 2.2, marker = :circle, ms = 3.2, color = :crimson, label = "Δf_nadir(t) [Hz]")
        Plots.plot!(p4, hours, qss_t; lw = 1.8, marker = :square, ms = 3.0, color = :steelblue, label = "Δf_qss(t) [Hz]")
        Plots.plot!(p4, hours, rocof_ratio; lw = 1.6, ls = :dashdot, color = :darkorange, label = "RoCoF(t) scaled to limit")
        Plots.hline!(p4, [p_cfg.nadir_limit_hz]; lw = 1.5, ls = :dash, color = :red, label = @sprintf("Nadir / QSS Limit (%.2f Hz)", p_cfg.nadir_limit_hz))

        fig = Plots.plot(p1, p2, p3, p4; layout = (2, 2), size = (1400, 920), dpi = 180, margin = 6Plots.mm)
        mkpath(dirname(save_path))
        Plots.savefig(fig, save_path)
        return save_path
    finally
        if prev_gks === nothing
            delete!(ENV, "GKSwstype")
        else
            ENV["GKSwstype"] = prev_gks
        end
    end
    end
end

"""
    export_hd_frequency_analysis(units, winds, x_commitment; Δp_contingency = nothing, output_dir, file_prefix = "", plot_enabled = true)

Evaluate time-varying H–D binding curves and operating trajectory after a UC solve,
save CSV tables (`hd_trajectory_by_hour.csv`, `hd_binding_curves.csv`), and render
the 2x2 diagnostic figure (`hd_time_varying_security_region.png`).
"""
function export_hd_frequency_analysis(
    units,
    winds,
    x_commitment::AbstractMatrix;
    Δp_contingency::Union{Nothing, Real} = nothing,
    output_dir::AbstractString,
    file_prefix::AbstractString = "",
    plot_enabled::Bool = frequency_env_bool("FREQUENCY_HD_PLOT_ENABLED", true),
)
    mkpath(output_dir)
    analysis = evaluate_uc_hd_trajectory(units, winds, x_commitment; Δp_contingency = Δp_contingency)

    traj_csv = joinpath(output_dir, file_prefix * "hd_trajectory_by_hour.csv")
    curves_csv = joinpath(output_dir, file_prefix * "hd_binding_curves.csv")
    CSV.write(traj_csv, analysis.trajectory_df)
    CSV.write(curves_csv, analysis.binding_curves_df)

    fig_path = nothing
    if plot_enabled
        fig_path = joinpath(output_dir, file_prefix * "hd_time_varying_security_region.png")
        try
            plot_hd_time_varying_region(analysis, fig_path; title_suffix = strip(replace(file_prefix, "_" => " ")))
        catch err
            @warn "Failed to render H-D time-varying security region figure" exception = (err, catch_backtrace())
            fig_path = nothing
        end
    end

    println("H-D time-varying binding curves & trajectory saved to: $(output_dir)")
    println("  - $(basename(traj_csv))")
    println("  - $(basename(curves_csv))")
    fig_path !== nothing && println("  - $(basename(fig_path))")

    return (
        analysis = analysis,
        trajectory_csv = traj_csv,
        binding_curves_csv = curves_csv,
        figure_path = fig_path,
    )
end
