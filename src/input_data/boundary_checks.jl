using DataFrames
using Printf

function _print_section(title::AbstractString)
    println("\n", repeat("=", 88))
    println(title)
    return println(repeat("=", 88))
end

function _print_kv(label::AbstractString, value)
    @printf("  %-36s %s\n", label * ":", value)
end

function _round4(x::Real)
    return round(Float64(x); digits = 4)
end

function _print_df(
    df::DataFrame;
    title::Union{Nothing, AbstractString} = nothing,
    allrows::Bool = true,
    allcols::Bool = true,
    display_cols::Int = 160,
)
    if title !== nothing
        println("\n  [", title, "]")
    end
    io = IOContext(stdout, :displaysize => (200, display_cols), :compact => true)
    show(io, df; allrows = allrows, allcols = allcols, eltypes = false, truncate = 64)
    println()
    return nothing
end

function _check_dimension!(checks::Vector{Tuple{String, Bool}}, label::String, condition::Bool)
    push!(checks, (label, condition))
    return nothing
end

function _print_checks(checks::Vector{Tuple{String, Bool}})
    _print_section("Consistency Checks")
    df = DataFrame(
        status = [ok ? "OK" : "FAIL" for (_, ok) in checks],
        check = [label for (label, _) in checks],
    )
    _print_df(df)
    if any(!ok for (_, ok) in checks)
        failed = [label for (label, ok) in checks if !ok]
        throw(ArgumentError("Boundary condition check failed: " * join(failed, "; ")))
    end
    return nothing
end

function _print_runtime_configuration()
    _print_section("Runtime Configuration (effective values)")
    config_path = get(ENV, "MODULE_UC_CONFIG_FILE", DEFAULT_RUNTIME_CONFIG_PATH)
    _print_kv("config file", config_path)

    entries = try
        runtime_config_entries(config_path)
    catch error
        println("  unable to read runtime config: ", sprint(showerror, error))
        Pair{String, String}[]
    end

    keys_col = String[]
    vals_col = String[]
    src_col = String[]
    for entry in sort(entries; by = item -> item.first)
        key = entry.first
        configured_value = entry.second
        has_env = haskey(ENV, key)
        effective_value = has_env ? ENV[key] : configured_value
        push!(keys_col, key)
        push!(vals_col, effective_value)
        push!(src_col, has_env && effective_value != configured_value ? "ENV" : "toml")
    end

    configured_keys = Set(first.(entries))
    runtime_prefixes = ("BENCHMARK_", "MODEL_", "BENDERS_", "CCG_", "FREQUENCY_")
    overrides = sort([
        key for key in keys(ENV) if
        any(startswith(key, prefix) for prefix in runtime_prefixes) && !(key in configured_keys)
    ])
    for key in overrides
        push!(keys_col, key)
        push!(vals_col, ENV[key])
        push!(src_col, "ENV (extra)")
    end

    if !isempty(keys_col)
        _print_df(DataFrame(key = keys_col, value = vals_col, source = src_col))
    end
    return nothing
end

boundary_env_bool(name::String, default::Bool) = uc_env_bool(name, default)

function maybe_print_boundarycondition(
    NB::Int64,
    NL::Int64,
    NG::Int64,
    NT::Int64,
    ND::Int64,
    units::unit,
    loads::load,
    lines::transmissionline,
    winds::wind,
    storages::pss,
    config_param::config,
    ;
    data_centers = nothing,
    default_enabled::Bool = true,
)
    if !boundary_env_bool("PRINT_BOUNDARY_CONDITION", default_enabled)
        return nothing
    end
    show_plots = boundary_env_bool("BOUNDARY_SHOW_PLOTS", false)
    return boundarycondition(
        NB,
        NL,
        NG,
        NT,
        ND,
        units,
        loads,
        lines,
        winds,
        storages,
        config_param;
        data_centers = data_centers,
        show_plots = show_plots,
    )
end

function boundrycondition(
    NB::Int64,
    NL::Int64,
    NG::Int64,
    NT::Int64,
    ND::Int64,
    units::unit,
    loads::load,
    lines::transmissionline,
    winds::wind,
    storages::pss,
    config_param::config,
    ;
    data_centers = nothing,
    show_plots::Bool = true,
)
    NS = winds.scenarios_nums
    NW = length(winds.index)

    checks = Tuple{String, Bool}[]
    _check_dimension!(checks, "NG matches length(units.index)", NG == length(units.index))
    _check_dimension!(checks, "NL matches length(lines.index)", NL == length(lines.index))
    _check_dimension!(checks, "ND matches length(loads.index)", ND == length(loads.index))
    _check_dimension!(checks, "NW matches length(winds.index)", NW == length(winds.index))
    _check_dimension!(checks, "NT matches load_curve columns", NT == size(loads.load_curve, 2))
    _check_dimension!(checks, "ND matches load_curve rows", ND == size(loads.load_curve, 1))
    _check_dimension!(checks, "NS matches wind scenario rows", NS == size(winds.scenarios_curve, 1))
    _check_dimension!(checks, "NT matches wind scenario columns", NT == size(winds.scenarios_curve, 2))
    _check_dimension!(checks, "generator p_max >= p_min", all(units.p_max .>= units.p_min))
    _check_dimension!(checks, "line p_max >= 0", all(lines.p_max .>= 0))
    _check_dimension!(checks, "load curve is finite and nonnegative", all(isfinite, loads.load_curve) && all(loads.load_curve .>= 0))
    _check_dimension!(checks, "wind scenarios are finite and nonnegative", all(isfinite, winds.scenarios_curve) && all(winds.scenarios_curve .>= 0))

    _print_section("Test System Boundary Summary")
    summary_df = DataFrame(
        metric = [
            "Buses (NB)",
            "Transmission lines (NL)",
            "Thermal generators (NG)",
            "Loads (ND)",
            "Time periods (NT)",
            "Wind units (NW)",
            "Wind scenarios (NS)",
            "Storage units (NC)",
            "Data center sites (ND2)",
            "Total generator Pmax",
            "Total generator Pmin",
            "Peak system load",
            "Total wind capacity",
            "Wind availability min / max",
        ],
        value = [
            string(NB),
            string(NL),
            string(NG),
            string(ND),
            string(NT),
            string(NW),
            string(NS),
            string(length(storages.index)),
            string(data_centers === nothing ? 0 : length(data_centers.index)),
            @sprintf("%.4f", sum(units.p_max)),
            @sprintf("%.4f", sum(units.p_min)),
            @sprintf("%.4f", maximum(sum(loads.load_curve; dims = 1))),
            @sprintf("%.4f", sum(winds.p_max)),
            @sprintf("%.4f / %.4f", minimum(winds.scenarios_curve), maximum(winds.scenarios_curve)),
        ],
    )
    _print_df(summary_df)

    _print_section("Configuration Flags")
    cfg_fields = collect(fieldnames(config))
    cfg_df = DataFrame(
        flag = String.(cfg_fields),
        value = [string(getfield(config_param, f)) for f in cfg_fields],
    )
    _print_df(cfg_df)
    _print_runtime_configuration()

    _print_section("Thermal Units")
    thermal_op_df = DataFrame(
        id = collect(units.index),
        bus = collect(units.locatebus),
        p_max = _round4.(units.p_max),
        p_min = _round4.(units.p_min),
        ramp_up = _round4.(units.ramp_up),
        ramp_dn = _round4.(units.ramp_down),
        su_ramp = _round4.(units.startup_ramp),
        sd_ramp = _round4.(units.shutdown_ramp),
        min_up = _round4.(units.min_up_time),
        min_dn = _round4.(units.min_down_time),
        x0 = _round4.(units.x_0),
        t0 = _round4.(units.t_0),
        p0 = _round4.(units.p_0),
    )
    _print_df(thermal_op_df; title = "Capacity, Ramp & Initial Status")

    thermal_cost_df = DataFrame(
        id = collect(units.index),
        a = _round4.(units.coeff_a),
        b = _round4.(units.coeff_b),
        c = _round4.(units.coeff_c),
        su_hot = _round4.(units.coeff_hot_startup),
        su_cold = _round4.(units.coeff_cold_startup),
        sd_cost = _round4.(units.coeff_shutdown),
        cold_t = _round4.(units.cold_start_time_limit),
        H = _round4.(units.Hg),
        D = _round4.(units.Dg),
        K = _round4.(units.Kg),
        F = _round4.(units.Fg),
        T = _round4.(units.Tg),
        R = _round4.(units.Rg),
    )
    _print_df(thermal_cost_df; title = "Cost & Frequency Response Parameters")

    _print_section("Loads")
    loads_summary_df = DataFrame(
        id = collect(loads.index),
        bus = collect(loads.locatebus),
        total_load = _round4.(vec(sum(loads.load_curve; dims = 2))),
        peak_load = _round4.(vec(maximum(loads.load_curve; dims = 2))),
        min_load = _round4.(vec(minimum(loads.load_curve; dims = 2))),
    )
    _print_df(loads_summary_df; title = "Load Bus Summary")

    load_curve_df = DataFrame(
        hour = collect(1:NT),
        system_total = _round4.(vec(sum(loads.load_curve; dims = 1))),
    )
    for d in 1:ND
        load_curve_df[!, Symbol("load_$(loads.index[d])")] = _round4.(vec(loads.load_curve[d, :]))
    end
    _print_df(load_curve_df; title = "Load Curve by Hour ($(ND) loads x $(NT) hours)", allcols = (ND <= 10))

    _print_section("Transmission Lines")
    lines_df = DataFrame(
        id = collect(lines.index),
        from = collect(lines.from),
        to = collect(lines.to),
        x = _round4.(lines.x),
        p_max = _round4.(lines.p_max),
        p_min = _round4.(lines.p_min),
    )
    _print_df(lines_df)

    _print_section("Wind Units and Scenarios")
    wind_units_df = DataFrame(
        id = collect(winds.index),
        bus = collect(winds.locatebus),
        p_max = _round4.(winds.p_max),
    )
    _print_df(wind_units_df; title = "Wind Units")

    prob_vec = winds.scenarios_prob isa AbstractVector ? Float64.(winds.scenarios_prob) : fill(Float64(winds.scenarios_prob), NS)
    wind_scen_summary_df = DataFrame(
        scenario = collect(1:NS),
        prob = _round4.(prob_vec[1:NS]),
        min_avail = _round4.(vec(minimum(winds.scenarios_curve; dims = 2))),
        mean_avail = _round4.(vec(sum(winds.scenarios_curve; dims = 2)) ./ NT),
        max_avail = _round4.(vec(maximum(winds.scenarios_curve; dims = 2))),
    )
    _print_df(wind_scen_summary_df; title = "Wind Scenarios Summary (NS=$(NS))")

    wind_curve_df = DataFrame(
        hour = collect(1:NT),
        mean_avail = _round4.(vec(sum(winds.scenarios_curve; dims = 1)) ./ NS),
    )
    for s in 1:NS
        wind_curve_df[!, Symbol("s$(s)")] = _round4.(vec(winds.scenarios_curve[s, :]))
    end
    _print_df(wind_curve_df; title = "Wind Scenario Curves by Hour ($(NS) scenarios x $(NT) hours)", allcols = (NS <= 10))

    _print_section("Storage Units")
    storage_df = DataFrame(
        id = collect(storages.index),
        bus = collect(storages.locatebus),
        Q_max = _round4.(storages.Q_max),
        Q_min = _round4.(storages.Q_min),
        p_chg = _round4.(storages.p⁺),
        p_dis = _round4.(storages.p⁻),
        P0 = _round4.(storages.P₀),
        gamma_chg = _round4.(storages.γ⁺),
        gamma_dis = _round4.(storages.γ⁻),
        eta_chg = _round4.(storages.η⁺),
        eta_dis = _round4.(storages.η⁻),
        self_dis = _round4.(storages.δₛ),
    )
    _print_df(storage_df)

    if data_centers !== nothing
        _print_section("Data Centers")
        dc_df = DataFrame(
            id = collect(data_centers.index),
            bus = collect(data_centers.locatebus),
            p_max = _round4.(data_centers.p_max),
            p_min = _round4.(data_centers.p_min),
            v_reg = _round4.(data_centers.voltage_regulation),
            idle_p = _round4.(data_centers.idle_power),
            sv_const = _round4.(data_centers.sv_constant),
            lambda = _round4.(data_centers.λ),
            mu = _round4.(data_centers.μ),
        )
        _print_df(dc_df; title = "Data Center Sites (ND2=$(length(data_centers.index)))")

        task_matrix = data_centers.computational_power_tasks
        n_dc = length(data_centers.index)
        oriented = if size(task_matrix, 1) == NT
            task_matrix
        elseif size(task_matrix, 2) == NT && size(task_matrix, 1) == n_dc
            permutedims(task_matrix)
        else
            task_matrix
        end
        n_rows, n_cols = size(oriented)
        task_df = DataFrame(hour = collect(1:n_rows))
        for j in 1:n_cols
            task_df[!, Symbol("task_$(j)")] = _round4.(vec(oriented[:, j]))
        end
        _print_df(task_df; title = "Computational Power Tasks ($(n_rows) x $(n_cols))", allcols = (n_cols <= 10))
    end

    if show_plots
        _print_section("Wind Scenario Curves")
        println(plt_unicodeplot(winds, loads, 0))
        _print_section("Demand Curve")
        println(plt_unicodeplot(winds, loads, 1))
    end

    _print_checks(checks)
    println("\nBoundary condition report completed successfully.\n")
    return nothing
end

function boundarycondition(args...; kwargs...)
    return boundrycondition(args...; kwargs...)
end

function boundary_condition(args...; kwargs...)
    return boundrycondition(args...; kwargs...)
end

function plt_unicodeplot(winds = nothing, loads = nothing, flag = 0)
    if !isdefined(@__MODULE__, :lineplot)
        series = flag == 0 ? winds.scenarios_curve[1, :] : loads.load_curve[1, :]
        label = flag == 0 ? "wind scenario 1" : "load 1"
        return "[UnicodePlots not loaded] $(label): len=$(length(series)), min=$(round(minimum(series); digits = 4)), max=$(round(maximum(series); digits = 4))"
    end
    lp = getfield(@__MODULE__, :lineplot)
    lp! = getfield(@__MODULE__, :lineplot!)
    if flag == 0
        NS = size(winds.scenarios_curve, 1)
        nt = size(winds.scenarios_curve, 2)
        xdata = collect(1:nt)
        plt = lp(
            xdata,
            winds.scenarios_curve[1, :];
            height = 10,
            xlim = (0, nt + 1),
            title = "stochastic realization of renewable resource",
            name = "wind farms",
            xlabel = "t / h",
            ylabel = "output / p.u.",
        )
        for i in 2:NS
            lp!(plt, xdata, winds.scenarios_curve[i, :])
        end
    else
        nt = size(loads.load_curve, 2)
        xdata = collect(1:nt)
        plt = lp(
            xdata,
            loads.load_curve[1, :];
            height = 10,
            xlim = (0, nt + 1),
            title = "sequential demand curve",
            name = "loads",
            xlabel = "t / h",
            ylabel = "output / p.u.",
        )
    end
    return plt
end

"""Canonical BlueStyle alias for `plt_unicodeplot` (标准命名入口: 终端字符曲线可视化)."""
const plot_unicode_profiles = plt_unicodeplot
