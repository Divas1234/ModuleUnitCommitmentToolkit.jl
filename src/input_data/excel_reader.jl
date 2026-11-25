using XLSX

function unit_commitment_data_file()
    default_path = normpath(joinpath(@__DIR__, "..", "..", "data", "data.xlsx"))
    return get(ENV, "MODULE_UC_DATA_FILE", default_path)
end

"""
`readxlssheet()`

Reads and parses raw system parameter and topology data from an external Excel file (`data.xlsx`).
By default the workbook is read from the current repository's `data/` directory.
Set `MODULE_UC_DATA_FILE` to run a different case without editing source code.

# Returns
A tuple containing matrices for generator frequency parameters, wind frequency parameters,
energy storage capabilities, generator static characteristics, generation costs, branch network parameters,
load curves, point loads, and data center requirements.
"""
function _read_excel_sheet(workbook, preferred::AbstractString, legacy::Union{Nothing, AbstractString} = nothing)
    sheets = XLSX.sheetnames(workbook)
    if preferred in sheets
        return workbook[preferred]
    elseif legacy !== nothing && legacy in sheets
        return workbook[legacy]
    end
    error("Required Excel sheet `$(preferred)` not found in workbook (available: $(sheets))")
end

function _read_sheet_matrix(sheet, last_col::AbstractString, ncols::Int)
    nrows = size(sheet[:], 1)
    nrows < 2 && return zeros(Float64, 0, ncols)
    return convert(Array{Float64, 2}, sheet[string("A2:", last_col, nrows)])
end

function readxlssheet(data_file::AbstractString = unit_commitment_data_file())
    println("Step-1: Pkgs and functions are loaded")
    resolved_file = String(data_file)
    isfile(resolved_file) || error("Input data workbook not found: $resolved_file")
    df = XLSX.readxlsx(resolved_file)

    # Part 1: Extract generation and wind frequency parameter matrices
    units_freq_param = _read_sheet_matrix(_read_excel_sheet(df, "units_frequencyparam"), "G", 7)
    winds_freq_param = _read_sheet_matrix(_read_excel_sheet(df, "winds_frequencyparam"), "F", 6)

    # Part 2: Extract energy storage system parameters
    storage_system_data = _read_sheet_matrix(_read_excel_sheet(df, "storage_system_data", "strogesystem_data"), "L", 12)

    # Part 3: Extract conventional unit, transmission network, and electrical load data
    gen_data = _read_sheet_matrix(_read_excel_sheet(df, "units_data"), "M", 13)
    gen_cost = _read_sheet_matrix(_read_excel_sheet(df, "units_cost"), "H", 8)
    line_data = _read_sheet_matrix(_read_excel_sheet(df, "branch_data"), "E", 5)
    load_curve = _read_sheet_matrix(_read_excel_sheet(df, "load_curve"), "B", 2)
    load_data = _read_sheet_matrix(_read_excel_sheet(df, "load_data"), "C", 3)
    data_center_data = _read_sheet_matrix(_read_excel_sheet(df, "data_centers", "data_centra"), "I", 9)

    return units_freq_param, winds_freq_param, storage_system_data, gen_data, gen_cost, line_data, load_curve, load_data, data_center_data
end

"""
`forminputdata(...)`

Structures and formalizes the raw matrix data parsed from the Excel sheets into algorithmic
system components (`unit`, `transmissionline`, `load`, `pss`, `data_centra`, etc.)
required for Security-Constrained Unit Commitment (SCUC) optimization.

# Returns
A consolidated tuple of physical component structs, optimization parameters, and topological dimensions
(e.g., number of buses `NB`, number of generators `NG`, number of lines `NL`, etc.).
"""
function forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, storage_data, data_center_data; horizon::Union{Nothing, Integer} = nothing)

    # Topological dimension mappings (DataGen,DataBranch,DataLoad,LoadCurve,GenCost = IEEE_RTS6())
    NL = Int64(size(DataBranch)[1])::Int64 # Number of Transmission Lines
    NG = Int64(size(DataGen)[1])::Int64    # Number of Generators
    ND = Int64(size(DataLoad)[1])::Int64   # Number of Loads
    NC = Int64(size(storage_data)[1])::Int64 # Number of Storage Units
    bus_candidates = Int64[]
    NL > 0 && append!(bus_candidates, Int64.(DataBranch[:, 2]), Int64.(DataBranch[:, 3]))
    NG > 0 && append!(bus_candidates, Int64.(DataGen[:, 2]))
    ND > 0 && append!(bus_candidates, Int64.(DataLoad[:, 2]))
    NC > 0 && append!(bus_candidates, Int64.(storage_data[:, 2]))
    size(data_center_data, 1) > 0 && append!(bus_candidates, Int64.(data_center_data[:, 2]))
    isempty(bus_candidates) && throw(ArgumentError("Input workbook defines no buses"))
    minimum(bus_candidates) >= 1 || throw(ArgumentError("Bus indices must be >= 1; got minimum $(minimum(bus_candidates))"))
    NB = Int64(maximum(bus_candidates))::Int64 # Number of Buses
    available_periods = Int64(size(LoadCurve, 1))
    NT = horizon === nothing ? Int64(24) : Int64(horizon)
    if NT <= 0 || NT > available_periods
        throw(ArgumentError("horizon must be between 1 and $(available_periods) for the loaded Excel LoadCurve; got $(NT)"))
    end

    # --- 1. Generator Parameters ---
    Gens_Index = convert(Array{Int64}, DataGen[:, 1])        # Generator ID
    Gens_LocateBus = convert(Array{Int64}, DataGen[:, 2])    # Bus location
    Gens_Pmax = DataGen[:, 3] / 100                          # Max active power (p.u.)
    Gens_Pmin = DataGen[:, 4] / 100                          # Min active power (p.u.)
    Gens_RD = DataGen[:, 5] / 100                            # Ramp-down limit (p.u./h)
    Gens_RU = DataGen[:, 6] / 100                            # Ramp-up limit (p.u./h)
    Gens_SD = DataGen[:, 7] / 100                            # Shutdown ramp limit (p.u.)
    Gens_SU = DataGen[:, 8] / 100                            # Startup ramp limit (p.u.)
    Gens_TU = DataGen[:, 9]                                  # Minimum up time (h)
    Gens_TD = DataGen[:, 10]                                 # Minimum down time (h)
    Gens_x0 = DataGen[:, 11]                                 # Initial status (1: on, 0: off)
    # Gens_x0 = ones(NG, 1)[:, 1]
    Gens_t0 = DataGen[:, 12]                                 # Initial hours online/offline
    Gens_p0 = DataGen[:, 13] / 100                           # Initial active power (p.u.)

    # --- 2. Generator Cost Parameters ---
    Gens_c = GenCost[:, 2]         # Constant cost coefficient ($)
    Gens_b = GenCost[:, 3] * 1e2   # Linear cost coefficient ($/MW)
    Gens_a = GenCost[:, 4] * 1e4   # Quadratic cost coefficient ($/MW^2)
    Gens_CD = GenCost[:, 5]        # Shutdown cost ($)
    Gens_CU = GenCost[:, 6]        # Hot startup cost ($)
    Gens_CU1 = GenCost[:, 7]       # Cold startup cost ($)
    Gens_Cold = GenCost[:, 8]      # Cold start time limit (h)

    # --- 3. Transmission Line Parameters ---
    Trans_index = convert(Array{Int64}, DataBranch[:, 1])    # Branch ID
    Trans_From = convert(Array{Int64}, DataBranch[:, 2])     # Sending bus ID
    Trans_To = convert(Array{Int64}, DataBranch[:, 3])       # Receiving bus ID
    Trans_x = DataBranch[:, 4]                               # Branch reactance (p.u.)
    Trans_Pmax = DataBranch[:, 5] / 100                      # Forward active power capacity (p.u.)
    Trans_Pmin = (-1) .* DataBranch[:, 5] / 100              # Reverse active power capacity (p.u.)
    # Trans_b    = zeros(NL, 1)
    # Trans_Ratio = ones(NL, 1)

    # --- 4. Load Parameters ---
    # Loads.Curve = LoadCurve
    Loads_Index = convert(Array{Int64}, DataLoad[:, 1])      # Load ID
    Loads_LocateBus = convert(Array{Int64}, DataLoad[:, 2])  # Bus location
    Loads_Percent = DataLoad[:, 3]                           # Load distribution percentage
    Loads_SumLoad = LoadCurve[:, 2] / 100                    # System total load curve (p.u.)
    Loads_PerLoad = zeros(ND, NT)                            # Individual nodal load distribution
    for i in 1:NT
        Loads_PerLoad[:, i] = Loads_SumLoad[i, 1] .* Loads_Percent[:, 1]
    end

    # --- 5. Frequency Regulation Parameters ---
    Hg = UnitsFreqParam[:, 2]      # Generator inertia constant (s)
    Dg = UnitsFreqParam[:, 3]      # Generator damping coefficient (p.u.)
    Kg = UnitsFreqParam[:, 4]      # Governor gain
    Fg = UnitsFreqParam[:, 5]      # Fraction of total power generated by the turbine
    Tg = UnitsFreqParam[:, 6]      # Governor time constant (s)
    Rg = UnitsFreqParam[:, 7]      # Governor speed regulation (droop) (p.u.)

    # --- 6. Energy Storage (PSS) Parameters ---
    Pss_index = convert(Array{Int64}, storage_data[:, 1])      # Storage ID
    Pss_locatebus = convert(Array{Int64}, storage_data[:, 2])  # Bus location
    Pss_q_max = storage_data[:, 3] / 100                       # Max State of Charge (SoC) limit (p.u.)
    Pss_q_min = storage_data[:, 4] / 100                       # Min State of Charge (SoC) limit (p.u.)
    Pss_p⁺ = storage_data[:, 5] / 100                          # Max charging power (p.u.)
    Pss_p⁻ = storage_data[:, 6] / 100                          # Max discharging power (p.u.)
    Pss_P₀ = storage_data[:, 7] / 100                          # Initial State of Charge (p.u.)
    Pss_γ⁺ = storage_data[:, 8] / 100                          # Maximum charging ramp rate
    Pss_γ⁻ = storage_data[:, 9] / 100                          # Maximum discharging ramp rate
    Pss_η⁺ = storage_data[:, 10]                               # Charging efficiency
    Pss_η⁻ = storage_data[:, 11]                               # Discharging efficiency
    Pss_δₛ = storage_data[:, 12]                               # Self-discharge coefficient

    # Re-normalized data and model configurations.
    config_param = config_from_env()

    # Initialize generator unit structure
    # Index/LocateBus: Generator ID and connected bus ID
    # Pmax/Pmin: Maximum and minimum active power limits
    # RU/RD: Ramp-up and ramp-down rate limits
    # SU/SD: Startup and shutdown ramp limits
    # TU/TD: Minimum up-time and minimum down-time requirements
    # x0/t0/p0: Initial on/off state, initial time online/offline, and initial power output
    # a/b/c: Fuel cost curve coefficients (quadratic, linear, constant terms)
    # CU/CU1/CD/Cold: Startup costs (intervals) and shutdown costs, cold start limits
    # Hg/Dg/Kg/Fg/Tg/Rg: Frequency regulation parameters (inertia, damping, gain, deadband, etc.)
    units = unit(
        Gens_Index, Gens_LocateBus, Gens_Pmax, Gens_Pmin,
        Gens_RU, Gens_RD, Gens_SU, Gens_SD, Gens_TU, Gens_TD, Gens_x0, Gens_t0, Gens_p0,
        Gens_a, Gens_b, Gens_c, Gens_CU, Gens_CU1, Gens_CD, Gens_Cold,
        Hg, Dg, Kg, Fg, Tg, Rg,
    )
    # lines = transmissionline(Trans_From, Trans_To, Trans_x, Trans_b, Trans_Pmax, Trans_Pmin)

    # Initialize transmission line structure
    # index: Branch/Line ID
    # From/To: Sending and receiving bus IDs
    # x: Branch reactance (p.u.)
    # Pmax/Pmin: Branch active power flow capacity limits
    lines = transmissionline(Trans_index, Trans_From, Trans_To, Trans_x, Trans_Pmax, Trans_Pmin)

    # Initialize energy storage/pumped-storage system (PSS) structure
    # index/locatebus: Storage ID and connected bus ID
    # q_max/q_min: Maximum and minimum energy storage capacity (State of Charge bounds)
    # p⁺/p⁻: Maximum charging and discharging power limits
    # P₀: Initial energy level
    # γ⁺/γ⁻: Charging and discharging ramp rates
    # η⁺/η⁻: Charging and discharging efficiency
    # δₛ: Self-discharge rate
    storages = pss(Pss_index, Pss_locatebus, Pss_q_max, Pss_q_min, Pss_p⁺, Pss_p⁻, Pss_P₀, Pss_γ⁺, Pss_γ⁻, Pss_η⁺, Pss_η⁻, Pss_δₛ)

    # Initialize electrical load distribution structure
    # Index/LocateBus: Load ID and connected bus ID
    # PerLoad: Time-series active power demand matrix (ND x NT)
    if size(Loads_PerLoad, 1) == ND
        if size(Loads_PerLoad, 2) == NT
            loads = load(Loads_Index, Loads_LocateBus, Loads_PerLoad)
        end
    end

    # Formulate Data Center (DC) parametric structures
    dc_index = convert(Array{Int64}, data_center_data[:, 1])
    dc_locatebus = convert(Array{Int64}, data_center_data[:, 2])
    dc_pmax = data_center_data[:, 3]
    dc_pmin = data_center_data[:, 4]
    dc_voltage_regulation = data_center_data[:, 5]
    dc_idle_power = data_center_data[:, 6]
    dc_sv_constant = data_center_data[:, 7]
    dc_λ = data_center_data[:, 8]
    dc_μ = data_center_data[:, 9]

    temp_computational_task_curves = ones(NT, 1) * 0.2
    dc_computational_power_tasks = temp_computational_task_curves

    ND2 = size(dc_index)[1]

    # Initialize Data Center (DC) structure
    # index/locatebus: Data center ID and connected bus
    # pmax/pmin: Maximum and minimum power consumption
    # voltage_regulation: Voltage regulation capability index
    # idle_power: Idle power consumption
    # sv_constant: Server power constant (reflecting PUE efficiency characteristics)
    # λ/μ: Task arrival rate and processing service rate parameters
    # computational_power_tasks: Time-series computational load task curve
    data_center_data = DataCenters(
        dc_index, dc_locatebus, dc_pmax, dc_pmin, dc_voltage_regulation, dc_idle_power, dc_sv_constant, dc_λ, dc_μ, dc_computational_power_tasks,
    )

    println("Step-2: imput data are loaded")

    return config_param, units, lines, loads, storages, NB, NG, NL, ND, NT, NC, ND2, data_center_data
end

"""Canonical BlueStyle alias for `readxlssheet` (标准命名入口: 读取 Excel 原始工作表)."""
const read_excel_sheets = readxlssheet

"""Canonical BlueStyle alias for `forminputdata` (标准命名入口: 格式化 UC 输入数据结构)."""
const format_uc_input_data = forminputdata
