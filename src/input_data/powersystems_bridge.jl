using PowerSystems
using PowerSystemCaseBuilder
using CSV
using DataFrames
using Logging

export build_system_from_powersystems,
    extract_uc_data_from_powersystems, generate_wind_scenarios_from_system, load_native_powersystems_case, generate_frequency_parameters

const _POWER_SYSTEM_CASE_CATALOG = (
    ieee6 = (
        alias = "ieee6",
        aliases = ("ieee6", "ieee_6bus", "ieee6bus", "case6", "matpower_case6_sys"),
        case_name = "matpower_case6_sys",
        case_category = MatpowerTestSystems,
        description = "IEEE 6-bus MATPOWER case",
    ),
    ieee14 = (
        alias = "ieee14",
        aliases = ("ieee14", "ieee_14bus", "ieee14bus", "case14", "matpower_case14_sys"),
        case_name = "matpower_case14_sys",
        case_category = MatpowerTestSystems,
        description = "IEEE 14-bus MATPOWER case",
    ),
    ieee24 = (
        alias = "ieee24",
        aliases = ("ieee24", "ieee_24bus", "ieee24bus", "case24", "matpower_case24_sys"),
        case_name = "matpower_case24_sys",
        case_category = MatpowerTestSystems,
        description = "IEEE 24-bus MATPOWER case",
    ),
    ieee30 = (
        alias = "ieee30",
        aliases = ("ieee30", "ieee_30bus", "ieee30bus", "case30", "matpower_case30_sys"),
        case_name = "matpower_case30_sys",
        case_category = MatpowerTestSystems,
        description = "IEEE 30-bus MATPOWER case",
    ),
    ieee118 = (
        alias = "ieee118",
        aliases = ("ieee118", "ieee_118bus", "ieee118bus", "case118", "118_bus"),
        case_name = "118_bus",
        case_category = nothing,
        description = "118-bus PowerSystemsTestData case with thermal units, loads, and AC branches",
    ),
    c_sys5_all_components = (
        alias = "c_sys5_all_components",
        aliases = ("c_sys5_all_components",),
        case_name = "c_sys5_all_components",
        case_category = PSITestSystems,
        description = "5-bus case with renewable generation, storage, and multiple load types",
    ),
    rts_gmlc = (
        alias = "rts_gmlc",
        aliases = ("rts_gmlc", "matpower_rts_gmlc", "matpower_rts_gmlc_sys"),
        case_name = "matpower_RTS_GMLC_sys",
        case_category = MatpowerTestSystems,
        description = "RTS-GMLC MATPOWER case",
    ),
    activsg2000 = (
        alias = "activsg2000",
        aliases = ("activsg2000", "activsg_2000", "matpower_activsg2000_sys"),
        case_name = "matpower_ACTIVSg2000_sys",
        case_category = MatpowerTestSystems,
        description = "ACTIVSg2000 large MATPOWER case",
    ),
    activsg10k = (
        alias = "activsg10k",
        aliases = ("activsg10k", "activsg_10k", "matpower_activsg10k_sys"),
        case_name = "matpower_ACTIVSg10k_sys",
        case_category = MatpowerTestSystems,
        description = "ACTIVSg10k very-large MATPOWER case",
    ),
)

"""
    powersystems_case_catalog()

Return the immutable catalog used by the unified PowerSystems input entry point.
Each entry provides an `alias`, canonical `case_name`, `case_category`, and a
short description. `ieee118` is loaded from the 118-Bus artifact shipped with
`PowerSystemCaseBuilder`, because that case is not registered in the package's
default catalog.
"""
powersystems_case_catalog() = _POWER_SYSTEM_CASE_CATALOG

"""
    list_powersystems_cases()

Return the curated case entries as a vector in display order. The returned
named tuples are immutable and can be used directly to populate a UI selector
or a command-line case list.
"""
list_powersystems_cases() = collect(values(_POWER_SYSTEM_CASE_CATALOG))

function _normalize_powersystems_case_key(case_name)
    key = lowercase(strip(string(case_name)))
    return replace(key, r"[^a-z0-9]+" => "_") |> x -> strip(x, '_')
end

function _catalog_case(case_name)
    key = _normalize_powersystems_case_key(case_name)
    for entry in values(_POWER_SYSTEM_CASE_CATALOG)
        key in (_normalize_powersystems_case_key(alias) for alias in entry.aliases) && return entry
    end
    return nothing
end

function _build_case_builder_system(case_category::Type{<:SystemCategory}, case_name::AbstractString; kwargs...)
    # PowerSystemCaseBuilder emits raw-data conformity diagnostics while it
    # deserializes several MATPOWER cases. Keep those implementation details
    # out of the unified API output; construction errors still propagate.
    return with_logger(NullLogger()) do
        build_system(case_category, case_name; kwargs...)
    end
end

function _power_system_case_data_dir()
    isdefined(PowerSystemCaseBuilder, :DATA_DIR) ||
        throw(ArgumentError("PowerSystemCaseBuilder does not expose its case-data artifact directory"))
    data_dir = getproperty(PowerSystemCaseBuilder, :DATA_DIR)
    case_dir = joinpath(data_dir, "118-Bus")
    isdir(case_dir) || throw(ArgumentError("The PowerSystemsTestData 118-Bus artifact is unavailable at $case_dir"))
    return case_dir
end

function _ieee118_float(value, default::Float64 = 0.0)
    value === missing && return default
    value isa AbstractString && isempty(strip(value)) && return default
    parsed = tryparse(Float64, string(value))
    return parsed === nothing ? default : parsed
end

function _ieee118_bus_number(value)
    parsed = tryparse(Int, string(value))
    parsed === nothing && throw(ArgumentError("Invalid IEEE 118 bus number: $value"))
    return parsed
end

function _ieee118_component_bus(value)
    digits = match(r"(\d+)$", strip(string(value)))
    digits === nothing && throw(ArgumentError("Invalid IEEE 118 component bus identifier: $value"))
    return parse(Int, digits.captures[1])
end

function _build_ieee118_system()
    case_dir = _power_system_case_data_dir()
    base_power = 100.0
    bus_df = CSV.read(joinpath(case_dir, "Buses.csv"), DataFrame)
    line_df = CSV.read(joinpath(case_dir, "Lines.csv"), DataFrame)
    generator_df = CSV.read(joinpath(case_dir, "gen.csv"), DataFrame)
    participation_df = CSV.read(joinpath(case_dir, "Load", "partfact.csv"), DataFrame)

    bus_by_number = Dict{Int, ACBus}()
    buses = ACBus[]
    for row in eachrow(bus_df)
        number = _ieee118_bus_number(row["Number"])
        bus = ACBus(
            name = "bus$(lpad(number, 3, '0'))",
            available = true,
            number = number,
            bustype = number == 69 ? ACBusTypes.REF : ACBusTypes.PQ,
            angle = _ieee118_float(row["Angle"]),
            magnitude = _ieee118_float(row["Magnitude "], 1.0),
            voltage_limits = (
                min = _ieee118_float(row["Voltage-Min (pu)"], 0.94),
                max = _ieee118_float(row["Voltage-Max (pu)"], 1.06),
            ),
            base_voltage = _ieee118_float(row["Base Voltage kV"], 138.0),
        )
        bus_by_number[number] = bus
        push!(buses, bus)
    end
    sort!(buses, by = get_number)

    generators = ThermalStandard[]
    for row in eachrow(generator_df)
        strip(String(row["type"])) == "Thermal" || continue
        bus_number = _ieee118_component_bus(row["bus of connection"])
        haskey(bus_by_number, bus_number) || throw(ArgumentError("IEEE 118 generator references unknown bus $bus_number"))
        maximum_power = max(_ieee118_float(row["Max Capacity (MW)"]), 0.0)
        minimum_power = clamp(_ieee118_float(row["Min Stable Level (MW)"], 0.0), 0.0, maximum_power)
        ramp_up = max(_ieee118_float(row["Max Ramp Up (MW/min)"], maximum_power), 0.0)
        ramp_down = max(_ieee118_float(row["Max Ramp Down (MW/min)"], maximum_power), 0.0)
        generator = ThermalStandard(
            name = String(row["Generator Name"]),
            available = true,
            status = true,
            bus = bus_by_number[bus_number],
            active_power = minimum_power / base_power,
            reactive_power = 0.0,
            rating = maximum_power / base_power,
            active_power_limits = (min = minimum_power / base_power, max = maximum_power / base_power),
            reactive_power_limits = nothing,
            ramp_limits = (up = ramp_up / base_power, down = ramp_down / base_power),
            operation_cost = ThermalGenerationCost(nothing),
            base_power = base_power,
            time_limits = (
                up = max(_ieee118_float(row["Min Up Time (h)"], 1.0), 0.0),
                down = max(_ieee118_float(row["Min Down Time (h)"], 1.0), 0.0),
            ),
            prime_mover_type = PrimeMovers.OT,
            fuel = ThermalFuels.OTHER,
        )
        push!(generators, generator)
    end

    branches = Line[]
    for (index, row) in enumerate(eachrow(line_df))
        from_number = _ieee118_component_bus(row["Bus from "])
        to_number = _ieee118_component_bus(row["Bus to"])
        haskey(bus_by_number, from_number) && haskey(bus_by_number, to_number) ||
            throw(ArgumentError("IEEE 118 branch $index references an unknown bus"))
        rating = max(_ieee118_float(row["Max Flow (MW)"], 0.0), 0.0)
        push!(
            branches,
            Line(
                name = String(row["Line Name"]),
                available = true,
                active_power_flow = 0.0,
                reactive_power_flow = 0.0,
                arc = Arc(bus_by_number[from_number], bus_by_number[to_number]),
                r = _ieee118_float(row["Resistance (p.u.)"]),
                x = _ieee118_float(row["Reactance (p.u.)"], 0.01),
                b = (from = 0.0, to = 0.0),
                rating = rating / base_power,
                angle_limits = (min = -pi, max = pi),
            ),
        )
    end

    regional_peaks = Dict{String, Float64}()
    for region in ("R1", "R2", "R3")
        profile = CSV.read(joinpath(case_dir, "Load", "RT", "Load$(region)RT.csv"), DataFrame)
        regional_peaks[region] = maximum(_ieee118_float.(profile[:, 2], 0.0))
    end
    loads = PowerLoad[]
    for row in eachrow(participation_df)
        bus_number = _ieee118_component_bus(row["Bus Name"])
        haskey(bus_by_number, bus_number) || throw(ArgumentError("IEEE 118 load references unknown bus $bus_number"))
        region = String(row["Region"])
        factor = max(_ieee118_float(row["Load Participation Factor"]), 0.0)
        maximum_power = max(regional_peaks[region] * factor, 0.0)
        push!(
            loads,
            PowerLoad(
                name = "load$(lpad(bus_number, 3, '0'))",
                available = true,
                bus = bus_by_number[bus_number],
                active_power = maximum_power / base_power,
                reactive_power = 0.0,
                base_power = base_power,
                max_active_power = maximum_power / base_power,
                max_reactive_power = 0.0,
            ),
        )
    end

    system = System(base_power; runchecks = false)
    for component in (buses, generators, branches, loads)
        for item in component
            add_component!(system, item)
        end
    end
    return system
end

"""
    build_system_from_powersystems(case_name; case_category = MatpowerTestSystems)

Build a native `PowerSystems.System` from a `PowerSystemCaseBuilder` catalog.
Use a category such as `MatpowerTestSystems`, `PSISystems`, or `PSYTestSystems`
to select the catalog. A file path is passed to `PowerSystems.System` directly.
"""
function build_system_from_powersystems(case_name::Union{Symbol, AbstractString}; case_category::Type{<:SystemCategory} = MatpowerTestSystems, kwargs...)
    catalog_case = _catalog_case(case_name)
    if catalog_case !== nothing
        catalog_case.alias == "ieee118" && return _build_ieee118_system()
        return _build_case_builder_system(catalog_case.case_category, catalog_case.case_name; kwargs...)
    end

    case_path = String(case_name)
    if isfile(case_path)
        return System(case_path)
    end
    return _build_case_builder_system(case_category, case_path; kwargs...)
end

"""
    load_native_powersystems_case(case_name; kwargs...)

Build a catalog case and convert its grid, generation, frequency-response, and
data-center data to the toolkit input structures without requiring an auxiliary
CSV directory. `frequency_parameters` is a dictionary keyed by thermal generator
name. Each value is a named tuple with `H`, `D`, `K`, `F`, `T`, and `R` fields.
`data_centers` is a vector of named tuples with at least `bus` and `p_max` in MW;
optional fields are `p_min`, `idle_power`, `server_energy`, `lambda`, `mu`, and
`workload`.
"""
function load_native_powersystems_case(
    case_name::Union{Symbol, AbstractString};
    case_category::Type{<:SystemCategory} = MatpowerTestSystems,
    scenario_limit::Int64 = 50,
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
    kwargs...,
)
    sys = build_system_from_powersystems(case_name; case_category = case_category, kwargs...)
    return _load_native_powersystems_system(
        sys;
        scenario_limit = scenario_limit,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
    )
end

function _field_or_default(value, name::Symbol, default)
    if value isa AbstractDict
        return get(value, name, get(value, String(name), default))
    elseif hasproperty(value, name)
        return getproperty(value, name)
    end
    return default
end

function _finite_float(value, default::Float64)
    parsed = try
        Float64(value)
    catch
        default
    end
    return isfinite(parsed) ? parsed : default
end

function _frequency_value(parameters, generator_name::String, index::Int, field::Symbol, default::Float64)
    parameters === nothing && return default
    if parameters isa AbstractDict
        record = get(parameters, generator_name, nothing)
        record === nothing && return default
        return Float64(_field_or_default(record, field, default))
    elseif parameters isa AbstractMatrix
        column = Dict(:H => 2, :D => 3, :K => 4, :F => 5, :T => 6, :R => 7)[field]
        size(parameters, 2) >= column || throw(ArgumentError("frequency_parameters matrix needs at least 7 columns"))
        return index <= size(parameters, 1) ? Float64(parameters[index, column]) : default
    end
    return throw(ArgumentError("frequency_parameters must be a generator-name dictionary or a legacy matrix"))
end

function _time_series_or_static(component, horizon::Int64)
    for label in ("max_active_power", "active_power", "scaling_factor_active_power")
        try
            values = Float64.(collect(get_time_series_values(SingleTimeSeries, component, label)))
            isempty(values) && continue
            if label == "scaling_factor_active_power"
                values .*= get_max_active_power(component)
            end
            return if length(values) >= horizon
                values[1:horizon]
            else
                vcat(values, fill(values[end], horizon - length(values)))
            end
        catch
        end
    end
    return fill(Float64(get_max_active_power(component)), horizon)
end

function _thermal_cost_coefficients(generator, base_power::Float64)
    a = 0.0
    b = 10.0
    c = 0.0
    operation_cost = getproperty(generator, :operation_cost)
    if hasproperty(operation_cost, :fixed)
        c = _finite_float(operation_cost.fixed, c)
    end
    if hasproperty(operation_cost, :variable)
        variable_cost = operation_cost.variable
        if hasproperty(variable_cost, :value_curve)
            data = variable_cost.value_curve.function_data
            a = _finite_float(_field_or_default(data, :quadratic_term, a), a)
            b = _finite_float(_field_or_default(data, :proportional_term, b), b)
            c += _finite_float(_field_or_default(data, :constant_term, 0.0), 0.0)
        end
    end
    return _finite_float(a * base_power^2, 0.0), _finite_float(b * base_power, 10.0 * base_power), _finite_float(c, 0.0)
end

function _normalize_data_centers(data_centers, legacy_buses, legacy_pmax)
    isempty(data_centers) ||
        (isempty(legacy_buses) && isempty(legacy_pmax)) ||
        throw(ArgumentError("Pass either data_centers or data_center_buses/data_center_pmax, not both"))
    if !isempty(data_centers)
        return data_centers
    end
    length(legacy_buses) == length(legacy_pmax) || throw(ArgumentError("data_center_buses and data_center_pmax must have the same length"))
    return [(bus = legacy_buses[i], p_max = legacy_pmax[i]) for i in eachindex(legacy_buses)]
end

function _data_center_struct(data_centers, bus_to_index::Dict{Int, Int}, horizon::Int64, base_power::Float64)
    count = length(data_centers)
    count == 0 && return data_centra(Int64[], Int64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], zeros(0, horizon))

    index = collect(Int64(1):Int64(count))
    locatebus = Int64[]
    p_max = Float64[]
    p_min = Float64[]
    voltage_regulation = Float64[]
    idle_power = Float64[]
    server_energy = Float64[]
    lambda = Float64[]
    mu = Float64[]
    workloads = zeros(count, horizon)
    for (i, center) in enumerate(data_centers)
        bus = Int(_field_or_default(center, :bus, 0))
        haskey(bus_to_index, bus) || throw(ArgumentError("Data center $i references unknown bus $bus"))
        maximum_power = Float64(_field_or_default(center, :p_max, -1.0))
        minimum_power = Float64(_field_or_default(center, :p_min, 0.0))
        maximum_power >= minimum_power >= 0 || throw(ArgumentError("Invalid data center power limits at index $i"))
        service_rate = Float64(_field_or_default(center, :mu, 1.0))
        service_rate > 0 || throw(ArgumentError("Data center service rate mu must be positive at index $i"))
        workload = Float64.(collect(_field_or_default(center, :workload, fill(0.0, horizon))))
        isempty(workload) && throw(ArgumentError("Data center workload cannot be empty at index $i"))
        workloads[i, :] = if length(workload) >= horizon
            workload[1:horizon]
        else
            vcat(workload, fill(workload[end], horizon - length(workload)))
        end

        push!(locatebus, bus_to_index[bus])
        push!(p_max, maximum_power / base_power)
        push!(p_min, minimum_power / base_power)
        push!(voltage_regulation, Float64(_field_or_default(center, :voltage_regulation, 0.0)))
        push!(idle_power, Float64(_field_or_default(center, :idle_power, 0.0)) / base_power)
        push!(server_energy, Float64(_field_or_default(center, :server_energy, 0.0)) / base_power)
        push!(lambda, Float64(_field_or_default(center, :lambda, 0.0)))
        push!(mu, service_rate)
    end
    return data_centra(index, locatebus, p_max, p_min, voltage_regulation, idle_power, server_energy, lambda, mu, workloads)
end

"""
    extract_uc_data_from_powersystems(sys; frequency_parameters, data_centers, horizon)

Convert a `PowerSystems.System` into the toolkit's UC structures. Native
PowerSystems component quantities are already expressed in the system-base
per-unit convention and are passed through without a second base-power
division. Power quantities supplied through `data_centers` are in MW and are
converted with the native system base power. The function keeps a contiguous
internal bus index so arbitrary PowerSystems bus numbers are supported.
"""
function extract_uc_data_from_powersystems(
    sys::System;
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_params_override = nothing,
    frequency_parameters = frequency_params_override,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    horizon > 0 || throw(ArgumentError("horizon must be positive"))
    base_power = Float64(get_base_power(sys))
    buses = sort(collect(get_components(ACBus, sys)), by = get_number)
    isempty(buses) && throw(ArgumentError("PowerSystems system has no AC buses"))
    bus_to_index = Dict{Int, Int}(get_number(bus) => index for (index, bus) in enumerate(buses))
    bus_index(bus) = bus_to_index[get_number(bus)]

    generators = sort(collect(get_components(ThermalStandard, sys)), by = get_name)
    isempty(generators) && throw(ArgumentError("PowerSystems system has no ThermalStandard generators"))
    generator_count = length(generators)
    generator_index = collect(Int64(1):Int64(generator_count))
    generator_bus = Int64[bus_index(get_bus(generator)) for generator in generators]
    p_max = Float64[];
    p_min = Float64[];
    ramp_up = Float64[];
    ramp_down = Float64[];
    startup_ramp = Float64[];
    shutdown_ramp = Float64[]
    min_up = Float64[];
    min_down = Float64[];
    initial_status = Float64[];
    initial_hours = Float64[];
    initial_power = Float64[]
    cost_a = Float64[];
    cost_b = Float64[];
    cost_c = Float64[];
    hot_start = Float64[];
    cold_start = Float64[];
    shutdown_cost = Float64[];
    cold_time = Float64[]
    inertia = Float64[];
    damping = Float64[];
    gain = Float64[];
    turbine_fraction = Float64[];
    time_constant = Float64[];
    droop = Float64[]
    for (index, generator) in enumerate(generators)
        limits = get_active_power_limits(generator)
        ramps = getproperty(generator, :ramp_limits)
        time_limits = getproperty(generator, :time_limits)
        active_limit_max = Float64(limits.max)
        native_rating = max(Float64(get_rating(generator)), 0.0)
        # Some MATPOWER generator rows are parsed by PowerSystems with a zero
        # active-power upper limit even though their generator rating is
        # positive. Keep those units available to UC by falling back to the
        # native rating only for the zero-limit case; preserve an explicitly
        # smaller positive active-power limit.
        maximum_power = active_limit_max > 0.0 ? active_limit_max : native_rating
        # PowerSystems uses SYSTEM_BASE units for component power values. These
        # quantities are already per-unit on the system base; dividing by
        # `base_power` here would perform a second, incorrect normalization.
        push!(p_max, maximum_power);
        push!(p_min, Float64(limits.min))
        push!(ramp_up, Float64(_field_or_default(ramps, :up, maximum_power)))
        push!(ramp_down, Float64(_field_or_default(ramps, :down, maximum_power)))
        push!(startup_ramp, maximum_power);
        push!(shutdown_ramp, maximum_power)
        push!(min_up, Float64(_field_or_default(time_limits, :up, 1.0)));
        push!(min_down, Float64(_field_or_default(time_limits, :down, 1.0)))
        push!(initial_status, getproperty(generator, :status) ? 1.0 : 0.0);
        push!(initial_hours, 1.0);
        push!(initial_power, Float64(getproperty(generator, :active_power)))
        a, b, c = _thermal_cost_coefficients(generator, base_power)
        push!(cost_a, a);
        push!(cost_b, b);
        push!(cost_c, c)
        operation_cost = getproperty(generator, :operation_cost)
        startup_cost_value = _finite_float(_field_or_default(operation_cost, :start_up, 0.0), 0.0)
        push!(hot_start, startup_cost_value);
        push!(cold_start, startup_cost_value);
        push!(shutdown_cost, _finite_float(_field_or_default(operation_cost, :shut_down, 0.0), 0.0));
        push!(cold_time, 1.0)
        name = get_name(generator)
        push!(inertia, _frequency_value(frequency_parameters, name, index, :H, 5.0));
        push!(damping, _frequency_value(frequency_parameters, name, index, :D, 0.0))
        push!(gain, _frequency_value(frequency_parameters, name, index, :K, 0.0));
        push!(turbine_fraction, _frequency_value(frequency_parameters, name, index, :F, 0.0))
        push!(time_constant, _frequency_value(frequency_parameters, name, index, :T, 0.0));
        push!(droop, _frequency_value(frequency_parameters, name, index, :R, 1.0))
    end
    units = unit(
        generator_index, generator_bus,
        p_max, p_min, ramp_up, ramp_down, startup_ramp, shutdown_ramp, min_up, min_down,
        initial_status, initial_hours, initial_power,
        cost_a, cost_b, cost_c, hot_start, cold_start, shutdown_cost, cold_time, inertia, damping, gain, turbine_fraction, time_constant, droop,
    )

    branches = sort(collect(get_components(ACBranch, sys)), by = get_name)
    branch_count = length(branches)
    lines = transmissionline(
        collect(Int64(1):Int64(branch_count)),
        Int64[bus_index(get_from(get_arc(branch))) for branch in branches],
        Int64[bus_index(get_to(get_arc(branch))) for branch in branches],
        Float64[get_x(branch) for branch in branches],
        Float64[get_rating(branch) for branch in branches],
        Float64[-get_rating(branch) for branch in branches],
    )

    power_loads = sort(collect(get_components(PowerLoad, sys)), by = get_name)
    load_count = length(power_loads)
    loads = load(
        collect(Int64(1):Int64(load_count)),
        Int64[bus_index(get_bus(power_load)) for power_load in power_loads],
        reduce(vcat, [_time_series_or_static(power_load, horizon)' for power_load in power_loads]; init = zeros(0, horizon)),
    )

    storage = sort(collect(get_components(EnergyReservoirStorage, sys)), by = get_name)
    storage_count = length(storage)
    psses = pss(
        collect(Int64(1):Int64(storage_count)),
        Int64[bus_index(get_bus(item)) for item in storage],
        Float64[get_storage_capacity(item) for item in storage],
        Float64[get_storage_level_limits(item).min for item in storage],
        Float64[get_input_active_power_limits(item).max for item in storage],
        Float64[get_output_active_power_limits(item).max for item in storage],
        Float64[get_initial_storage_capacity_level(item) for item in storage],
        Float64[get_input_active_power_limits(item).max for item in storage],
        Float64[get_output_active_power_limits(item).max for item in storage],
        Float64[get_efficiency(item).in for item in storage],
        Float64[get_efficiency(item).out for item in storage],
        zeros(storage_count),
    )

    centers = _normalize_data_centers(data_centers, data_center_buses, data_center_pmax)
    data_center_data = _data_center_struct(centers, bus_to_index, horizon, base_power)
    config_parameter = config_from_env()

    # Keep thermal and renewable frequency settings in the same public
    # dictionary. Thermal records use H/D/K/F/T/R; renewable records use the
    # native wind fields Fcmode/Kw/Rw/Mw/Dw/Tw. This lets a caller configure
    # all frequency resources through one UCSolveRequest.frequency_parameters
    # value without introducing a second input channel.
    renewables = sort(collect(get_components(RenewableGen, sys)), by = get_name)
    renewable_frequency_parameters = zeros(length(renewables), 6)
    for (index, renewable) in enumerate(renewables)
        record = if frequency_parameters isa AbstractDict
            get(frequency_parameters, get_name(renewable), nothing)
        else
            nothing
        end
        record === nothing && continue
        renewable_frequency_parameters[index, 1] = _finite_float(_field_or_default(record, :Fcmode, 0.0), 0.0)
        renewable_frequency_parameters[index, 2] = _finite_float(_field_or_default(record, :Kw, 0.0), 0.0)
        renewable_frequency_parameters[index, 3] = _finite_float(_field_or_default(record, :Rw, 1.0), 1.0)
        renewable_frequency_parameters[index, 4] = _finite_float(_field_or_default(record, :Mw, 0.0), 0.0)
        renewable_frequency_parameters[index, 5] = _finite_float(_field_or_default(record, :Dw, 0.0), 0.0)
        renewable_frequency_parameters[index, 6] = _finite_float(_field_or_default(record, :Tw, 0.0), 0.0)
    end
    return config_parameter,
    units, lines, loads, psses, length(buses), generator_count, branch_count, load_count,
    horizon, storage_count, length(centers), data_center_data, renewable_frequency_parameters, bus_to_index
end

function generate_wind_scenarios_from_system(
    sys::System,
    wind_frequency_parameters::Matrix{Float64},
    mode::Int,
    horizon::Int64 = 24;
    bus_to_idx::Dict{Int, Int} = Dict{Int, Int}(),
    scenario_limit::Int64 = 50,
)
    renewables = sort(collect(get_components(RenewableGen, sys)), by = get_name)
    base_power = Float64(get_base_power(sys))
    count = length(renewables)
    count == 0 &&
        return wind(Int64[], Int64[], Float64[], 1.0, 1, zeros(1, horizon), Float64[], Float64[], Float64[], Float64[], Float64[], Float64[]), 0
    index = collect(Int64(1):Int64(count))
    locatebus = Int64[get(bus_to_idx, get_number(get_bus(item)), get_number(get_bus(item))) for item in renewables]
    p_max = Float64[get_rating(item) for item in renewables]
    base_profile =
        reshape([clamp(Float64(getproperty(item, :active_power)) / max(Float64(get_rating(item)), eps()), 0.0, 1.0) for item in renewables], :, 1)
    profile = repeat(mean(base_profile; dims = 1), 1, horizon)
    scenarios = if mode == 1
        generate_weibull_wind_availability(profile, scenario_limit, horizon)
    else
        profile
    end
    frequency = if size(wind_frequency_parameters, 1) == count
        wind_frequency_parameters
    else
        zeros(count, 6)
    end
    scenario_count = size(scenarios, 1)
    return wind(
        index,
        locatebus,
        p_max,
        1.0 / scenario_count,
        scenario_count,
        scenarios,
        frequency[:, 1],
        frequency[:, 2],
        frequency[:, 3],
        frequency[:, 4],
        frequency[:, 5],
        frequency[:, 6],
    ),
    count
end

function _load_native_powersystems_system(sys::System; scenario_limit::Int64, frequency_parameters, data_centers, horizon::Int64)
    config_parameter, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, data_center_data, wind_frequency_parameters, bus_to_index =
        extract_uc_data_from_powersystems(sys; frequency_parameters = frequency_parameters, data_centers = data_centers, horizon = horizon)
    winds, NW = generate_wind_scenarios_from_system(sys, wind_frequency_parameters, 1, NT; bus_to_idx = bus_to_index, scenario_limit = scenario_limit)
    NS = Int64(winds.scenarios_nums)
    return (
        config_param = config_parameter,
        units = units,
        lines = lines,
        loads = loads,
        winds = winds,
        psses = psses,
        DataCentras = data_center_data,
        NB = NB,
        NG = NG,
        NL = NL,
        ND = ND,
        NT = NT,
        NC = NC,
        ND2 = ND2,
        NW = NW,
        NS = NS,
        full_scenario_probability = 1.0 / NS,
    )
end

"""
    generate_frequency_parameters(sys::System; overrides::Dict = Dict())

Generate a complete frequency parameters dictionary for all conventional generators 
in the given PowerSystems `System`. The default parameters are assigned based on the 
generator's fuel type and name prefix to ensure realistic physical behavior.

Chinese description:
根据 PowerSystems 系统对象自动为所有常规机组生成调频参数字典。默认参数根据机组燃料类型和
名称特征匹配，符合真实物理特性，同时支持用户自定义覆盖。
"""
function generate_frequency_parameters(sys::System; overrides::Dict = Dict())
    frequency_parameters = Dict{String, NamedTuple}()

    # Define templates for typical generator technologies
    # 定义各类发电技术的典型调频参数模板
    templates = Dict(
        :coal => (H = 6.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05),
        :gas => (H = 4.0, D = 0.05, K = 0.90, F = 0.15, T = 5.0, R = 0.04),
        :hydro => (H = 3.0, D = 0.10, K = 1.00, F = 0.50, T = 4.0, R = 0.05),
        :nuclear => (H = 7.0, D = 0.10, K = 0.00, F = 0.00, T = 0.0, R = 1.00), # No governor response
        :default => (H = 5.0, D = 0.00, K = 0.00, F = 0.00, T = 0.0, R = 1.00),  # Safe default (no governor)
    )

    for generator in get_components(ThermalGen, sys)
        name = get_name(generator)

        # Check user overrides first
        # 优先使用用户自定义的机组覆盖
        if haskey(overrides, name)
            frequency_parameters[name] = overrides[name]
            continue
        end

        # Determine fuel type if available in PowerSystems
        # 从 PowerSystems 机组信息获取燃料类型或类型名称
        fuel = :default
        if hasproperty(generator, :fuel)
            try
                gen_fuel = get_fuel(generator)
                fuel_str = lowercase(string(gen_fuel))
                if occursin("coal", fuel_str) || occursin("coal/steam", fuel_str) || occursin("steam", fuel_str)
                    fuel = :coal
                elseif occursin("gas", fuel_str) || occursin("distillate", fuel_str) || occursin("oil", fuel_str)
                    fuel = :gas
                elseif occursin("hydro", fuel_str) || occursin("water", fuel_str)
                    fuel = :hydro
                elseif occursin("nuclear", fuel_str)
                    fuel = :nuclear
                end
            catch
            end
        end

        # Secondary check based on name heuristic if fuel property wasn't conclusive
        # 若燃料属性不明确，根据名称特征进行启发式匹配
        if fuel == :default
            lower_name = lowercase(name)
            if occursin("solitude", lower_name) || occursin("coal", lower_name) || occursin("steam", lower_name)
                fuel = :coal
            elseif occursin("park city", lower_name) ||
                   occursin("alta", lower_name) ||
                   occursin("gas", lower_name) ||
                   occursin("combustion", lower_name)
                fuel = :gas
            elseif occursin("hydro", lower_name) || occursin("water", lower_name)
                fuel = :hydro
            elseif occursin("nuclear", lower_name) || occursin("nuc", lower_name)
                fuel = :nuclear
            end
        end

        # Assign matching template
        # 赋予匹配的参数模板
        template = get(templates, fuel, templates[:default])
        frequency_parameters[name] = template
    end

    return frequency_parameters
end
