# reformat data
"""
`config`

Configuration parameters controlling algorithmic behavior and model inclusion logic for the SCUC optimization.
"""
struct config
    # Algorithmic and model inclusion flags
    is_NetWorkCon::Int64                  # 1: Consider transmission network constraints; 0: Ignore
    is_ThermalUnitCon::Int64              # 1: Consider thermal unit generation limits; 0: Ignore
    is_WindUnitCon::Int64                 # 1: Consider wind generation availability; 0: Ignore
    is_SysticalCon::Int64                 # 1: Consider system-level balance/tracking; 0: Ignore
    is_PieceLinear::Int64                 # 1: Use piecewise linear cost approximations; 0: Nonlinear
    is_NumSeg::Int64                      # Number of linear approximation segments for cost curves

    # Objective function weighting factors
    is_Alpha::Float64                     # Penalty weight for economic dispatch base cost
    is_Belta::Float64                     # Penalty weight for frequency deviation or emission objective

    # Market and economic factors
    is_CoalPrice::Int64                   # Multiplier or index for fuel cost modeling

    # Flexible modeling scopes
    is_ActiveLoad::Int64                  # 1: Consider active load demand constraints; 0: Ignore
    is_WindIntegration::Int64             # 1: Enable stochastic wind integration; 0: Ignore
    is_LoadsCuttingCoefficient::Float64   # Economic penalty factor for involuntary load shedding
    is_WindsCuttingCoefficient::Float64   # Economic penalty factor for wind curtailment

    # Benders decomposition solver precision parameters
    is_MaxIterationsNum::Int64            # Maximum allowed iterations for algorithmic convergence
    is_CalculPrecision::Float64           # Absolute or relative optimization gap tolerance

    # Advanced sub-component inclusions
    is_ConsiderDataCentra::Int64          # 1: Enable spatially-coupled Data Center flexible loads; 0: Ignore
    is_ConsiderFrequencyControl::Int64    # 1: Enforce frequency safety (nadir/RoCoF) constraints; 0: Ignore
    is_ConsiderBESS::Int64                # 1: Enable Battery Energy Storage Systems / PSS; 0: Ignore
    is_ConsiderMultiCUTs::Int64           # 1: Generate multiple Benders cuts per scenario; 0: Standard aggregated cut
end

function model_env_int(name::String, default::Int64)
	return parse(Int64, get(ENV, name, string(default)))
end

function model_env_float(name::String, default::Float64)
	return parse(Float64, get(ENV, name, string(default)))
end

function config_from_env()
	consider_bess = model_env_int(
		"MODEL_CONSIDER_BESS",
		parse(Int64, get(ENV, "BENDERS_CONSIDER_BESS", get(ENV, "CONSIDER_BESS", "0"))),
	)
	return config(
		model_env_int("MODEL_IS_NETWORK_CON", 1),
		model_env_int("MODEL_IS_THERMAL_UNIT_CON", 1),
		model_env_int("MODEL_IS_WIND_UNIT_CON", 1),
		model_env_int("MODEL_IS_SYSTEM_CON", 1),
		model_env_int("MODEL_IS_PIECE_LINEAR", 1),
		model_env_int("MODEL_NUM_SEGMENTS", 3),
		model_env_float("MODEL_ALPHA", 0.005),
		model_env_float("MODEL_BETA", 0.005),
		model_env_int("MODEL_COAL_PRICE", 1),
		model_env_int("MODEL_IS_ACTIVE_LOAD", 1),
		model_env_int("MODEL_IS_WIND_INTEGRATION", 1),
		model_env_float("MODEL_LOAD_CUTTING_COEFFICIENT", 1e5),
		model_env_float("MODEL_WIND_CUTTING_COEFFICIENT", 1e5),
		model_env_int("MODEL_MAX_ITERATIONS_NUM", 50),
		model_env_float("MODEL_CALCULATION_PRECISION", 0.01),
		model_env_int("MODEL_CONSIDER_DATA_CENTER", 0),
		model_env_int("MODEL_CONSIDER_FREQUENCY_CONTROL", 0),
		consider_bess,
		model_env_int("MODEL_CONSIDER_MULTI_CUTS", 1),
	)
end

"""
`unit`

Structure representing dispatchable conventional or thermal generation units.
"""
struct unit
    # Topological mapping
    index::Vector{Int64}                  # Generator ID array
    locatebus::Vector{Int64}              # Connected bus ID array

    # Power output constraints
    p_max::Vector{Float64}                # Maximum active power limits (p.u.)
    p_min::Vector{Float64}                # Minimum active power limits (p.u.)
    ramp_up::Vector{Float64}              # Normal operational ramp-up limits (p.u./time)
    ramp_down::Vector{Float64}            # Normal operational ramp-down limits (p.u./time)
    shut_up::Vector{Float64}              # Startup condition ramp limits (p.u.)
    shut_down::Vector{Float64}            # Shutdown condition ramp limits (p.u.)

    # Temporal scheduling constraints
    min_shutup_time::Vector{Float64}      # Minimum continuous up-time requirement (h)
    min_shutdown_time::Vector{Float64}    # Minimum continuous down-time requirement (h)

    # Initial border states (t=0)
    x_0::Vector{Float64}                  # Initial online status (1: online, 0: offline)
    t_0::Vector{Float64}                  # Accumulative hours historically online/offline prior to dispatch
    p_0::Vector{Float64}                  # Initial generated active power (p.u.)

    # Performance & operation cost parameters
    coffi_a::Vector{Float64}              # Quadratic fuel cost coefficient ($/MW^2)
    coffi_b::Vector{Float64}              # Linear fuel cost coefficient ($/MW)
    coffi_c::Vector{Float64}              # Fixed no-load operational cost ($)
    coffi_cold_shutup_1::Vector{Float64}  # Hot startup cost penalty ($)
    coffi_cold_shutup_2::Vector{Float64}  # Cold startup cost penalty ($)
    coffi_cold_shutdown_1::Vector{Float64} # Normal shutdown cost ($)
    coffi_cold_shutdown_2::Vector{Float64} # Cold start time horizon limit (h)

    # Frequency response parameters

    # Part-1 Inertia response process
    Hg::Vector{Float64}                   # Generation unit inertia constant (s)
    Dg::Vector{Float64}                   # Mechanical damping constant (p.u.)

    # Part-2 Primary frequency response process
    Kg::Vector{Float64}                   # Governor gain (inverse of droop characteristic)
    Fg::Vector{Float64}                   # Fraction of total power generated by high-pressure turbine stages
    Tg::Vector{Float64}                   # Governor/Turbine operational time constant (s)
    Rg::Vector{Float64}                   # Unit governor speed regulation or droop factor (p.u.)

    function unit(
        index,
        locatebus,
        p_max,
        p_min,
        ramp_up,
        ramp_down,
        shut_up,
        shut_down,
        min_shutup_time,
        min_shutdown_time,
        x_0,
        t_0,
        p_0,
        coffi_a,
        coffi_b,
        coffi_c,
        coffi_cold_shutup_1,
        coffi_cold_shutup_2,
        coffi_cold_shutdown_1,
        coffi_cold_shutdown_2,
        Hg,
        Dg,
        Kg,
        Fg,
        Tg,
        Rg,
    )
        return new(
            index,
            locatebus,
            p_max,
            p_min,
            ramp_up,
            ramp_down,
            shut_up,
            shut_down,
            min_shutup_time,
            min_shutdown_time,
            x_0,
            t_0,
            p_0,
            coffi_a,
            coffi_b,
            coffi_c,
            coffi_cold_shutup_1,
            coffi_cold_shutup_2,
            coffi_cold_shutdown_1,
            coffi_cold_shutdown_2,
            Hg,
            Dg,
            Kg,
            Fg,
            Tg,
            Rg,
        )
    end

    # units(Hg,Dg,Kg,Fg,Tg,Rg) = new(Hg,Dg,Kg,Fg,Tg,Rg)
    #
    # function unit(args...)
    #     new(index, p_max, p_min, ramp_up, ramp_down, shut_up, shut_down, min_shutup_time, min_shutdown_time,
    #         x_0, t_0, p_0, coffi_a, coffi_b, coffi_c, coffi_cold_shutup_1, coffi_cold_shutup_2, coffi_cold_shutdown_1, coffi_cold_shutdown_2, Hg, Dg, Kg, Fg, Tg, Rg, nothing)
    # end
end

"""
`transmissionline`

Structure representing the AC transmission network branches.
"""
struct transmissionline
    index::Vector{Int64}                  # Branch/Line ID
    from::Vector{Int64}                   # Sending bus ID
    to::Vector{Int64}                     # Receiving bus ID
    x::Vector{Float64}                    # Branch series reactance (p.u.)
    p_max::Vector{Float64}                # Forward active power flow capacity
    p_min::Vector{Float64}                # Reverse active power flow capacity
    # b::Vector{Float64}
    # ratio::Vector{Int64}
    # transmissionline(from,to,x,b,p_max,p_min) = new(from,to,x,b,p_max,p_min)
    function transmissionline(index, from, to, x, p_max, p_min)
        return new(index, from, to, x, p_max, p_min)
    end
end

"""
`load`

Structure representing baseline electrical demand across various network nodes.
"""
struct load
    index::Vector{Int64}                  # Load ID
    locatebus::Vector{Int64}              # Connected bus ID
    load_curve::Array{Float64}            # Time-series active power demand matrix (ND x NT)
    function load(index, locatebus, load_curve) # Using consistent constructor syntax
        return new(index, locatebus, load_curve)
    end
end

"""
`pss`

Structure representing energy storage units, such as Pumped-Storage Systems (PSS) or Batteries.
"""
struct pss
    index::Vector{Int64}                  # Storage unit ID
    locatebus::Vector{Int64}              # Connected bus ID
    Q_max::Vector{Float64}                # Maximum State of Charge (SoC) energy limit
    Q_min::Vector{Float64}                # Minimum State of Charge (SoC) energy limit
    p⁺::Vector{Float64}                   # Maximum active power charging limit
    p⁻::Vector{Float64}                   # Maximum active power discharging limit
    P₀::Vector{Float64}                   # Initial stored energy level (SoC at t=0)
    γ⁺::Vector{Float64}                   # Charging operational ramp rate limit
    γ⁻::Vector{Float64}                   # Discharging operational ramp rate limit
    η⁺::Vector{Float64}                   # Energy conversion charging efficiency
    η⁻::Vector{Float64}                   # Energy conversion discharging efficiency
    δₛ::Vector{Float64}                   # Storage self-discharge or capacity leakage rate
    function pss(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ) # Corrected constructor name, also fixed p₀ -> P₀ to match definition
        return new(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ) # Fixed p₀ -> P₀
    end
end

"""
`data_centra`

Structure representing spatial Data Centers acting as dispatchable, computationally-linked flexible loads.
"""
struct data_centra
    index::Vector{Int64}                  # Data center ID
    locatebus::Vector{Int64}              # Connected power bus ID
    p_max::Vector{Float64}                # Maximum permissible power consumption
    p_min::Vector{Float64}                # Minimum mandatory power consumption
    voltage_regulation::Vector{Float64}   # Voltage-dependent active power regulation capability
    idale::Vector{Float64}                # Baseline or static idle power consumption
    sv_constant::Vector{Float64}          # Equivalent server energy constant (models PUE characteristics)
    λ::Vector{Float64}                    # IT computational task continuous arrival rate
    μ::Vector{Float64}                    # IT computational task service processing capability
    computational_power_tasks::Matrix{Float64} # Time-series IT task allocation matrix (ND2 x NT)
    function data_centra(index, locatebus, p_max, p_min, voltage_regulation, idale, sv_constant, λ, μ, computational_power_tasks)
        return new(index, locatebus, p_max, p_min, voltage_regulation, idale, sv_constant, λ, μ, computational_power_tasks)
    end
end
