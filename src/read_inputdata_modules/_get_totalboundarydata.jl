
"""
	forminputdata(
		DataGen,
		DataBranch,
		DataLoad,
		LoadCurve,
		GenCost,
		UnitsFreqParam,
		StrogeData,
		datacentra_Data,
		HydroData,
		HydroCurve
	) -> (config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, datacentra_data, hydros)

Constructs and returns all structured input data required for the unit commitment and
co-optimization model. It parses raw matrices describing generators, transmission
branches, loads, storage units, data centers and hydropower plants, converts them
to strongly typed / scaled arrays, and wraps them using the model's constructor
functions (unit, transmissionline, load, pss, data_centra, hydro, config).

Inputs are expected to be numeric matrices where columns follow predefined schema:
DataGen: [index, bus, Pmax(MW), Pmin(MW), RD, RU, SD, SU, TU, TD, x0, t0, p0(MW), t1]
GenCost: [index, c, b(€/MW), a(€/MW^2), CD, CU, CU1, Cold]
DataBranch: [index, from, to, reactance, Pmax(MW)]
DataLoad: [index, bus, share] ; LoadCurve: [:, total system load(MW)]
UnitsFreqParam: [index, Hg, Dg, Kg, Fg, Tg, Rg]
StrogeData: [index, bus, q_max, q_min, p_plus, p_minus, P0, gamma_plus, gamma_minus, eta_plus, eta_minus, delta_s]
datacentra_Data: [index, bus, pmax, pmin, volt_reg, idle, sv_const, lambda, mu]
HydroData: [index, bus, pmax, pmin, qmax, q0]; HydroCurve: [:, reservoir level]

All power-related quantities are rescaled by dividing by 100 to move from MW to a
normalized per-100-MW base (legacy normalization used in downstream model code).
"""
function forminputdata(
		DataGen,
		DataBranch,
		DataLoad,
		LoadCurve,
		GenCost,
		UnitsFreqParam,
		StrogeData,
		datacentra_Data,
		HydroData,
		HydroCurve
)

	# Determine system dimensions from input matrices.
	# DataGen,DataBranch,DataLoad,LoadCurve,GenCost = IEEE_RTS6()  # Example loader (not used).
	NB = Int64(maximum([maximum(DataBranch[:, 2]), maximum(DataBranch[:, 3])]))::Int64
	NL = Int64(size(DataBranch)[1])::Int64
	NG = Int64(size(DataGen)[1])::Int64
	ND = Int64(size(DataLoad)[1])::Int64
	NC = Int64(size(StrogeData)[1])::Int64
	# Temporal horizon taken from load curve length.
	# NT = 24::Int64  # fixed alternative
	NT = size(LoadCurve, 1)

	# ---------------- Generator data ----------------
	# Convert indices and buses to Int64; scale power-related columns.
	Gens_Index = convert(Array{Int64}, DataGen[:, 1])
	Gens_LocateBus = convert(Array{Int64}, DataGen[:, 2])
	Gens_Pmax = DataGen[:, 3] / 100
	Gens_Pmin = DataGen[:, 4] / 100
	Gens_RD = DataGen[:, 5] / 100
	Gens_RU = DataGen[:, 6] / 100
	Gens_SD = DataGen[:, 7] / 100
	Gens_SU = DataGen[:, 8] / 100
	Gens_TU = DataGen[:, 9]
	Gens_TD = DataGen[:, 10]
	Gens_x0 = DataGen[:, 11]
	# Gens_x0 could alternatively be initialized as ones(NG) indicating on-state.
	Gens_t0 = DataGen[:, 12]
	Gens_p0 = DataGen[:, 13] / 100
	Gens_t1 = DataGen[:, 14]

	# Generator cost coefficients (quadratic a, linear b, constant c) and other costs.
	Gens_c = GenCost[:, 2]
	Gens_b = GenCost[:, 3] * 1e2
	Gens_a = GenCost[:, 4] * 1e4
	Gens_CD = GenCost[:, 5]
	Gens_CU = GenCost[:, 6]
	Gens_CU1 = GenCost[:, 7]
	Gens_Cold = GenCost[:, 8]

	# ---------------- Transmission line data ----------------
	Trans_index = convert(Array{Int64}, DataBranch[:, 1])
	Trans_From = convert(Array{Int64}, DataBranch[:, 2])
	Trans_To = convert(Array{Int64}, DataBranch[:, 3])
	Trans_x = DataBranch[:, 4]
	Trans_Pmax = DataBranch[:, 5] / 100
	Trans_Pmin = (-1) .* DataBranch[:, 5] / 100
	# (Potential placeholders: susceptance Trans_b, ratio if transformer modeled.)

	# ---------------- Load data ----------------
	# Loads.Curve = LoadCurve  # total system load profile
	Loads_Index = convert(Array{Int64}, DataLoad[:, 1])
	Loads_LocateBus = convert(Array{Int64}, DataLoad[:, 2])
	Loads_Percent = DataLoad[:, 3]
	Loads_SumLoad = LoadCurve[:, 2] / 100
	Loads_PerLoad = zeros(ND, NT)
	# Disaggregate total load curve by fixed bus percentage allocation.
	for i ∈ 1:NT
		Loads_PerLoad[:, i] = Loads_SumLoad[i, 1] .* Loads_Percent[:, 1]
	end

	# ---------------- Frequency regulation parameters per unit ----------------
	Hg = UnitsFreqParam[:, 2]
	Dg = UnitsFreqParam[:, 3]
	Kg = UnitsFreqParam[:, 4]
	Fg = UnitsFreqParam[:, 5]
	Tg = UnitsFreqParam[:, 6]
	Rg = UnitsFreqParam[:, 7]

	# ---------------- Storage (PSS) data ----------------
	Pss_index = convert(Array{Int64}, StrogeData[:, 1])
	Pss_locatebus = convert(Array{Int64}, StrogeData[:, 2])
	Pss_q_max = StrogeData[:, 3] / 100
	Pss_q_min = StrogeData[:, 4] / 100
	Pss_p⁺ = StrogeData[:, 5] / 100
	Pss_p⁻ = StrogeData[:, 6] / 100
	Pss_P₀ = StrogeData[:, 7] / 100
	Pss_γ⁺ = StrogeData[:, 8] / 100
	Pss_γ⁻ = StrogeData[:, 9] / 100
	Pss_η⁺ = StrogeData[:, 10]
	Pss_η⁻ = StrogeData[:, 11]
	Pss_δₛ = StrogeData[:, 12]

	# ---------------- Global configuration parameters (penalties, weights, bases) ----------------
	# Renormalized / default configuration values for optimization scaling.
	# Create configuration parameters for the optimization model.
	# Arguments (in order):
	#   1: penalty for load shedding
	#   2: penalty for reserve shortage
	#   3: penalty for generator startup
	#   4: penalty for generator shutdown
	#   5: penalty for generator ramping
	#   6: penalty for generator minimum up/down time violation
	#   7: weight for frequency regulation
	#   8: tolerance for power balance (per unit)
	#   9: tolerance for reserve balance (per unit)
	#  10: base value for power (per unit system)
	#  11: base value for energy (per unit system)
	#  12: base value for time (per unit system)
	#  13: large penalty for infeasibility (big-M)
	#  14: large penalty for slack variables (big-M)
	#  15: base frequency (Hz)
	#  16: tolerance for frequency deviation
	#  17: reserved (set to 0)
	#  18: reserved (set to 0)
	#  19: reserved (set to 0)
	#  20: scaling factor for cost normalization
	#  21: scaling factor for emission normalization
	config_param = config(
		1,        # penalty for load shedding
		1,        # penalty for reserve shortage
		1,        # penalty for generator startup
		1,        # penalty for generator shutdown
		1,        # penalty for generator ramping
		1,        # penalty for generator min up/down time violation
		3,        # weight for frequency regulation
		0.005,    # tolerance for power balance
		0.005,    # tolerance for reserve balance
		1,        # base value for power
		1,        # base value for energy
		1,        # base value for time
		1e5,      # large penalty for infeasibility (big-M)
		1e5,      # large penalty for slack variables (big-M)
		50,       # base frequency (Hz)
		0.01,     # tolerance for frequency deviation
		0,        # reserved
		0,        # reserved
		0,        # reserved
		1,        # scaling factor for cost normalization
		2         # scaling factor for emission normalization
	)

	# Wrap primitive arrays into domain-specific composite types.
	units = unit(
		Gens_Index, Gens_LocateBus, Gens_Pmax, Gens_Pmin, Gens_RU, Gens_RD, Gens_SU, Gens_SD, Gens_TU, Gens_TD, Gens_x0, Gens_t0, Gens_t1, Gens_p0, Gens_a, Gens_b, Gens_c, Gens_CU, Gens_CU1, Gens_CD, Gens_Cold, Hg, Dg, Kg, Fg, Tg, Rg
	)
	# lines = transmissionline(Trans_From, Trans_To, Trans_x, Trans_b, Trans_Pmax, Trans_Pmin)  # older signature

	lines = transmissionline(Trans_index, Trans_From, Trans_To, Trans_x, Trans_Pmax, Trans_Pmin)

	stroges = pss(
		Pss_index, Pss_locatebus, Pss_q_max, Pss_q_min, Pss_p⁺, Pss_p⁻, Pss_P₀, Pss_γ⁺, Pss_γ⁻, Pss_η⁺, Pss_η⁻, Pss_δₛ
	)

	# Conditional creation of load structure only if dimensions match expectations.
	if size(Loads_PerLoad, 1) == ND
		if size(Loads_PerLoad, 2) == NT
			loads = load(Loads_Index, Loads_LocateBus, Loads_PerLoad)
		end
	end

	# ---------------- Data center dataset ----------------
	dc_index = convert(Array{Int64}, datacentra_Data[:, 1])
	dc_locatebus = convert(Array{Int64}, datacentra_Data[:, 2])
	dc_pmax = datacentra_Data[:, 3]
	dc_pmin = datacentra_Data[:, 4]
	dc_voltage_regulation = datacentra_Data[:, 5]
	dc_idale = datacentra_Data[:, 6]
	dc_sv_constent = datacentra_Data[:, 7]
	dc_λ = datacentra_Data[:, 8]
	dc_μ = datacentra_Data[:, 9]

	# Placeholder constant computational task profile (can be replaced by real curve).
	tem_computatioinal_task_curves = ones(NT, 1) * 0.2
	dc_computational_power_tasks = tem_computatioinal_task_curves

	ND2 = size(dc_index)[1]

	datacentra_data = data_centra(
		dc_index, dc_locatebus, dc_pmax, dc_pmin, dc_voltage_regulation, dc_idale, dc_sv_constent, dc_λ, dc_μ, dc_computational_power_tasks
	)

	# ---------------- Hydropower data ----------------
	# hydropower_data, hydropower_curve

	hydros_index = convert(Array{Int64}, HydroData[:, 1])
	hydros_locatebus = convert(Array{Int64}, HydroData[:, 2])
	hydros_pmax = HydroData[:, 3]
	hydros_pmin = HydroData[:, 4]
	hydros_qmax = HydroData[:, 5]
	hydros_q0 = HydroData[:, 6]
	hydros_reservoir_curve = HydroCurve[:, 2]
	NH = size(hydros_index)[1]
	hydros = hydro(
		hydros_index, hydros_locatebus, hydros_pmax, hydros_pmin, hydros_qmax, hydros_q0, hydros_reservoir_curve
	)

	println("Step-2: input data are loaded")

	return config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, datacentra_data, hydros
end
