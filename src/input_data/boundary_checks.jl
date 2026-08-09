using Printf
using UnicodePlots

function _print_section(title::AbstractString)
    println("\n", repeat("=", 88))
    println(title)
    return println(repeat("=", 88))
end

function _print_kv(label::AbstractString, value)
    @printf("  %-36s %s\n", label * ":", value)
end

function _print_vector(label::AbstractString, value)
    return _print_kv(label, collect(value))
end

function _print_matrix_rows(label::AbstractString, matrix, row_count::Int64, col_count::Int64)
    println("  ", label, " (", row_count, " x ", col_count, "):")
    for i ∈ 1:row_count
        @printf("    row %02d:", i)
        for j ∈ 1:col_count
            @printf(" %10.4f", matrix[i, j])
        end
        println()
    end
end

function _check_dimension!(checks::Vector{Tuple{String, Bool}}, label::String, condition::Bool)
    push!(checks, (label, condition))
    return nothing
end

function _print_checks(checks::Vector{Tuple{String, Bool}})
    _print_section("Consistency Checks")
    for (label, ok) ∈ checks
        @printf("  [%s] %s\n", ok ? "OK" : "FAIL", label)
    end
    if any(!ok for (_, ok) ∈ checks)
        failed = [label for (label, ok) ∈ checks if !ok]
        throw(ArgumentError("Boundary condition check failed: " * join(failed, "; ")))
    end
    return nothing
end

function _print_runtime_configuration()
    _print_section("Runtime Configuration (effective values)")
    default_config_path = isdefined(@__MODULE__, :DEFAULT_RUNTIME_CONFIG_PATH) ? DEFAULT_RUNTIME_CONFIG_PATH : "config/runtime_config.toml"
    config_path = get(ENV, "MODULE_UC_CONFIG_FILE", default_config_path)
    _print_kv("config file", config_path)

    if !isdefined(@__MODULE__, :runtime_config_entries)
        println("  runtime_config_entries is unavailable; showing current ENV only")
        return nothing
    end

    entries = try
        runtime_config_entries(config_path)
    catch error
        println("  unable to read runtime config: ", sprint(showerror, error))
        Pair{String, String}[]
    end
    for entry ∈ sort(entries; by = item -> item.first)
        key = entry.first
        configured_value = entry.second
        effective_value = get(ENV, key, configured_value)
        _print_kv(key, effective_value)
    end

    configured_keys = Set(first.(entries))
    runtime_prefixes = ("BENCHMARK_", "MODEL_", "BENDERS_", "CCG_", "FREQUENCY_")
    overrides = sort([key for key ∈ keys(ENV) if any(startswith(key, prefix) for prefix ∈ runtime_prefixes) && !(key in configured_keys)])
    isempty(overrides) || begin
        println("  calibration/runtime overrides:")
        for key ∈ overrides
            _print_kv("    " * key, ENV[key])
        end
    end
    return nothing
end

function boundary_env_bool(name::String, default::Bool)
    value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    return value in ("1", "true", "yes", "y", "on")
end

function maybe_print_boundarycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit, loads::load, lines::transmissionline,
        winds::wind, stroges::pss, config_param::config, ; data_centers = nothing, default_enabled::Bool = true)
    if !boundary_env_bool("PRINT_BOUNDARY_CONDITION", default_enabled)
        return nothing
    end
    show_plots = boundary_env_bool("BOUNDARY_SHOW_PLOTS", false)
    return boundarycondition(
        NB, NL, NG, NT, ND, units, loads, lines, winds, stroges, config_param; data_centers = data_centers, show_plots = show_plots)
end

function boundrycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit, loads::load, lines::transmissionline,
        winds::wind, stroges::pss, config_param::config, ; data_centers = nothing, show_plots::Bool = true)
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
    _print_kv("Buses (NB)", NB)
    _print_kv("Transmission lines (NL)", NL)
    _print_kv("Thermal generators (NG)", NG)
    _print_kv("Loads (ND)", ND)
    _print_kv("Time periods (NT)", NT)
    _print_kv("Wind units (NW)", NW)
    _print_kv("Wind scenarios (NS)", NS)
    _print_kv("Storage units (NC)", length(stroges.index))
    _print_kv("Total generator Pmax", @sprintf("%.4f", sum(units.p_max)))
    _print_kv("Total generator Pmin", @sprintf("%.4f", sum(units.p_min)))
    _print_kv("Peak system load", @sprintf("%.4f", maximum(sum(loads.load_curve; dims = 1))))
    _print_kv("Total wind capacity", @sprintf("%.4f", sum(winds.p_max)))
    _print_kv("Wind availability min/max", @sprintf("%.4f / %.4f", minimum(winds.scenarios_curve), maximum(winds.scenarios_curve)))

    _print_section("Configuration Flags")
    for field ∈ fieldnames(config)
        _print_kv(String(field), getfield(config_param, field))
    end
    _print_runtime_configuration()

    _print_section("Thermal Units")
    _print_vector("index", units.index)
    _print_vector("locatebus", units.locatebus)
    _print_vector("p_max", units.p_max)
    _print_vector("p_min", units.p_min)
    _print_vector("ramp_up", units.ramp_up)
    _print_vector("ramp_down", units.ramp_down)
    _print_vector("startup ramp", units.shut_up)
    _print_vector("shutdown ramp", units.shut_down)
    _print_vector("min up time", units.min_shutup_time)
    _print_vector("min down time", units.min_shutdown_time)
    _print_vector("initial status", units.x_0)
    _print_vector("initial time", units.t_0)
    _print_vector("initial power", units.p_0)
    _print_vector("cost a", units.coffi_a)
    _print_vector("cost b", units.coffi_b)
    _print_vector("cost c", units.coffi_c)
    _print_vector("cold startup cost 1", units.coffi_cold_shutup_1)
    _print_vector("cold startup cost 2", units.coffi_cold_shutup_2)
    _print_vector("cold shutdown cost 1", units.coffi_cold_shutdown_1)
    _print_vector("cold shutdown cost 2", units.coffi_cold_shutdown_2)
    _print_vector("inertia H", units.Hg)
    _print_vector("damping D", units.Dg)
    _print_vector("governor gain K", units.Kg)
    _print_vector("turbine fraction F", units.Fg)
    _print_vector("time constant T", units.Tg)
    _print_vector("droop R", units.Rg)

    _print_section("Loads")
    _print_vector("index", loads.index)
    _print_vector("locatebus", loads.locatebus)
    _print_kv("load total by bus", vec(sum(loads.load_curve; dims = 2)))
    _print_kv("load total by time", vec(sum(loads.load_curve; dims = 1)))
    _print_matrix_rows("load_curve", loads.load_curve, ND, NT)

    _print_section("Transmission Lines")
    _print_vector("index", lines.index)
    _print_vector("from", lines.from)
    _print_vector("to", lines.to)
    _print_vector("reactance x", lines.x)
    _print_vector("forward p_max", lines.p_max)
    _print_vector("reverse p_min", lines.p_min)

    _print_section("Wind Units and Scenarios")
    _print_vector("index", winds.index)
    _print_vector("locatebus", winds.locatebus)
    _print_vector("installed capacity", winds.p_max)
    _print_kv("scenario probability", winds.scenarios_prob)
    _print_kv("scenario count", winds.scenarios_nums)
    _print_kv("scenario mean availability", vec(sum(winds.scenarios_curve; dims = 1)) ./ NS)
    _print_matrix_rows("wind scenario curves", winds.scenarios_curve, NS, NT)

    _print_section("Storage Units")
    _print_vector("index", stroges.index)
    _print_vector("locatebus", stroges.locatebus)
    _print_vector("Q_max", stroges.Q_max)
    _print_vector("Q_min", stroges.Q_min)
    _print_vector("charge power limit", stroges.p⁺)
    _print_vector("discharge power limit", stroges.p⁻)
    _print_vector("initial energy", stroges.P₀)
    _print_vector("charge ramp/cost parameter", stroges.γ⁺)
    _print_vector("discharge ramp/cost parameter", stroges.γ⁻)
    _print_vector("charge efficiency", stroges.η⁺)
    _print_vector("discharge efficiency", stroges.η⁻)
    _print_vector("self-discharge", stroges.δₛ)

    if data_centers !== nothing
        _print_section("Data Centers")
        _print_vector("index", data_centers.index)
        _print_vector("locatebus", data_centers.locatebus)
        _print_vector("p_max", data_centers.p_max)
        _print_vector("p_min", data_centers.p_min)
        _print_vector("voltage regulation", data_centers.voltage_regulation)
        _print_vector("idle power", data_centers.idale)
        _print_vector("server energy constant", data_centers.sv_constant)
        _print_vector("arrival rate lambda", data_centers.λ)
        _print_vector("service rate mu", data_centers.μ)
        task_matrix = data_centers.computational_power_tasks
        _print_matrix_rows("computational power tasks", task_matrix, size(task_matrix, 1), size(task_matrix, 2))
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
    xdata = collect(1:1:24)
    if flag == 0
        NS = size(winds.scenarios_curve, 1)
        plt = lineplot(xdata, winds.scenarios_curve[1, :]; height = 10, xlim = (0, 25), title = "stochastic realization of renewable resource",
            name = "wind farms", xlabel = "t / h", ylabel = "output / p.u.")
        for i ∈ 2:NS
            lineplot!(plt, xdata, winds.scenarios_curve[i, :])
        end
    else
        # ND = size( loads.load_curve,1)
        plt = lineplot(xdata, loads.load_curve[1, :]; height = 10, xlim = (0, 25), title = "sequential demand curve",
            name = "loads", xlabel = "t / h", ylabel = "output / p.u.")
    end
    return plt
end
