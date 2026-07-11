# ============================================================================
# PowerSystems.jl Bridge for Unit Commitment Model
#
# This module provides functions to:
# 1. Load power system cases natively via PowerSystems.jl / PowerSystemCaseBuilder.jl
# 2. Extract and format grid and generator parameters for the UC model
# 3. Inject dynamic frequency parameters and mount data centers dynamically
# ============================================================================

using PowerSystems
using PowerSystemCaseBuilder
using DataFrames
using Random
using Distributions

export build_system_from_powersystems, extract_uc_data_from_powersystems, generate_wind_scenarios_from_system

"""
    build_system_from_powersystems(case_name::String)

Build a PowerSystems.jl `System` object either from a predefined test case name
(e.g., "c_sys5", "c_sys14") or a MATPOWER file path.
"""
function build_system_from_powersystems(case_name::String)
    println("Loading PowerSystems case: $case_name")
    
    # Check if case_name is a MATPOWER/JSON file on disk
    if isfile(case_name)
        return System(case_name)
    end
    
    # Try building from Sienna/NREL standard test cases
    try
        # Attempt loading using CaseBuilder
        return build_system(PSITestSystems, case_name)
    catch e
        # Try finding standard system builder case
        try
            return build_system(case_name)
        catch e2
            error("Failed to build system from '$case_name'. Please check case name or file path. Details: $e2")
        end
    end
end

"""
    get_ts_values_fallback(component, name::String, NT::Int)

Helper function to extract time series values with fallback to static attributes.
"""
function get_ts_values_fallback(component, name::String, NT::Int)
    for label in [name, "max_active_power", "active_power"]
        try
            vals = get_time_series_values(SingleTimeSeries, component, label)
            vector_vals = collect(vals)
            if length(vector_vals) >= NT
                return Float64.(vector_vals[1:NT])
            else
                res = Float64.(vector_vals)
                while length(res) < NT
                    push!(res, isempty(res) ? 1.0 : res[end])
                end
                return res
            end
        catch
            continue
        end
    end
    
    # Static property fallbacks
    val = 1.0
    try
        if hasproperty(component, :active_power)
            val = component.active_power
        elseif hasproperty(component, :active_power_limits)
            val = component.active_power_limits.max
        elseif hasproperty(component, :rating)
            val = component.rating
        end
    catch
        val = 1.0
    end
    return fill(Float64(val), NT)
end

"""
    extract_cost_coefficients(gen)

Robust helper to extract quadratic (a, b, c) cost coefficients from a generator's operational cost.
"""
function extract_cost_coefficients(gen)
    a, b, c = 0.0, 10.0, 50.0  # Safe defaults
    try
        op_cost = gen.operation_cost
        
        # Fixed cost (constant c)
        if hasproperty(op_cost, :fixed)
            c = Float64(op_cost.fixed)
        end
        
        # Variable cost (a and b)
        if hasproperty(op_cost, :variable)
            var_cost = op_cost.variable
            if hasproperty(var_cost, :value_curve)
                curve = var_cost.value_curve
                if hasproperty(curve, :function_data)
                    data = curve.function_data
                    if hasproperty(data, :proportional_term)
                        b = Float64(data.proportional_term)
                    end
                    if hasproperty(data, :constant_term)
                        c += Float64(data.constant_term)
                    end
                    if hasproperty(data, :quadratic_term)
                        a = Float64(data.quadratic_term)
                    end
                end
            end
        end
    catch
        # Fall back silently to default values
    end
    return a, b, c
end

"""
    get_branch_rate(branch)

Retrieve line rating with fallbacks.
"""
function get_branch_rate(branch)
    rate = 1000.0
    try
        if hasproperty(branch, :rating)
            rate = Float64(branch.rating)
        elseif hasproperty(branch, :rate)
            rate = Float64(branch.rate)
        end
    catch
    end
    return rate
end

"""
    get_branch_reactance(branch)

Retrieve line reactance with fallbacks.
"""
function get_branch_reactance(branch)
    x = 0.1
    try
        if hasproperty(branch, :x)
            x = Float64(branch.x)
        end
    catch
    end
    return x
end

"""
    extract_uc_data_from_powersystems(sys::System;
                                     data_center_buses::Vector{Int} = Int[],
                                     data_center_pmax::Vector{Float64} = Float64[],
                                     frequency_params_override = nothing)

Extract and format variables from a PowerSystems `System` to feed into our
Stochastic Unit Commitment optimization model.
Also mounts data centers on designated buses and configures grid frequency parameters.
"""
function extract_uc_data_from_powersystems(sys::System;
                                         data_center_buses::Vector{Int} = Int[],
                                         data_center_pmax::Vector{Float64} = Float64[],
                                         frequency_params_override = nothing)
    
    # ---------------- Setup Time Horizon ----------------
    NT = 24  # Default hourly scheduling horizon
    
    # ---------------- Buses ----------------
    buses = collect(get_components(Bus, sys))
    NB = length(buses)
    
    # Create mapping of bus number to 1-based index
    bus_to_idx = Dict{Int, Int}()
    bus_numbers = [b.number for b in buses]
    # Sort them to keep consistent bus mapping
    sorted_bus_numbers = sort(bus_numbers)
    for (idx, bnum) in enumerate(sorted_bus_numbers)
        bus_to_idx[bnum] = idx
    end
    
    # Helper to map a bus object or bus number to contiguous index
    get_bus_idx(bus_num::Int) = get(bus_to_idx, bus_num, 1)
    get_bus_idx(b::Bus) = get_bus_idx(b.number)
    
    # ---------------- Thermal Generators ----------------
    thermal_gens = collect(get_components(ThermalStandard, sys))
    NG = length(thermal_gens)
    
    # Heuristic: Detect if system is already in per-unit (e.g. max capacity < 50.0)
    is_pu = false
    if NG > 0
        max_cap = maximum(g.active_power_limits.max for g in thermal_gens)
        if max_cap < 50.0
            is_pu = true
            println("Detected system data is already in per-unit (p.u.). No un-scaling applied.")
        else
            println("Detected system data is in MW/natural units. Scaling factor of 0.01 (per-100-MW base) applied.")
        end
    end
    scale_factor = is_pu ? 1.0 : 0.01
    
    # Allocate fields for thermal generator structure
    Gens_Index = collect(1:NG)
    Gens_LocateBus = [get_bus_idx(g.bus) for g in thermal_gens]
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
    Gens_t1 = Float64[]
    Gens_p0 = Float64[]
    
    Gens_a = Float64[]
    Gens_b = Float64[]
    Gens_c = Float64[]
    Gens_CD = Float64[]
    Gens_CU = Float64[]
    Gens_CU1 = Float64[]
    Gens_Cold = Float64[]
    
    # Set default/override frequency parameters
    # Hg, Dg, Kg, Fg, Tg, Rg
    Hg = Float64[]
    Dg = Float64[]
    Kg = Float64[]
    Fg = Float64[]
    Tg = Float64[]
    Rg = Float64[]
    
    for (i, g) in enumerate(thermal_gens)
        # Power limits (scaled by scale_factor)
        lims = g.active_power_limits
        pmax_val = lims.max * scale_factor
        pmin_val = lims.min * scale_factor
        push!(Gens_Pmax, pmax_val)
        push!(Gens_Pmin, pmin_val)
        
        # Ramps
        ramps = g.ramp_limits
        ru_val = (ramps !== nothing ? ramps.up : pmax_val * 10) * scale_factor
        rd_val = (ramps !== nothing ? ramps.down : pmax_val * 10) * scale_factor
        push!(Gens_RU, ru_val)
        push!(Gens_RD, rd_val)
        
        # Startup and Shutdown costs
        su_cost = 0.0
        sd_cost = 0.0
        try
            su_cost = Float64(g.operation_cost.start_up)
            sd_cost = Float64(g.operation_cost.shut_down)
        catch
        end
        push!(Gens_SU, su_cost)
        push!(Gens_SD, sd_cost)
        
        # Time limits
        t_lims = g.time_limits
        push!(Gens_TU, t_lims !== nothing ? Float64(t_lims.up) : 1.0)
        push!(Gens_TD, t_lims !== nothing ? Float64(t_lims.down) : 1.0)
        
        # Initial conditions
        push!(Gens_x0, 1.0) # start initially online
        push!(Gens_t0, 1.0)
        push!(Gens_t1, 0.0)
        push!(Gens_p0, pmin_val)
        
        # Cost coefficients
        a_coef, b_coef, c_coef = extract_cost_coefficients(g)
        # Note downstream UC model scales linear by 1e2 and quadratic by 1e4
        # If in p.u., we must adjust to fit the model's expected scaling structure
        if is_pu
            # If system is already in per-unit, the cost coefficients in Sienna
            # are typically written for 1 p.u. base.
            push!(Gens_a, a_coef / 1e4)
            push!(Gens_b, b_coef / 1e2)
        else
            push!(Gens_a, a_coef / 1e4)
            push!(Gens_b, b_coef / 1e2)
        end
        push!(Gens_c, c_coef)
        push!(Gens_CD, sd_cost)
        push!(Gens_CU, su_cost)
        push!(Gens_CU1, su_cost)
        push!(Gens_Cold, su_cost)
        
        # Frequency parameters injection (Hg, Dg, Kg, Fg, Tg, Rg)
        if frequency_params_override !== nothing && i <= size(frequency_params_override, 1)
            push!(Hg, frequency_params_override[i, 2])
            push!(Dg, frequency_params_override[i, 3])
            push!(Kg, frequency_params_override[i, 4])
            push!(Fg, frequency_params_override[i, 5])
            push!(Tg, frequency_params_override[i, 6])
            push!(Rg, frequency_params_override[i, 7])
        else
            # Default typical frequency parameters
            push!(Hg, 8.0)
            push!(Dg, 4.0)
            push!(Kg, 0.35)
            push!(Fg, 0.35)
            push!(Tg, 0.25)
            push!(Rg, 1.0 / 0.03)  # Droop
        end
    end
    
    # ---------------- Transmission Lines ----------------
    branches = collect(get_components(Branch, sys))
    NL = length(branches)
    Trans_index = collect(1:NL)
    Trans_From = [get_bus_idx(get_from(get_arc(b))) for b in branches]
    Trans_To = [get_bus_idx(get_to(get_arc(b))) for b in branches]
    Trans_x = [get_branch_reactance(b) for b in branches]
    Trans_Pmax = [get_branch_rate(b) * scale_factor for b in branches]
    Trans_Pmin = (-1) .* Trans_Pmax
    
    # ---------------- Load curves ----------------
    power_loads = collect(get_components(PowerLoad, sys))
    ND = length(power_loads)
    Loads_Index = collect(1:ND)
    Loads_LocateBus = [get_bus_idx(l.bus) for l in power_loads]
    
    # Calculate load disaggregation. We get time series profile for each load.
    Loads_PerLoad = zeros(ND, NT)
    for (i, load_comp) in enumerate(power_loads)
        Loads_PerLoad[i, :] = get_ts_values_fallback(load_comp, "max_active_power", NT) .* scale_factor
    end
    
    # ---------------- Wind / Renewable Configuration ----------------
    renewables = collect(get_components(RenewableDispatch, sys))
    NW = length(renewables)
    if NW == 0
        NW = 1
        WindsFreqParam = reshape([0.0, 0.05, 10.0, 0.0, 0.0, 0.25], 1, 6)
    else
        WindsFreqParam = zeros(NW, 6)
        for i in 1:NW
            WindsFreqParam[i, :] = [0.0, 0.05, 10.0, 0.0, 0.0, 0.25]
        end
    end
    
    # ---------------- Storage (BESS) ----------------
    storage_comps = collect(get_components(Storage, sys))
    NC = length(storage_comps)
    # Create matching storage data
    StrogeData = zeros(NC, 12)
    for i in 1:NC
        s = storage_comps[i]
        StrogeData[i, 1] = i
        StrogeData[i, 2] = get_bus_idx(s.bus)
        StrogeData[i, 3] = s.rating * scale_factor # Q_max
        StrogeData[i, 4] = 0.0 # Q_min
        StrogeData[i, 5] = s.active_power_limits.max * scale_factor # p+
        StrogeData[i, 6] = s.active_power_limits.max * scale_factor # p-
        StrogeData[i, 7] = s.rating * scale_factor * 0.5 # P0
        StrogeData[i, 8] = 0.01 # charging cost
        StrogeData[i, 9] = 0.01 # discharging cost
        StrogeData[i, 10] = 0.95 # efficiency +
        StrogeData[i, 11] = 0.95 # efficiency -
        StrogeData[i, 12] = 0.001 # self discharge
    end
    
    # ---------------- Data Center Mounting ----------------
    ND2 = length(data_center_buses)
    Datacentra_Data = zeros(ND2, 9)
    for i in 1:ND2
        bus_idx = get_bus_idx(data_center_buses[i])
        pmax = data_center_pmax[i]
        # Columns: [index, locatebus, pmax, pmin, voltage_regulation, idale, sv_constant, λ, μ]
        Datacentra_Data[i, 1] = i
        Datacentra_Data[i, 2] = bus_idx
        Datacentra_Data[i, 3] = pmax  # pmax (already expected in per-unit of the system)
        Datacentra_Data[i, 4] = pmax * 0.2  # pmin
        Datacentra_Data[i, 5] = 0.05  # voltage regulation capability
        Datacentra_Data[i, 6] = pmax * 0.1  # idle power consumption
        Datacentra_Data[i, 7] = 2.0  # service constant
        Datacentra_Data[i, 8] = 0.5  # lambda dual
        Datacentra_Data[i, 9] = 1.0  # mu dual
    end
    
    # ---------------- Hydropower ----------------
    hydros_comps = collect(get_components(HydroDispatch, sys))
    NH = length(hydros_comps)
    HydroData = zeros(NH, 6)
    HydroCurve = zeros(NT, 2)
    for i in 1:NH
        hc = hydros_comps[i]
        HydroData[i, 1] = i
        HydroData[i, 2] = get_bus_idx(hc.bus)
        HydroData[i, 3] = hc.active_power_limits.max * scale_factor
        HydroData[i, 4] = hc.active_power_limits.min * scale_factor
        HydroData[i, 5] = 10.0 * scale_factor # qmax
        HydroData[i, 6] = 5.0 * scale_factor # q0
    end
    HydroCurve[:, 1] = collect(1:NT)
    HydroCurve[:, 2] .= 1.0 # reservoir level seasonal curve
    
    # ---------------- Packaging composite types ----------------
    # Instantiating custom structs for the UC model
    
    # Config parameters setup (enable datacenter, frequency control, BESS if present)
    config_param = config(
        1, # is_NetWorkCon
        1, # is_ThermalUnitCon
        NW > 0 ? 1 : 0, # is_WindUnitCon
        NH > 0 ? 1 : 0, # is_HydroUnitCon
        1, # is_SysticalCon
        1, # is_PieceLinear
        3, # is_NumSeg
        0.005, # is_Alpha
        0.005, # is_Belta
        1, # is_CoalPrice
        1, # is_ActiveLoad
        NW > 0 ? 1 : 0, # is_WindIntegration
        1e-5, # is_LoadsCuttingCoefficient
        1e-5, # is_WindsCuttingCoefficient
        50, # is_MaxIterationsNum
        0.01, # is_CalculPrecision
        1e5, # Reserved17
        1e5, # Reserved18
        50, # Reserved19
        0.01, # Reserved20
        1, # Reserved21
        2, # Reserved22
        ND2 > 0 ? 1 : 0, # is_ConsiderDataCentra
        1, # is_ConsiderFrequencyControl
        NC > 0 ? 1 : 0, # is_ConsiderBESS
        1, # is_ConsiderMultiCUTs
        1  # is_SchedulingObjFuncType
    )
    
    units = unit(
        Gens_Index,
        Gens_LocateBus,
        Gens_Pmax,
        Gens_Pmin,
        Gens_RU,
        Gens_RD,
        Gens_SU,
        Gens_SD,
        Gens_TU,
        Gens_TD,
        Gens_x0,
        Gens_t0,
        Gens_t1,
        Gens_p0,
        Gens_a,
        Gens_b,
        Gens_c,
        Gens_CU,
        Gens_CU1,
        Gens_CD,
        Gens_Cold,
        Hg,
        Dg,
        Kg,
        Fg,
        Tg,
        Rg
    )
    
    lines = transmissionline(Trans_index, Trans_From, Trans_To, Trans_x, Trans_Pmax, Trans_Pmin)
    
    stroges = pss(
        convert(Array{Int64}, StrogeData[:, 1]),
        convert(Array{Int64}, StrogeData[:, 2]),
        StrogeData[:, 3],
        StrogeData[:, 4],
        StrogeData[:, 5],
        StrogeData[:, 6],
        StrogeData[:, 7],
        StrogeData[:, 8],
        StrogeData[:, 9],
        StrogeData[:, 10],
        StrogeData[:, 11],
        StrogeData[:, 12]
    )
    
    loads = load(Loads_Index, Loads_LocateBus, Loads_PerLoad)
    
    # Datacenter dataset instantiation
    if ND2 > 0
        dc_index = convert(Array{Int64}, Datacentra_Data[:, 1])
        dc_locatebus = convert(Array{Int64}, Datacentra_Data[:, 2])
        dc_pmax = Datacentra_Data[:, 3]
        dc_pmin = Datacentra_Data[:, 4]
        dc_voltage_regulation = Datacentra_Data[:, 5]
        dc_idale = Datacentra_Data[:, 6]
        dc_sv_constent = Datacentra_Data[:, 7]
        dc_λ = Datacentra_Data[:, 8]
        dc_μ = Datacentra_Data[:, 9]
        dc_computational_power_tasks = ones(NT, 1) * 0.2
        
        datacentra_data = data_centra(
            dc_index,
            dc_locatebus,
            dc_pmax,
            dc_pmin,
            dc_voltage_regulation,
            dc_idale,
            dc_sv_constent,
            dc_λ,
            dc_μ,
            dc_computational_power_tasks
        )
    else
        datacentra_data = data_centra(Int64[], Int64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], zeros(NT, 0))
    end
    
    # Hydro
    if NH > 0
        hydros = hydro(
            convert(Array{Int64}, HydroData[:, 1]),
            convert(Array{Int64}, HydroData[:, 2]),
            HydroData[:, 3],
            HydroData[:, 4],
            HydroData[:, 5],
            HydroData[:, 6],
            HydroCurve[:, 2]
        )
    else
        hydros = hydro(Int64[], Int64[], Float64[], Float64[], Float64[], Float64[], Float64[])
    end
    
    println("Successfully extracted UC data from PowerSystems System.")
    return config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, datacentra_data, hydros, WindsFreqParam, bus_to_idx
end

"""
    generate_wind_scenarios_from_system(sys::System, WindsFreqParam::Matrix{Float64}, flag::Int, NT::Int = 24; bus_to_idx::Dict{Int, Int} = Dict{Int, Int}())

Generate wind scenarios using Weibull distribution based on wind components present in the PowerSystems System.
"""
function generate_wind_scenarios_from_system(sys::System, WindsFreqParam::Matrix{Float64}, flag::Int, NT::Int = 24; bus_to_idx::Dict{Int, Int} = Dict{Int, Int}())
    renewables = collect(get_components(RenewableDispatch, sys))
    NW = length(renewables)
    
    # Heuristic: check scaling multiplier
    is_pu = false
    thermal_gens = collect(get_components(ThermalStandard, sys))
    if !isempty(thermal_gens)
        max_cap = maximum(g.active_power_limits.max for g in thermal_gens)
        if max_cap < 50.0
            is_pu = true
        end
    end
    scale_factor = is_pu ? 1.0 : 0.01
    
    # Extract locations and capacities
    if NW == 0
        # Dummy wind farm fallback
        index = [1]
        locatebus = [1]
        p_max = [0.0]
        NW = 1
    else
        index = Int64[]
        locatebus = Int64[]
        p_max = Float64[]
        for r in renewables
            bnum = r.bus.number
            bidx = get(bus_to_idx, bnum, 1)
            push!(index, bidx)
            push!(locatebus, bidx)
            push!(p_max, r.active_power_limits.max * scale_factor)
        end
    end
    
    # Generate curves
    if flag == 1
        scenarios_curvebase = [
            0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300
            0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042
            0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410
            0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982
        ] * 1.0
        scenarios_curvebase = reshape(scenarios_curvebase, 1, NT)
        
        Random.seed!(123)
        scenarios_nums = 3
        
        sample_sets = rand(Weibull(), scenarios_nums * NT) * 0.01
        scenarios_curve = reshape(sample_sets, scenarios_nums, NT)
        scenarios_error = reshape(sample_sets, scenarios_nums, NT)
        
        for i in 1:scenarios_nums
            for j in 1:NT
                sample_temp = rand()
                if sample_temp > 0.5
                    scenarios_curve[i, j] = scenarios_curvebase[1, j] + scenarios_error[i, j]
                else
                    scenarios_curve[i, j] = scenarios_curvebase[1, j] - scenarios_error[i, j]
                end
            end
        end
    else
        scenarios_nums = 7
        scenarios_curve = [
            0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300 0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042 0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410 0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982
            0.438145251438362 0.451595831499290 0.434476599311993 0.419306858427854 0.439299123016117 0.402675152643531 0.436348294887821 0.447513027575036 0.445276832579360 0.408448500875771 0.476106019486472 0.451932867123187 0.446968204950444 0.457706023689642 0.454429491703142 0.432489551344388 0.460269791720502 0.417994780067730 0.404420416693225 0.443013967794901 0.407382847053778 0.430503777173583 0.455183618944849 0.443789093804304
            0.441672518788126 0.461922845597782 0.425338820890952 0.420366090471607 0.411612893296905 0.435840069094316 0.443930499695973 0.457511112047526 0.450817300160177 0.396413160907573 0.441068179613219 0.432401166117165 0.420639320150678 0.443835529493502 0.433537192471826 0.427399090347307 0.417573417186437 0.422905158624658 0.467119379846108 0.500219495833784 0.432716758754643 0.422622895486611 0.452734491278974 0.425638923917095
            0.404454468849607 0.427898443023513 0.456678201304931 0.466227716201764 0.458275535897303 0.447722201714402 0.430408791524416 0.457075404497126 0.422560643262941 0.479016292670867 0.440735317418680 0.426724520859767 0.438876736399005 0.427232619437777 0.431855284702541 0.436026678964276 0.463231975065251 0.449494208561186 0.440539555865053 0.430643201150598 0.463252275085078 0.426482114000725 0.450319628567473 0.447144352980500
            0.475002833720225 0.437617623292143 0.434471584469213 0.439971226562153 0.454329370050504 0.436312054145452 0.445440779281991 0.463144009687827 0.433153030072578 0.484931467718911 0.413222836444571 0.443268354334839 0.459751329710262 0.449325345517610 0.451073618934457 0.440806883197305 0.432345533655294 0.461416346612016 0.458566667364229 0.391262069079400 0.459153578592304 0.463514158218735 0.416622458118542 0.457798005720119
            0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300 0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042 0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410 0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982
            0.438145251438362 0.451595831499290 0.434476599311993 0.419306858427854 0.439299123016117 0.402675152643531 0.436348294887821 0.447513027575036 0.445276832579360 0.408448500875771 0.476106019486472 0.451932867123187 0.446968204950444 0.457706023689642 0.454429491703142 0.432489551344388 0.460269791720502 0.417994780067730 0.404420416693225 0.443013967794901 0.407382847053778 0.430503777173583 0.455183618944849 0.443789093804304
        ]
        scenarios_curve = vec(scenarios_curve')'
    end
    
    scenarios_prob = 1.0 / scenarios_nums
    
    if !isempty(WindsFreqParam)
        FCmode = WindsFreqParam[:, 1]
        KW = WindsFreqParam[:, 2]
        RW = WindsFreqParam[:, 3]
        MW = WindsFreqParam[:, 4]
        DW = WindsFreqParam[:, 5]
        TW = WindsFreqParam[:, 6]
    else
        FCmode = zeros(NW)
        KW = zeros(NW)
        RW = zeros(NW)
        MW = zeros(NW)
        DW = zeros(NW)
        TW = zeros(NW)
    end
    
    scenarios_nums = size(scenarios_curve, 1)
    
    winds = wind(
        index,
        locatebus,
        p_max,
        scenarios_prob,
        scenarios_nums,
        scenarios_curve,
        FCmode,
        KW,
        RW,
        MW,
        DW,
        TW
    )
    
    return winds, NW
end
