"""
`define_decision_variables!(...)`

Registers all decision variables for a monolithic (single-stage) SCUC model.
This includes binary status variables for generators and storage, as well as
continuous variables for power dispatch, reserves, and slack.

# Categories

  - **Thermal Units**: x, u, v, pg, su, sd, sr.
  - **System Flexibility**: Δpd (Load shedding), Δpw (Wind curtailment).
  - **Storage (BESS/PSS)**: κ, pc, qc.
  - **Data Centers**: dc_p, dc_f, dc_λ.
"""
function define_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	# --- Thermal Unit Commitment Variables (Scenario-independent) ---
	@variable(scuc, x[1:NG, 1:NT], Bin)  # Commitment status (1: On, 0: Off)
	@variable(scuc, u[1:NG, 1:NT], Bin)  # Startup indicator
	@variable(scuc, v[1:NG, 1:NT], Bin)  # Shutdown indicator

	# --- Generation, Reserve, and Slack Variables (Scenario-indexed) ---
	@variable(scuc, pg₀[1:(NG * NS), 1:NT] >= 0)       # Base active power dispatch
	@variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3] >= 0)  # Piecewise cost segments
	@variable(scuc, su₀[1:NG, 1:NT] >= 0)            # Startup cost linearization
	@variable(scuc, sd₀[1:NG, 1:NT] >= 0)            # Shutdown cost linearization
	@variable(scuc, sr⁺[1:(NG * NS), 1:NT] >= 0)       # Upward spinning reserve
	@variable(scuc, sr⁻[1:(NG * NS), 1:NT] >= 0)       # Downward spinning reserve
	@variable(scuc, Δpd[1:(ND * NS), 1:NT] >= 0)       # Load shedding slack
	@variable(scuc, Δpw[1:(NW * NS), 1:NT] >= 0)       # Wind curtailment slack

	# --- Energy Storage (BESS) Variables ---
	@variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin)   # Charging binary status
	@variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin)   # Discharging binary status
	@variable(scuc, pc⁺[1:(NC * NS), 1:NT] >= 0)  # Charging power power
	@variable(scuc, pc⁻[1:(NC * NS), 1:NT] >= 0)  # Discharging power power
	@variable(scuc, qc[1:(NC * NS), 1:NT] >= 0)   # State of Charge (SoC) energy

	@variable(scuc, α[1:(NS * NC), 1:NT], Bin)  # Auxiliary flags for cycle counting
	@variable(scuc, β[1:(NS * NC), 1:NT], Bin)

	if config_param.is_ConsiderDataCentra == 1
		@variable(scuc, dc_p[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_f[1:(ND2 * NS), 1:NT] >= 0)
		# @variable(scuc, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
		@variable(scuc, dc_v²[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_λ[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_Δu1[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_Δu2[1:(ND2 * NS), 1:NT] >= 0)
	end

	# Frequency control related variables (assuming these might be needed based on later constraints)
	# Check if these are actually used/defined in the constraints file later
	if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
		@variable(scuc, Δf_nadir[1:NS] >= 0)
		@variable(scuc, Δf_qss[1:NS] >= 0)
		@variable(scuc, Δp_imbalance[1:NS] >= 0) # Placeholder, adjust as needed based on full constraints
	end

	println("\t Variables defined.")
	return scuc # Return model with variables
end
