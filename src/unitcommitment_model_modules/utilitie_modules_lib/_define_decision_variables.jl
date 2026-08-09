using JuMP

export define_decision_variables!

"""
    define_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, NH, config_param)

Define all decision variables for the stochastic unit commitment optimization model.

This function creates all binary and continuous variables needed for the SCUC problem,
including unit commitment, power dispatch, reserves, storage, and optional components
like data centers and frequency control.

# Arguments
- `scuc::Model`: JuMP optimization model
- `NT::Int`: Number of time periods
- `NG::Int`: Number of generators
- `ND::Int`: Number of loads
- `NC::Int`: Number of energy storage units
- `ND2::Int`: Number of data centers
- `NS::Int`: Number of scenarios
- `NW::Int`: Number of wind farms
- `NH::Int`: Number of hydro units
- `config_param::config`: Configuration parameters with flags:
  - `is_ConsiderDataCentra`: Enable data center variables
  - `is_ConsiderFrequencyControl`: Enable frequency control variables
  - `is_HydroUnitCon`: Enable hydro unit variables

# Variables Defined

## Binary Variables
- `x[g, t]`: Unit commitment status (1 = on, 0 = off)
- `u[g, t]`: Unit startup indicator
- `v[g, t]`: Unit shutdown indicator
- `κ⁺[c, s, t]`: Storage charging status
- `κ⁻[c, s, t]`: Storage discharging status
- `α[c, s, t]`: BESS charging binary variable
- `β[c, s, t]`: BESS discharging binary variable

## Continuous Variables
- `pg₀[g, s, t]`: Base power output (MW)
- `pgₖ[g, s, t, k]`: Piecewise linear power segments (k = 1, 2, 3)
- `su₀[g, t]`: Startup cost (dollars)
- `sd₀[g, t]`: Shutdown cost (dollars)
- `sr⁺[g, s, t]`: Upward reserve (MW)
- `sr⁻[g, s, t]`: Downward reserve (MW)
- `Δpd[d, s, t]`: Load curtailment (MW)
- `Δpw[w, s, t]`: Wind curtailment (MW)
- `pc⁺[c, s, t]`: Storage charging power (MW)
- `pc⁻[c, s, t]`: Storage discharging power (MW)
- `qc[c, s, t]`: Storage energy state (MWh)

## Optional Variables (if enabled)
- Data center: `dc_p`, `dc_f`, `dc_v²`, `dc_λ`, `dc_Δu1`, `dc_Δu2`
- Frequency control: `Δf_nadir`, `Δf_qss`, `Δp_imbalance`
- Hydro: `ph[h, s, t]`

# Returns
- `scuc::Model`: Modified model with all variables defined
"""

function define_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, NH, config_param)
    # ========================================================================
    # Binary Variables: Unit Commitment
    # ========================================================================
    @variable(scuc, x[1:NG, 1:NT], Bin)  # Unit on/off status
    @variable(scuc, u[1:NG, 1:NT], Bin)  # Startup indicator
    @variable(scuc, v[1:NG, 1:NT], Bin)  # Shutdown indicator

    # ========================================================================
    # Continuous Variables: Power Generation
    # ========================================================================
    @variable(scuc, pg₀[1:(NG * NS), 1:NT] >= 0)      # Base power output
    @variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3] >= 0) # Piecewise linear segments
    @variable(scuc, su₀[1:NG, 1:NT] >= 0)           # Startup cost
    @variable(scuc, sd₀[1:NG, 1:NT] >= 0)           # Shutdown cost
    @variable(scuc, sr⁺[1:(NG * NS), 1:NT] >= 0)      # Upward spinning reserve
    @variable(scuc, sr⁻[1:(NG * NS), 1:NT] >= 0)      # Downward spinning reserve

    # ========================================================================
    # Continuous Variables: Curtailment
    # ========================================================================
    @variable(scuc, Δpd[1:(ND * NS), 1:NT] >= 0)  # Load curtailment
    @variable(scuc, Δpw[1:(NW * NS), 1:NT] >= 0)  # Wind curtailment

    # ========================================================================
    # Variables: Energy Storage System (ESS)
    # ========================================================================
    @variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin)  # Charging status
    @variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin)  # Discharging status
    @variable(scuc, pc⁺[1:(NC * NS), 1:NT] >= 0) # Charging power
    @variable(scuc, pc⁻[1:(NC * NS), 1:NT] >= 0) # Discharging power
    @variable(scuc, qc[1:(NC * NS), 1:NT] >= 0)  # Energy state (cumulative)

    # BESS charging/discharging binary variables
    @variable(scuc, α[1:(NS * NC), 1:NT], Bin)  # Charging binary
    @variable(scuc, β[1:(NS * NC), 1:NT], Bin)  # Discharging binary

    # ========================================================================
    # Optional Variables: Data Centers
    # ========================================================================
    if config_param.is_ConsiderDataCentra == 1
        @variable(scuc, dc_p[1:(ND2 * NS), 1:NT] >= 0)    # Data center power consumption
        @variable(scuc, dc_f[1:(ND2 * NS), 1:NT] >= 0)    # Data center frequency
        @variable(scuc, dc_v²[1:(ND2 * NS), 1:NT] >= 0)   # Data center voltage squared
        @variable(scuc, dc_λ[1:(ND2 * NS), 1:NT] >= 0)    # Data center dual variable
        @variable(scuc, dc_Δu1[1:(ND2 * NS), 1:NT] >= 0)  # Data center control variable 1
        @variable(scuc, dc_Δu2[1:(ND2 * NS), 1:NT] >= 0)  # Data center control variable 2
    end

    # ========================================================================
    # Optional Variables: Frequency Control
    # ========================================================================
    if config_param.is_ConsiderFrequencyControl == 1
        @variable(scuc, Δf_nadir[1:NS] >= 0)      # Frequency nadir deviation
        @variable(scuc, Δf_qss[1:NS] >= 0)       # Quasi-steady-state frequency deviation
        @variable(scuc, Δp_imbalance[1:NS] >= 0) # Power imbalance
    end

    # ========================================================================
    # Optional Variables: Hydroelectric Units
    # ========================================================================
    if config_param.is_HydroUnitCon == 1
        @variable(scuc, ph[1:(NH * NS), 1:NT] >= 0) # Hydro power output
    end

    println("\t Variables defined.")
    return scuc
end
