using PowerSystems
using CSV
using DataFrames
using Dates
using Statistics
using Distributions

const PSY = PowerSystems
const TS = PSY.TimeSeries

export read_powersystems_case

"""
    read_powersystems_case(case_dir::String; scenario_limit::Int64 = 50)

Constructs a `PowerSystems.System` from a standard Sienna CSV case directory
(expecting `user_descriptors.yaml` and optionally `generator_mapping.yaml`),
and then adapts it along with the project-specific CSV extensions.

# Returns
A 14-tuple of adapted structs and dimensions:
`(config_param, units, lines, loads, stroges, winds, NB, NG, NL, ND, NT, NC, ND2, datacentra_data)`
"""
function read_powersystems_case(case_dir::String; scenario_limit::Int64 = 50)
    user_desc_path = joinpath(case_dir, "user_descriptors.yaml")
    isfile(user_desc_path) || throw(ArgumentError("Missing required descriptor: user_descriptors.yaml in $case_dir"))

    gen_map_path = joinpath(case_dir, "generator_mapping.yaml")
    sys = if isfile(gen_map_path)
        System(PowerSystemTableData(case_dir, 100.0, user_desc_path; generator_mapping_file=gen_map_path))
    else
        System(PowerSystemTableData(case_dir, 100.0, user_desc_path))
    end

    return read_powersystems_case(sys, case_dir; scenario_limit = scenario_limit)
end

"""
    read_powersystems_case(sys::System, case_dir::String; scenario_limit::Int64 = 50)

Adapts a `PowerSystems.System` and project-specific CSV files inside `case_dir`
to the legacy unit commitment data structures.
"""
function read_powersystems_case(sys::System, case_dir::String; scenario_limit::Int64 = 50)
    sys_base_power = get_base_power(sys)
    config_param = config_from_env()

    # Helpers for column retrieval with aliases and case insensitivity
    function get_col_name(df::DataFrame, possible_names::Vector{String})
        cols = names(df)
        for name in possible_names
            if name in cols
                return name
            end
            for col in cols
                if lowercase(col) == lowercase(name)
                    return col
                end
            end
        end
        throw(ArgumentError("None of the required columns found: $possible_names in DataFrame with columns $cols"))
    end

    function has_column(df::DataFrame, possible_names::Vector{String})
        cols = names(df)
        for name in possible_names
            if name in cols
                return true
            end
            for col in cols
                if lowercase(col) == lowercase(name)
                    return true
                end
            end
        end
        return false
    end

    # --- 1. Map Thermal Generators ---
    gens = sort(collect(get_components(ThermalStandard, sys)), by=get_name)
    NG = length(gens)

    thermal_uc_path = joinpath(case_dir, "thermal_uc.csv")
    isfile(thermal_uc_path) || throw(ArgumentError("Missing required file: thermal_uc.csv"))
    df_uc = CSV.read(thermal_uc_path, DataFrame)

    uc_row_by_name = Dict{String, DataFrameRow}()
    for row in eachrow(df_uc)
        name = row[Symbol(get_col_name(df_uc, ["generator_name", "name", "gen_name"]))]
        if haskey(uc_row_by_name, name)
            throw(ArgumentError("Duplicate generator name in thermal_uc.csv: $name"))
        end
        uc_row_by_name[name] = row
    end

    # Validate joins
    for name in keys(uc_row_by_name)
        any(get_name(g) == name for g in gens) || throw(ArgumentError("Generator '$name' in thermal_uc.csv not found in PowerSystems ThermalStandard components"))
    end

    # Populate units struct arrays
    Gens_Index = collect(1:NG)
    Gens_LocateBus = [get_number(get_bus(g)) for g in gens]
    Gens_Pmax = Float64[]
    Gens_Pmin = Float64[]
    Gens_RU = Float64[]
    Gens_RD = Float64[]
    Gens_SU = Float64[]
    Gens_SD = Float64[]
    Gens_TU = Float64[]
    Gens_TD = Float64[]
    Gens_x0 = Float64[]
    Gens_t0 = Float64[]
    Gens_p0 = Float64[]
    Gens_a = Float64[]
    Gens_b = Float64[]
    Gens_c = Float64[]
    Gens_CU = Float64[]
    Gens_CU1 = Float64[]
    Gens_CD = Float64[]
    Gens_Cold = Float64[]

    for (i, g) in enumerate(gens)
        g_name = get_name(g)
        if !haskey(uc_row_by_name, g_name)
            throw(ArgumentError("Generator '$g_name' in PowerSystems not found in thermal_uc.csv"))
        end
        row = uc_row_by_name[g_name]

        p_lim = get_active_power_limits(g)
        push!(Gens_Pmax, p_lim.max / sys_base_power)
        push!(Gens_Pmin, p_lim.min / sys_base_power)

        push!(Gens_RU, row[Symbol(get_col_name(df_uc, ["ramp_up"]))] / sys_base_power)
        push!(Gens_RD, row[Symbol(get_col_name(df_uc, ["ramp_down"]))] / sys_base_power)
        push!(Gens_SU, row[Symbol(get_col_name(df_uc, ["startup_ramp", "shut_up"]))] / sys_base_power)
        push!(Gens_SD, row[Symbol(get_col_name(df_uc, ["shutdown_ramp", "shut_down"]))] / sys_base_power)

        push!(Gens_TU, Float64(row[Symbol(get_col_name(df_uc, ["min_uptime", "min_shutup_time"]))]))
        push!(Gens_TD, Float64(row[Symbol(get_col_name(df_uc, ["min_downtime", "min_shutdown_time"]))]))

        x0_val = Float64(row[Symbol(get_col_name(df_uc, ["initial_status", "x_0"]))])
        if x0_val != 0.0 && x0_val != 1.0
            throw(ArgumentError("Invalid initial status for $g_name: must be 0 or 1, got $x0_val"))
        end
        push!(Gens_x0, x0_val)
        push!(Gens_t0, Float64(row[Symbol(get_col_name(df_uc, ["initial_hours", "t_0"]))]))
        push!(Gens_p0, row[Symbol(get_col_name(df_uc, ["initial_power", "p_0"]))] / sys_base_power)

        push!(Gens_a, row[Symbol(get_col_name(df_uc, ["cost_a", "coffi_a"]))] * (sys_base_power^2))
        push!(Gens_b, row[Symbol(get_col_name(df_uc, ["cost_b", "coffi_b"]))] * sys_base_power)
        push!(Gens_c, row[Symbol(get_col_name(df_uc, ["cost_c", "coffi_c"]))])

        push!(Gens_CU, row[Symbol(get_col_name(df_uc, ["startup_cost_hot", "coffi_cold_shutup_1"]))])
        push!(Gens_CU1, row[Symbol(get_col_name(df_uc, ["startup_cost_cold", "coffi_cold_shutup_2"]))])
        push!(Gens_CD, row[Symbol(get_col_name(df_uc, ["shutdown_cost", "coffi_cold_shutdown_1"]))])
        push!(Gens_Cold, row[Symbol(get_col_name(df_uc, ["cold_start_time", "coffi_cold_shutdown_2"]))])
    end

    # Validations for Conventional Generators
    for i in 1:NG
        Gens_Pmax[i] >= Gens_Pmin[i] >= 0 || throw(ArgumentError("Invalid power limits for thermal generator index $i"))
        Gens_RU[i] >= 0 || throw(ArgumentError("Invalid ramp up limit for thermal generator index $i"))
        Gens_RD[i] >= 0 || throw(ArgumentError("Invalid ramp down limit for thermal generator index $i"))
        Gens_SU[i] >= 0 || throw(ArgumentError("Invalid startup ramp for thermal generator index $i"))
        Gens_SD[i] >= 0 || throw(ArgumentError("Invalid shutdown ramp for thermal generator index $i"))
        Gens_TU[i] >= 0 || throw(ArgumentError("Invalid min uptime for thermal generator index $i"))
        Gens_TD[i] >= 0 || throw(ArgumentError("Invalid min downtime for thermal generator index $i"))
        Gens_t0[i] >= 0 || throw(ArgumentError("Invalid initial hours for thermal generator index $i"))
        Gens_p0[i] >= 0 || throw(ArgumentError("Invalid initial power for thermal generator index $i"))
        Gens_a[i] >= 0 || throw(ArgumentError("Invalid quadratic cost for thermal generator index $i"))
        Gens_b[i] >= 0 || throw(ArgumentError("Invalid linear cost for thermal generator index $i"))
        Gens_c[i] >= 0 || throw(ArgumentError("Invalid constant cost for thermal generator index $i"))
        Gens_CU[i] >= 0 || throw(ArgumentError("Invalid hot startup cost for thermal generator index $i"))
        Gens_CU1[i] >= 0 || throw(ArgumentError("Invalid cold startup cost for thermal generator index $i"))
        Gens_CD[i] >= 0 || throw(ArgumentError("Invalid shutdown cost for thermal generator index $i"))
        Gens_Cold[i] >= 0 || throw(ArgumentError("Invalid cold start time limit for thermal generator index $i"))
    end

    # Load frequency parameters
    is_freq_con = (config_param.is_ConsiderFrequencyControl == 1)
    freq_path = joinpath(case_dir, "frequency_parameters.csv")

    if !isfile(freq_path)
        if is_freq_con
            throw(ArgumentError("Missing required file: frequency_parameters.csv because MODEL_CONSIDER_FREQUENCY_CONTROL is enabled"))
        else
            Hg = zeros(NG)
            Dg = zeros(NG)
            Kg = zeros(NG)
            Fg = zeros(NG)
            Tg = zeros(NG)
            Rg = zeros(NG)
        end
    else
        df_freq = CSV.read(freq_path, DataFrame)
        freq_row_by_name = Dict{String, DataFrameRow}()
        for row in eachrow(df_freq)
            name = row[Symbol(get_col_name(df_freq, ["device_name", "name"]))]
            if haskey(freq_row_by_name, name)
                throw(ArgumentError("Duplicate device name in frequency_parameters.csv: $name"))
            end
            freq_row_by_name[name] = row
        end

        Hg = zeros(NG)
        Dg = zeros(NG)
        Kg = zeros(NG)
        Fg = zeros(NG)
        Tg = zeros(NG)
        Rg = zeros(NG)

        for (i, g) in enumerate(gens)
            g_name = get_name(g)
            if !haskey(freq_row_by_name, g_name)
                throw(ArgumentError("Generator '$g_name' not found in frequency_parameters.csv"))
            end
            frow = freq_row_by_name[g_name]
            Hg[i] = frow[Symbol(get_col_name(df_freq, ["H", "Hg"]))]
            Dg[i] = frow[Symbol(get_col_name(df_freq, ["D", "Dg"]))]
            Kg[i] = frow[Symbol(get_col_name(df_freq, ["K", "Kg"]))]
            Fg[i] = frow[Symbol(get_col_name(df_freq, ["F", "Fg"]))]
            Tg[i] = frow[Symbol(get_col_name(df_freq, ["T", "Tg"]))]
            Rg[i] = frow[Symbol(get_col_name(df_freq, ["R", "Rg"]))]
        end

        # Validate frequency parameters
        for i in 1:NG
            Hg[i] >= 0 || throw(ArgumentError("Invalid Hg for generator index $i"))
            Dg[i] >= 0 || throw(ArgumentError("Invalid Dg for generator index $i"))
            Kg[i] >= 0 || throw(ArgumentError("Invalid Kg for generator index $i"))
            Fg[i] >= 0 || throw(ArgumentError("Invalid Fg for generator index $i"))
            Tg[i] >= 0 || throw(ArgumentError("Invalid Tg for generator index $i"))
            Rg[i] >= 0 || throw(ArgumentError("Invalid Rg for generator index $i"))
        end
    end

    units_struct = unit(
        Gens_Index, Gens_LocateBus, Gens_Pmax, Gens_Pmin, Gens_RU, Gens_RD, Gens_SU, Gens_SD,
        Gens_TU, Gens_TD, Gens_x0, Gens_t0, Gens_p0, Gens_a, Gens_b, Gens_c, Gens_CU, Gens_CU1,
        Gens_CD, Gens_Cold, Hg, Dg, Kg, Fg, Tg, Rg
    )

    # --- 2. Map Transmission Lines ---
    branches = sort(collect(get_components(Line, sys)), by=get_name)
    NL = length(branches)
    Trans_index = collect(1:NL)
    Trans_From = [get_number(get_from(get_arc(b))) for b in branches]
    Trans_To = [get_number(get_to(get_arc(b))) for b in branches]
    Trans_x = [get_x(b) for b in branches]
    Trans_Pmax = [get_rating(b) / sys_base_power for b in branches]
    Trans_Pmin = [-get_rating(b) / sys_base_power for b in branches]

    # Validate branch values
    for i in 1:NL
        Trans_Pmax[i] >= 0 || throw(ArgumentError("Invalid branch capacity for branch index $i"))
        Trans_x[i] > 0 || throw(ArgumentError("Branch reactance must be positive; branch index $i"))
    end

    lines_struct = transmissionline(Trans_index, Trans_From, Trans_To, Trans_x, Trans_Pmax, Trans_Pmin)

    # --- 3. Map Loads and Time Horizon NT ---
    loads_sys = sort(collect(get_components(PowerLoad, sys)), by=get_name)
    ND = length(loads_sys)
    Loads_Index = collect(1:ND)
    Loads_LocateBus = [get_number(get_bus(ld)) for ld in loads_sys]

    loads_curves_list = Vector{Vector{Float64}}()
    NT = 0
    for (i, ld) in enumerate(loads_sys)
        if !has_time_series(ld)
            throw(ArgumentError("Load $(get_name(ld)) does not have any time series"))
        end
        keys = get_time_series_keys(ld)
        found_key = nothing
        for k in keys
            name = get_name(k)
            if name in ["max_active_power", "active_power", "scaling_factor_active_power"]
                found_key = name
                break
            end
        end
        if found_key === nothing
            if !isempty(keys)
                found_key = get_name(first(keys))
            else
                throw(ArgumentError("Load $(get_name(ld)) has empty time series keys"))
            end
        end
        vals = get_time_series_values(SingleTimeSeries, ld, found_key)
        if i == 1
            NT = length(vals)
            if NT == 0
                throw(ArgumentError("Time series length for load $(get_name(ld)) is 0"))
            end
        else
            if length(vals) != NT
                throw(ArgumentError("Time series length mismatch for load $(get_name(ld)): got $(length(vals)), expected $NT"))
            end
        end
        max_ap = get_max_active_power(ld)
        push!(loads_curves_list, vals .* max_ap / sys_base_power)
    end

    Loads_PerLoad = zeros(ND, NT)
    for i in 1:ND
        Loads_PerLoad[i, :] = loads_curves_list[i]
    end
    loads_struct = load(Loads_Index, Loads_LocateBus, Loads_PerLoad)

    # --- 4. Map Storage (BESS / PSS) ---
    storages_sys = sort(collect(get_components(EnergyReservoirStorage, sys)), by=get_name)
    NC = length(storages_sys)
    storage_path = joinpath(case_dir, "storage_uc.csv")

    if NC == 0
        stroges_struct = pss(Int64[], Int64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[])
    else
        if !isfile(storage_path)
            if config_param.is_ConsiderBESS == 1
                throw(ArgumentError("Missing required file: storage_uc.csv because MODEL_CONSIDER_BESS is enabled"))
            else
                Pss_index = collect(1:NC)
                Pss_locatebus = [get_number(get_bus(s)) for s in storages_sys]
                Pss_q_max = [get_storage_capacity(s) / sys_base_power for s in storages_sys]
                Pss_q_min = [get_storage_level_limits(s).min / sys_base_power for s in storages_sys]
                Pss_p⁺ = [get_input_active_power_limits(s).max / sys_base_power for s in storages_sys]
                Pss_p⁻ = [get_output_active_power_limits(s).max / sys_base_power for s in storages_sys]
                Pss_P₀ = [get_initial_storage_capacity_level(s) / sys_base_power for s in storages_sys]
                Pss_γ⁺ = copy(Pss_p⁺)
                Pss_γ⁻ = copy(Pss_p⁻)
                Pss_η⁺ = [get_efficiency(s).in for s in storages_sys]
                Pss_η⁻ = [get_efficiency(s).out for s in storages_sys]
                Pss_δₛ = zeros(NC)
            end
        else
            df_storage = CSV.read(storage_path, DataFrame)
            storage_row_by_name = Dict{String, DataFrameRow}()
            for row in eachrow(df_storage)
                name = row[Symbol(get_col_name(df_storage, ["storage_name", "name"]))]
                if haskey(storage_row_by_name, name)
                    throw(ArgumentError("Duplicate storage name in storage_uc.csv: $name"))
                end
                storage_row_by_name[name] = row
            end

            for name in keys(storage_row_by_name)
                any(get_name(s) == name for s in storages_sys) || throw(ArgumentError("Storage '$name' in storage_uc.csv not found in PowerSystems EnergyReservoirStorage components"))
            end

            Pss_index = collect(1:NC)
            Pss_locatebus = [get_number(get_bus(s)) for s in storages_sys]
            Pss_q_max = Float64[]
            Pss_q_min = Float64[]
            Pss_p⁺ = Float64[]
            Pss_p⁻ = Float64[]
            Pss_P₀ = Float64[]
            Pss_γ⁺ = Float64[]
            Pss_γ⁻ = Float64[]
            Pss_η⁺ = Float64[]
            Pss_η⁻ = Float64[]
            Pss_δₛ = Float64[]

            for (i, s) in enumerate(storages_sys)
                s_name = get_name(s)
                if !haskey(storage_row_by_name, s_name)
                    throw(ArgumentError("Storage '$s_name' not found in storage_uc.csv"))
                end
                srow = storage_row_by_name[s_name]

                qmax = has_column(df_storage, ["q_max", "storage_capacity"]) ?
                       srow[Symbol(get_col_name(df_storage, ["q_max", "storage_capacity"]))] / sys_base_power :
                       get_storage_capacity(s) / sys_base_power
                push!(Pss_q_max, qmax)

                qmin = has_column(df_storage, ["q_min"]) ?
                       srow[Symbol(get_col_name(df_storage, ["q_min"]))] / sys_base_power :
                       get_storage_level_limits(s).min / sys_base_power
                push!(Pss_q_min, qmin)

                p_charge = has_column(df_storage, ["p_charge_max", "p⁺"]) ?
                           srow[Symbol(get_col_name(df_storage, ["p_charge_max", "p⁺"]))] / sys_base_power :
                           get_input_active_power_limits(s).max / sys_base_power
                push!(Pss_p⁺, p_charge)

                p_discharge = has_column(df_storage, ["p_discharge_max", "p⁻"]) ?
                              srow[Symbol(get_col_name(df_storage, ["p_discharge_max", "p⁻"]))] / sys_base_power :
                              get_output_active_power_limits(s).max / sys_base_power
                push!(Pss_p⁻, p_discharge)

                push!(Pss_P₀, srow[Symbol(get_col_name(df_storage, ["initial_soc", "P_0", "P₀"]))] / sys_base_power)
                push!(Pss_γ⁺, srow[Symbol(get_col_name(df_storage, ["charge_ramp", "γ⁺"]))] / sys_base_power)
                push!(Pss_γ⁻, srow[Symbol(get_col_name(df_storage, ["discharge_ramp", "γ⁻"]))] / sys_base_power)

                eta_plus = has_column(df_storage, ["charge_efficiency", "η⁺"]) ?
                           srow[Symbol(get_col_name(df_storage, ["charge_efficiency", "η⁺"]))] :
                           get_efficiency(s).in
                eta_minus = has_column(df_storage, ["discharge_efficiency", "η⁻"]) ?
                            srow[Symbol(get_col_name(df_storage, ["discharge_efficiency", "η⁻"]))] :
                            get_efficiency(s).out
                push!(Pss_η⁺, eta_plus)
                push!(Pss_η⁻, eta_minus)

                push!(Pss_δₛ, srow[Symbol(get_col_name(df_storage, ["self_discharge", "δₛ"]))])
            end
        end

        for i in 1:NC
            Pss_q_max[i] >= Pss_q_min[i] >= 0 || throw(ArgumentError("Invalid storage capacity limits for storage index $i"))
            Pss_p⁺[i] >= 0 || throw(ArgumentError("Invalid charging power limit for storage index $i"))
            Pss_p⁻[i] >= 0 || throw(ArgumentError("Invalid discharging power limit for storage index $i"))
            Pss_P₀[i] >= 0 || throw(ArgumentError("Invalid initial SoC for storage index $i"))
            Pss_γ⁺[i] >= 0 || throw(ArgumentError("Invalid charge ramp rate for storage index $i"))
            Pss_γ⁻[i] >= 0 || throw(ArgumentError("Invalid discharge ramp rate for storage index $i"))
            0 <= Pss_η⁺[i] <= 1 || throw(ArgumentError("Invalid charge efficiency for storage index $i"))
            0 <= Pss_η⁻[i] <= 1 || throw(ArgumentError("Invalid discharge efficiency for storage index $i"))
            0 <= Pss_δₛ[i] <= 1 || throw(ArgumentError("Invalid self-discharge rate for storage index $i"))
        end

        stroges_struct = pss(Pss_index, Pss_locatebus, Pss_q_max, Pss_q_min, Pss_p⁺, Pss_p⁻, Pss_P₀, Pss_γ⁺, Pss_γ⁻, Pss_η⁺, Pss_η⁻, Pss_δₛ)
    end

    # --- 5. Map Renewable Generators (Wind) ---
    renewables = sort(collect(get_components(RenewableGen, sys)), by=get_name)
    NW = length(renewables)
    ren_profile_path = joinpath(case_dir, "renewable_profiles.csv")

    if !isfile(ren_profile_path)
        if NW > 0
            throw(ArgumentError("Missing required file: renewable_profiles.csv because renewable components are present in PowerSystems"))
        else
            winds_struct = wind(Int64[], Int64[], Float64[], 1.0, 1, zeros(1, NT), Float64[], Float64[], Float64[], Float64[], Float64[], Float64[])
        end
    else
        df_ren = CSV.read(ren_profile_path, DataFrame)
        gen_col = Symbol(get_col_name(df_ren, ["generator_name", "name"]))
        time_col = Symbol(get_col_name(df_ren, ["time"]))
        val_col = Symbol(get_col_name(df_ren, ["value", "generation", "available_power", "avail"]))

        ren_by_name = Dict(get_name(r) => r for r in renewables)

        ren_profiles = Dict{String, Vector{Float64}}()
        for row in eachrow(df_ren)
            name = row[gen_col]
            t = row[time_col]
            val = row[val_col]

            haskey(ren_by_name, name) || throw(ArgumentError("Renewable generator '$name' in renewable_profiles.csv not found in PowerSystems RenewableGen components"))

            profile = get!(ren_profiles, name, zeros(NT))
            if t < 1 || t > NT
                throw(ArgumentError("Time index $t in renewable_profiles.csv out of bounds [1, $NT] for generator $name"))
            end
            if profile[t] != 0.0
                throw(ArgumentError("Duplicate entry for generator $name at time $t in renewable_profiles.csv"))
            end
            profile[t] = val
        end

        for r in renewables
            r_name = get_name(r)
            haskey(ren_profiles, r_name) || throw(ArgumentError("Renewable generator '$r_name' is missing from renewable_profiles.csv"))
        end

        Wind_index = collect(1:NW)
        Wind_locatebus = [get_number(get_bus(ren_by_name[name])) for name in get_name.(renewables)]
        Wind_pmax = [get_rating(r) / sys_base_power for r in renewables]

        cf_profiles = zeros(NW, NT)
        for (i, r) in enumerate(renewables)
            r_name = get_name(r)
            profile_mw = ren_profiles[r_name]
            rating_mw = get_rating(r)
            cf_profiles[i, :] = profile_mw ./ rating_mw
        end

        base_profile = mean(cf_profiles, dims=1)
        all(0 .<= base_profile .<= 1) || throw(ArgumentError("Calculated capacity factors must be in [0, 1]"))

        scenarios_curve = if scenario_limit > 1
            generate_weibull_wind_availability(base_profile, scenario_limit, NT)
        else
            base_profile
        end
        scenarios_nums = size(scenarios_curve, 1)
        scenarios_prob = 1.0 / scenarios_nums

        # Load wind frequency parameters
        Fcmode = zeros(NW)
        Kw = zeros(NW)
        Rw = zeros(NW)
        Mw = zeros(NW)
        Dw = zeros(NW)
        Tw = zeros(NW)

        if is_freq_con && isfile(freq_path)
            for (i, r) in enumerate(renewables)
                r_name = get_name(r)
                if !haskey(freq_row_by_name, r_name)
                    throw(ArgumentError("Renewable generator '$r_name' not found in frequency_parameters.csv"))
                end
                frow = freq_row_by_name[r_name]
                Fcmode[i] = frow[Symbol(get_col_name(df_freq, ["Fcmode", "H"]))]
                Kw[i] = frow[Symbol(get_col_name(df_freq, ["Kw", "K"]))]
                Rw[i] = frow[Symbol(get_col_name(df_freq, ["Rw", "R"]))]
                Mw[i] = frow[Symbol(get_col_name(df_freq, ["Mw", "M"]))]
                Dw[i] = frow[Symbol(get_col_name(df_freq, ["Dw", "D"]))]
                Tw[i] = frow[Symbol(get_col_name(df_freq, ["Tw", "T"]))]
            end
        end

        winds_struct = wind(Wind_index, Wind_locatebus, Wind_pmax, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw)
    end

    # --- 6. Map Data Centers ---
    dc_path = joinpath(case_dir, "data_centers.csv")
    dc_workload_path = joinpath(case_dir, "data_center_workloads.csv")

    if !isfile(dc_path)
        if config_param.is_ConsiderDataCentra == 1
            throw(ArgumentError("Missing required file: data_centers.csv because MODEL_CONSIDER_DATA_CENTER is enabled"))
        else
            datacentra_struct = data_centra(Int64[], Int64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], zeros(0, NT))
            ND2 = 0
        end
    else
        df_dc = CSV.read(dc_path, DataFrame)
        isfile(dc_workload_path) || throw(ArgumentError("Missing workload file: data_center_workloads.csv"))
        df_workload = CSV.read(dc_workload_path, DataFrame)

        ND2 = size(df_dc, 1)

        buses = get_components(ACBus, sys)
        bus_by_name = Dict(get_name(b) => get_number(b) for b in buses)

        dc_index = collect(1:ND2)
        dc_locatebus = zeros(Int64, ND2)

        for (i, row) in enumerate(eachrow(df_dc))
            bus_col_name = get_col_name(df_dc, ["bus_name", "bus_number", "locatebus"])
            bus_val = row[Symbol(bus_col_name)]
            if bus_val isa AbstractString
                if haskey(bus_by_name, bus_val)
                    dc_locatebus[i] = bus_by_name[bus_val]
                else
                    throw(ArgumentError("Bus name '$bus_val' for data center not found in PowerSystems buses"))
                end
            else
                dc_locatebus[i] = Int64(bus_val)
            end
        end

        dc_names_col = Symbol(get_col_name(df_dc, ["data_center_name", "name"]))
        dc_names = df_dc[!, dc_names_col]

        dc_pmax = df_dc[!, Symbol(get_col_name(df_dc, ["p_max"]))] / sys_base_power
        dc_pmin = df_dc[!, Symbol(get_col_name(df_dc, ["p_min"]))] / sys_base_power
        dc_voltage_regulation = df_dc[!, Symbol(get_col_name(df_dc, ["voltage_regulation"]))]
        dc_idale = df_dc[!, Symbol(get_col_name(df_dc, ["idale", "idle_power"]))] / sys_base_power
        dc_sv_constant = df_dc[!, Symbol(get_col_name(df_dc, ["sv_constant", "sv_constent"]))] / sys_base_power
        dc_λ = df_dc[!, Symbol(get_col_name(df_dc, ["λ", "lambda"]))]
        dc_μ = df_dc[!, Symbol(get_col_name(df_dc, ["μ", "mu"]))]

        wl_dc_col = Symbol(get_col_name(df_workload, ["data_center_name", "name"]))
        wl_time_col = Symbol(get_col_name(df_workload, ["time"]))
        wl_val_col = Symbol(get_col_name(df_workload, ["workload", "value"]))

        dc_workloads = Dict{String, Vector{Float64}}()
        for row in eachrow(df_workload)
            name = row[wl_dc_col]
            t = row[wl_time_col]
            val = row[wl_val_col]

            name in dc_names || throw(ArgumentError("Data center '$name' in workloads not found in data_centers.csv"))

            profile = get!(dc_workloads, name, zeros(NT))
            if t < 1 || t > NT
                throw(ArgumentError("Time index $t in data_center_workloads.csv out of bounds [1, $NT] for data center $name"))
            end
            if profile[t] != 0.0
                throw(ArgumentError("Duplicate entry for data center $name at time $t in workloads"))
            end
            profile[t] = val
        end

        for name in dc_names
            haskey(dc_workloads, name) || throw(ArgumentError("Data center '$name' is missing from workloads"))
        end

        dc_computational_power_tasks = zeros(ND2, NT)
        for i in 1:ND2
            dc_computational_power_tasks[i, :] = dc_workloads[dc_names[i]]
        end

        for i in 1:ND2
            dc_pmax[i] >= dc_pmin[i] >= 0 || throw(ArgumentError("Invalid power limits for data center index $i"))
            dc_idale[i] >= 0 || throw(ArgumentError("Invalid idle power for data center index $i"))
            dc_sv_constant[i] >= 0 || throw(ArgumentError("Invalid server constant for data center index $i"))
            dc_λ[i] >= 0 || throw(ArgumentError("Invalid task arrival rate for data center index $i"))
            dc_μ[i] >= 0 || throw(ArgumentError("Invalid service rate for data center index $i"))
        end

        datacentra_struct = data_centra(
            dc_index, dc_locatebus, dc_pmax, dc_pmin, dc_voltage_regulation,
            dc_idale, dc_sv_constant, dc_λ, dc_μ, dc_computational_power_tasks
        )
    end

    NB = maximum(get_number(b) for b in get_components(ACBus, sys))

    return config_param, units_struct, lines_struct, loads_struct, stroges_struct, winds_struct, NB, NG, NL, ND, NT, NC, ND2, datacentra_struct
end
