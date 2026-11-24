"""
    hd_estimation/hd_uc_adapter.jl

Adapter connecting `ModuleUnitCommitmentToolkit` UC system data (`units`, `winds`,
`storages`, `config_param`) to the H–D Frequency Security Region assessment and
pure-MILP JuMP constraint injection.
"""

using DataFrames
using JuMP
using Statistics

"""
    extract_uc_hd_parameters(units, winds, Δp_contingency; kwargs...) -> HDFrequencyParameters

Aggregate thermal unit and wind/converter frequency parameters from UC input data
into an equivalent single-area `HDFrequencyParameters` struct on the system
apparent power base `S_base = sum(units.p_max) + sum(winds.p_max)`.
"""
function extract_uc_hd_parameters(
    units,
    winds,
    Δp_contingency::Real;
    f0_hz::Float64 = frequency_env_float("FREQUENCY_BASE_HZ", 50.0),
    rocof_limit_hz_per_s::Float64 = frequency_env_float(
        "FREQUENCY_ROCOF_LIMIT_HZ_PER_S",
        4.5,
    ),
    nadir_limit_hz::Float64 = frequency_env_float("FREQUENCY_NADIR_LIMIT_HZ", 0.5),
    qss_limit_hz::Float64 = frequency_env_float("FREQUENCY_QSS_LIMIT_HZ", 0.5),
    damping_min::Float64 = frequency_env_float("FREQUENCY_HD_DAMPING_MIN", 0.0),
    damping_max::Float64 = frequency_env_float("FREQUENCY_HD_DAMPING_MAX", 15.0),
    damping_points::Int = max(
        5,
        floor(Int, frequency_env_float("FREQUENCY_HD_DAMPING_POINTS", 61.0)),
    ),
    inertia_max::Float64 = begin
        raw = strip(get(ENV, "FREQUENCY_HD_INERTIA_MAX", ""))
        isempty(raw) ? Inf : parse(Float64, raw)
    end,
    include_converter_support::Bool = frequency_env_bool(
        "FREQUENCY_HD_CONVERTER_ENABLED",
        true,
    ),
    area_id::Int = 1,
)
    NG = length(units.index)
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    sum_unit_capacity = max(sum(units.p_max), eps(Float64))

    # Capacity-weighted equivalent governor parameters across thermal fleet
    K_num = sum(
        unit_primary_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) for
        i = 1:NG
    )
    KF_num = sum(
        unit_turbine_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) for
        i = 1:NG
    )
    K_eq = max(K_num / sum_apparent_power, 1.0e-3)
    FH_eq = K_num > eps(Float64) ? clamp(KF_num / K_num, 0.0, 0.99) : 0.25

    T_vals = [safe_frequency_coeff(units.Tg, i; default = 8.0) for i = 1:NG]
    T_weights = [max(safe_frequency_coeff(units.p_max, i), 0.0) for i = 1:NG]
    T_eq =
        sum(T_weights) > eps(Float64) ? sum(T_vals .* T_weights) / sum(T_weights) :
        mean(T_vals)
    T_eq = max(T_eq, 0.1)

    wind_support =
        include_converter_support ? wind_frequency_capacity_support(winds) :
        (inertia = 0.0, damping = 0.0, primary = 0.0)
    H_vsm = wind_support.inertia / (2.0 * sum_apparent_power)
    D_vsm = wind_support.damping / sum_apparent_power
    K_conv = wind_support.primary / sum_apparent_power

    contingency_mw = frequency_contingency_size(units, Δp_contingency)
    delta_p_pu = contingency_mw / sum_apparent_power

    # Ensure damping search range covers both fleet damping capability and QSS minimum damping
    max_sync_damping =
        sum(
            safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) for
            i = 1:NG
        ) / sum_apparent_power
    qss_damping_req = max(
        0.0,
        hd_qss_min_damping(delta_p_pu, qss_limit_hz, K_eq; f0 = f0_hz) - (D_vsm + K_conv),
    )
    eff_damping_max = max(
        damping_max,
        max_sync_damping * 1.25 + 1.0,
        qss_damping_req + 5.0,
        damping_min + 1.0,
    )

    return HDFrequencyParameters(
        area_id = area_id,
        f0_hz = f0_hz,
        rocof_limit_hz_per_s = rocof_limit_hz_per_s,
        nadir_limit_hz = nadir_limit_hz,
        qss_limit_hz = qss_limit_hz,
        delta_p_pu = delta_p_pu,
        droop_gain_K = K_eq,
        turbine_fraction_FH = FH_eq,
        reheat_time_T = T_eq,
        H_vsm = H_vsm,
        D_vsm = D_vsm,
        K_conv = K_conv,
        damping_min = damping_min,
        damping_max = eff_damping_max,
        damping_points = damping_points,
        inertia_max = inertia_max,
    )
end

"""
    add_hd_frequency_constraints!(scuc::Model, NT, NG, NC, NS, units, storages, config_param, Δp_contingency; winds = nothing)

Add pure-MILP Inertia–Damping (H–D) Frequency Security Region constraints to `scuc`:
1. RoCoF minimum synchronous inertia floor: `H_sync[t] >= H_min_sync`
2. QSS + FRSR minimum synchronous damping floor: `D_sync[t] >= D_min_sync`
3. Nadir H–D coupling linear cuts: `H_sync[t] + beta_m * D_sync[t] >= alpha_m`
4. Standard QSS and SFR spinning reserve constraints (`add_qss_frequency_constraints!`, `add_sfr_reserve_constraints!`).
"""
function add_hd_frequency_constraints!(
    scuc::Model,
    NT::Int64,
    NG::Int64,
    NC::Int64,
    NS::Int64,
    units,
    storages,
    config_param,
    Δp_contingency;
    winds = nothing,
)
    if !haskey(JuMP.object_dictionary(scuc), :x)
        println(
            "\t constraints: 13) H-D frequency security constraints skipped (x not defined)",
        )
        return nothing
    end

    x = scuc[:x]
    hd_params = extract_uc_hd_parameters(units, winds, Δp_contingency)
    hd_region = assess_hd_frequency_region(hd_params)
    max_cuts = max(1, floor(Int, frequency_env_float("FREQUENCY_HD_MAX_CUTS", 6.0)))
    cuts = build_hd_linear_cuts(hd_region; max_cuts = max_cuts)

    if frequency_env_bool("FREQUENCY_HD_EXPORT_REPORT", false)
        println("\n--- H-D Frequency Security Region Assessment ---")
        io = IOContext(stdout, :displaysize => (100, 140), :compact => true)
        show(
            io,
            hd_region_summary_dataframe(hd_region);
            allrows = true,
            allcols = true,
            eltypes = false,
        )
        println()
        if !isempty(cuts.alpha)
            show(
                io,
                hd_cuts_dataframe(cuts);
                allrows = true,
                allcols = true,
                eltypes = false,
            )
            println()
        end
    end

    sum_apparent_power = frequency_sum_apparent_power(units, winds)

    H_sync_expr = @expression(
        scuc,
        [t = 1:NT],
        sum(
            safe_frequency_coeff(units.Hg, i) *
            safe_frequency_coeff(units.p_max, i) *
            x[i, t] for i = 1:NG
        ) / sum_apparent_power
    )
    D_sync_expr = @expression(
        scuc,
        [t = 1:NT],
        sum(
            safe_frequency_coeff(units.Dg, i) *
            safe_frequency_coeff(units.p_max, i) *
            x[i, t] for i = 1:NG
        ) / sum_apparent_power
    )

    rocof_constr = @constraint(scuc, [t = 1:NT], H_sync_expr[t] >= cuts.H_min_sync)
    damping_constr = if cuts.D_min_sync > 0.0
        @constraint(scuc, [t = 1:NT], D_sync_expr[t] >= cuts.D_min_sync)
    else
        nothing
    end
    nadir_cut_count = length(cuts.alpha)
    hd_nadir_constr = if nadir_cut_count > 0
        @constraint(
            scuc,
            [m = 1:nadir_cut_count, t = 1:NT],
            H_sync_expr[t] + cuts.beta[m] * D_sync_expr[t] >= cuts.alpha[m]
        )
    else
        nothing
    end

    # Upper binding constraints: H_sync <= H_max_sync, D_sync <= D_max_sync, and upper H-D cuts
    enforce_upper = frequency_env_bool("FREQUENCY_HD_ENFORCE_UPPER_BOUNDS", true)
    inertia_upper_constr = if enforce_upper && isfinite(cuts.H_max_sync)
        @constraint(scuc, [t = 1:NT], H_sync_expr[t] <= cuts.H_max_sync)
    else
        nothing
    end
    damping_upper_constr = if enforce_upper && isfinite(cuts.D_max_sync)
        @constraint(scuc, [t = 1:NT], D_sync_expr[t] <= cuts.D_max_sync)
    else
        nothing
    end
    upper_cut_count = length(cuts.alpha_upper)
    hd_upper_constr = if enforce_upper && upper_cut_count > 0
        @constraint(
            scuc,
            [m = 1:upper_cut_count, t = 1:NT],
            H_sync_expr[t] - cuts.beta_upper[m] * D_sync_expr[t] <= cuts.alpha_upper[m]
        )
    else
        nothing
    end

    fcr_threshold = frequency_env_float("FREQUENCY_FCR_THRESHOLD", 0.025)
    qss_constr =
        add_qss_frequency_constraints!(scuc, NT, NG, NS, units, x, hd_params.qss_limit_hz)
    sfr_constr = add_sfr_reserve_constraints!(
        scuc,
        NT,
        NG,
        NS,
        units,
        x,
        hd_params.nadir_limit_hz,
        fcr_threshold,
    )

    println(
        "\t constraints: 13) H-D frequency security region constraints ($(nadir_cut_count) lower, $(upper_cut_count) upper cuts)\t done",
    )
    return (
        mode = :hd_region,
        region = hd_region,
        cuts = cuts,
        H_sync = H_sync_expr,
        D_sync = D_sync_expr,
        rocof = rocof_constr,
        inertia_upper = inertia_upper_constr,
        damping = damping_constr,
        damping_upper = damping_upper_constr,
        nadir = hd_nadir_constr,
        hd_upper = hd_upper_constr,
        qss = qss_constr,
        sfr = sfr_constr,
    )
end

function _entity_areas(obj, n::Int)
    obj === nothing && return Int[]
    hasproperty(obj, :area) && length(obj.area) == n && return Int.(obj.area)
    return ones(Int, n)
end

function _slice_units_for_area(units, idxs::Vector{Int})
    return (
        index = units.index[idxs],
        p_max = units.p_max[idxs],
        Hg = units.Hg[idxs],
        Dg = units.Dg[idxs],
        Kg = units.Kg[idxs],
        Fg = units.Fg[idxs],
        Tg = units.Tg[idxs],
        Rg = units.Rg[idxs],
    )
end

function _slice_winds_for_area(winds, idxs::Vector{Int})
    (winds === nothing || isempty(idxs)) && return nothing
    return (
        index = winds.index[idxs],
        p_max = winds.p_max[idxs],
        Fcmode = winds.Fcmode[idxs],
        Kw = winds.Kw[idxs],
        Rw = winds.Rw[idxs],
        Mw = winds.Mw[idxs],
        Dw = winds.Dw[idxs],
        Tw = winds.Tw[idxs],
    )
end

"""
    extract_uc_hd_parameters_by_area(units, winds, Δp_contingency; kwargs...) -> Dict{Int, HDFrequencyParameters}

Group thermal and wind units by their `area` vector (defaulting to single area `1`) and
return per-area `HDFrequencyParameters`. `Δp_contingency` may be a scalar `Real` (applied
per area) or a `Dict{Int, <:Real}` mapping each `area_id` to its area contingency size.
"""
function extract_uc_hd_parameters_by_area(
    units,
    winds,
    Δp_contingency;
    kwargs...,
)
    NG = length(units.index)
    u_areas = _entity_areas(units, NG)
    w_areas = winds === nothing ? Int[] : _entity_areas(winds, length(winds.index))
    area_ids = sort!(unique(u_areas))
    params_by_area = Dict{Int, HDFrequencyParameters}()
    for a in area_ids
        u_idx = findall(==(a), u_areas)
        w_idx = findall(==(a), w_areas)
        area_units = _slice_units_for_area(units, u_idx)
        area_winds = _slice_winds_for_area(winds, w_idx)
        area_dp = Δp_contingency isa AbstractDict ? Δp_contingency[a] : Δp_contingency
        params_by_area[a] = extract_uc_hd_parameters(area_units, area_winds, area_dp; area_id = a, kwargs...)
    end
    return params_by_area
end

"""
    add_multi_area_hd_frequency_constraints!(scuc::Model, NT, NG, NC, NS, units, storages, config_param, Δp_contingency; winds = nothing, max_cuts = ...)

Inject independent H–D Frequency Security Region MILP cuts for every frequency-control area
defined by `units.area` (and `winds.area`), returning a `Dict{Int, NamedTuple}` keyed by `area_id`.
"""
function add_multi_area_hd_frequency_constraints!(
    scuc::Model,
    NT::Int64,
    NG::Int64,
    NC::Int64,
    NS::Int64,
    units,
    storages,
    config_param,
    Δp_contingency;
    winds = nothing,
    max_cuts::Int = max(1, floor(Int, frequency_env_float("FREQUENCY_HD_MAX_CUTS", 6.0))),
    kwargs...,
)
    haskey(JuMP.object_dictionary(scuc), :x) || return Dict{Int, NamedTuple}()
    x = scuc[:x]
    u_areas = _entity_areas(units, NG)
    w_areas = winds === nothing ? Int[] : _entity_areas(winds, length(winds.index))
    params_by_area = extract_uc_hd_parameters_by_area(units, winds, Δp_contingency; kwargs...)
    enforce_upper = frequency_env_bool("FREQUENCY_HD_ENFORCE_UPPER_BOUNDS", true)

    results = Dict{Int, NamedTuple}()
    for (a, hd_params) in sort!(collect(params_by_area); by = first)
        u_idx = findall(==(a), u_areas)
        w_idx = findall(==(a), w_areas)
        area_units = _slice_units_for_area(units, u_idx)
        area_winds = _slice_winds_for_area(winds, w_idx)
        hd_region = assess_hd_frequency_region(hd_params)
        cuts = build_hd_linear_cuts(hd_region; max_cuts = max_cuts)
        s_base = frequency_sum_apparent_power(area_units, area_winds)

        H_sync_a = @expression(
            scuc,
            [t = 1:NT],
            sum(safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in u_idx) / s_base
        )
        D_sync_a = @expression(
            scuc,
            [t = 1:NT],
            sum(safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in u_idx) / s_base
        )
        rocof_c = @constraint(scuc, [t = 1:NT], H_sync_a[t] >= cuts.H_min_sync)
        damping_c = cuts.D_min_sync > 0.0 ? @constraint(scuc, [t = 1:NT], D_sync_a[t] >= cuts.D_min_sync) : nothing
        nadir_c = !isempty(cuts.alpha) ?
            @constraint(scuc, [m = 1:length(cuts.alpha), t = 1:NT], H_sync_a[t] + cuts.beta[m] * D_sync_a[t] >= cuts.alpha[m]) :
            nothing
        upper_h = enforce_upper && isfinite(cuts.H_max_sync) ?
            @constraint(scuc, [t = 1:NT], H_sync_a[t] <= cuts.H_max_sync) : nothing
        upper_d = enforce_upper && isfinite(cuts.D_max_sync) ?
            @constraint(scuc, [t = 1:NT], D_sync_a[t] <= cuts.D_max_sync) : nothing
        results[a] = (
            area_id = a,
            unit_indices = u_idx,
            region = hd_region,
            cuts = cuts,
            H_sync = H_sync_a,
            D_sync = D_sync_a,
            rocof = rocof_c,
            damping = damping_c,
            nadir = nadir_c,
            inertia_upper = upper_h,
            damping_upper = upper_d,
        )
    end
    return results
end
