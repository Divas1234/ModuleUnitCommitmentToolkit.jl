using XLSX

"""
`readxlssheet()`

Reads and parses raw system parameter and topology data from an external Excel file (`data.xlsx`).
Detects the OS automatically to set the correct local file path.

# Returns
A tuple containing matrices for generator frequency parameters, wind frequency parameters,
energy storage capabilities, generator static characteristics, generation costs, branch network parameters,
load curves, point loads, and data center requirements.
"""
function readxlssheet()
	println("Step-1: Pkgs and functions are loaded")
	filepath = pwd()
	# df = XLSX.readxlsx(filepath * "\\master-2\\case1\\data\\data.xlsx")
	if Sys.isapple()
		df = XLSX.readxlsx("/Users/yuanyiping/Documents/GitHub/module_unitcommitment/data/data.xlsx")
	elseif Sys.iswindows()
		df = XLSX.readxlsx(joinpath(pwd(), "data", "data.xlsx"))
	end

	# Part 1: Extract generation and wind frequency parameter matrices
	unitsfreqparam = df["units_frequencyparam"]
	windsfreqparam = df["winds_frequencyparam"]

	Sheet1_list = string("A2", ":", "G", string(size(unitsfreqparam[:], 1)))
	Sheet2_list = string("A2", ":", "F", string(size(windsfreqparam[:], 1)))

	unitsfreqparam = convert(Array{Float64, 2}, unitsfreqparam[Sheet1_list])
	windsfreqparam = convert(Array{Float64, 2}, windsfreqparam[Sheet2_list])

	# Part 2: Extract energy storage system parameters
	strogesystemdata = df["strogesystem_data"]
	Sheet3_list = string("A2", ":", "L", string(size(strogesystemdata[:], 1)))
	strogesystemdata = convert(Array{Float64, 2}, strogesystemdata[Sheet3_list])

	# Part 3: Extract conventional unit, transmission network, and electrical load data
	gendata = df["units_data"]
	Sheet4_list = string("A2", ":", "M", string(size(gendata[:], 1)))
	gendata = convert(Array{Float64, 2}, gendata[Sheet4_list])

	gencost = df["units_cost"]
	Sheet5_list = string("A2", ":", "H", string(size(gencost[:], 1)))
	gencost = convert(Array{Float64, 2}, gencost[Sheet5_list])

	linedata = df["branch_data"]
	Sheet6_list = string("A2", ":", "E", string(size(linedata[:], 1)))
	linedata = convert(Array{Float64, 2}, linedata[Sheet6_list])

	loadcurve = df["load_curve"]
	Sheet7_list = string("A2", ":", "B", string(size(loadcurve[:], 1)))
	loadcurve = convert(Array{Float64, 2}, loadcurve[Sheet7_list])

	loaddata = df["load_data"]
	Sheet8_list = string("A2", ":", "C", string(size(loaddata[:], 1)))
	loaddata = convert(Array{Float64, 2}, loaddata[Sheet8_list])

	data_cnetra_data = df["data_centra"]
	Sheet9_list = string("A2", ":", "I", string(size(data_cnetra_data[:], 1)))
	datacentra_data = convert(Array{Float64, 2}, data_cnetra_data[Sheet9_list])

	return unitsfreqparam, windsfreqparam, strogesystemdata, gendata, gencost, linedata, loadcurve, loaddata, datacentra_data
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
function forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

	# Topological dimension mappings (DataGen,DataBranch,DataLoad,LoadCurve,GenCost = IEEE_RTS6())
	NB = Int64(maximum([maximum(DataBranch[:, 2]), maximum(DataBranch[:, 3])]))::Int64 # Number of Buses
	NL = Int64(size(DataBranch)[1])::Int64 # Number of Transmission Lines
	NG = Int64(size(DataGen)[1])::Int64    # Number of Generators
	ND = Int64(size(DataLoad)[1])::Int64   # Number of Loads
	NC = Int64(size(StrogeData)[1])::Int64 # Number of Storage Units
	NT = 24::Int64                         # Number of Time periods (e.g., 24 hours)

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
	Pss_index = convert(Array{Int64}, StrogeData[:, 1])      # Storage ID
	Pss_locatebus = convert(Array{Int64}, StrogeData[:, 2])  # Bus location
	Pss_q_max = StrogeData[:, 3] / 100                       # Max State of Charge (SoC) limit (p.u.)
	Pss_q_min = StrogeData[:, 4] / 100                       # Min State of Charge (SoC) limit (p.u.)
	Pss_p⁺ = StrogeData[:, 5] / 100                          # Max charging power (p.u.)
	Pss_p⁻ = StrogeData[:, 6] / 100                          # Max discharging power (p.u.)
	Pss_P₀ = StrogeData[:, 7] / 100                          # Initial State of Charge (p.u.)
	Pss_γ⁺ = StrogeData[:, 8] / 100                          # Maximum charging ramp rate
	Pss_γ⁻ = StrogeData[:, 9] / 100                          # Maximum discharging ramp rate
	Pss_η⁺ = StrogeData[:, 10]                               # Charging efficiency
	Pss_η⁻ = StrogeData[:, 11]                               # Discharging efficiency
	Pss_δₛ = StrogeData[:, 12]                               # Self-discharge coefficient

	# Re-normalized data and algorithmic configurations
	config_param = config(1, 1, 1, 1, 1, 3, 0.005, 0.005, 1, 1, 1, 1e5, 1e5, 50, 0.01, 0, 0, 0, 1)

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
		Rg,
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
	stroges = pss(Pss_index, Pss_locatebus, Pss_q_max, Pss_q_min, Pss_p⁺, Pss_p⁻, Pss_P₀, Pss_γ⁺, Pss_γ⁻, Pss_η⁺, Pss_η⁻, Pss_δₛ)

	# Initialize electrical load distribution structure
	# Index/LocateBus: Load ID and connected bus ID
	# PerLoad: Time-series active power demand matrix (ND x NT)
	if size(Loads_PerLoad, 1) == ND
		if size(Loads_PerLoad, 2) == NT
			loads = load(Loads_Index, Loads_LocateBus, Loads_PerLoad)
		end
	end

	# Formulate Data Center (DC) parametric structures
	dc_index = convert(Array{Int64}, datacentra_Data[:, 1])
	dc_locatebus = convert(Array{Int64}, datacentra_Data[:, 2])
	dc_pmax = datacentra_Data[:, 3]
	dc_pmin = datacentra_Data[:, 4]
	dc_voltage_regulation = datacentra_Data[:, 5]
	dc_idale = datacentra_Data[:, 6]
	dc_sv_constent = datacentra_Data[:, 7]
	dc_λ = datacentra_Data[:, 8]
	dc_μ = datacentra_Data[:, 9]

	tem_computatioinal_task_curves = ones(NT, 1) * 0.2
	dc_computational_power_tasks = tem_computatioinal_task_curves

	ND2 = size(dc_index)[1]

	# Initialize Data Center (DC) structure
	# index/locatebus: Data center ID and connected bus
	# pmax/pmin: Maximum and minimum power consumption
	# voltage_regulation: Voltage regulation capability index
	# idale: Idle power consumption
	# sv_constent: Server power constant (reflecting PUE efficiency characteristics)
	# λ/μ: Task arrival rate and processing service rate parameters
	# computational_power_tasks: Time-series computational load task curve
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
		dc_computational_power_tasks,
	)

	println("Step-2: imput data are loaded")

	return config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, datacentra_data
end
