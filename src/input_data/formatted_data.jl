# Formatted SCUC domain data structures and compatibility aliases

"""
`UCConfig` (legacy alias: `config`)

Configuration parameters controlling algorithmic behavior and model inclusion logic for the SCUC optimization.
"""
struct UCConfig
    # Algorithmic and model inclusion flags
    is_network_con::Int64                 # 1: Consider transmission network constraints; 0: Ignore
    is_thermal_unit_con::Int64            # 1: Consider thermal unit generation limits; 0: Ignore
    is_wind_unit_con::Int64               # 1: Consider wind generation availability; 0: Ignore
    is_system_con::Int64                  # 1: Consider system-level balance/tracking; 0: Ignore
    is_piecewise_linear::Int64            # 1: Use piecewise linear cost approximations; 0: Nonlinear
    num_segments::Int64                   # Number of linear approximation segments for cost curves

    # Objective function weighting factors
    alpha::Float64                        # Penalty weight for economic dispatch base cost
    beta::Float64                         # Penalty weight for frequency deviation or emission objective

    # Market and economic factors
    coal_price::Int64                     # Multiplier or index for fuel cost modeling

    # Flexible modeling scopes
    is_active_load::Int64                 # 1: Consider active load demand constraints; 0: Ignore
    is_wind_integration::Int64            # 1: Enable stochastic wind integration; 0: Ignore
    load_cutting_coefficient::Float64     # Economic penalty factor for involuntary load shedding
    wind_cutting_coefficient::Float64     # Economic penalty factor for wind curtailment

    # Benders decomposition solver precision parameters
    max_iterations::Int64                 # Maximum allowed iterations for algorithmic convergence
    calculation_precision::Float64        # Absolute or relative optimization gap tolerance

    # Advanced sub-component inclusions
    consider_data_center::Int64           # 1: Enable spatially-coupled Data Center flexible loads; 0: Ignore
    consider_frequency_control::Int64     # 1: Enforce frequency safety (nadir/RoCoF) constraints; 0: Ignore
    consider_bess::Int64                  # 1: Enable Battery Energy Storage Systems / PSS; 0: Ignore
    consider_multi_cuts::Int64            # 1: Generate multiple Benders cuts per scenario; 0: Standard aggregated cut
end

const config = UCConfig

const _LEGACY_UCCONFIG_FIELDS = Dict{Symbol, Symbol}(
    :is_NetWorkCon => :is_network_con,
    :is_ThermalUnitCon => :is_thermal_unit_con,
    :is_WindUnitCon => :is_wind_unit_con,
    :is_SysticalCon => :is_system_con,
    :is_PieceLinear => :is_piecewise_linear,
    :is_NumSeg => :num_segments,
    :is_Alpha => :alpha,
    :is_Belta => :beta,
    :is_CoalPrice => :coal_price,
    :is_ActiveLoad => :is_active_load,
    :is_WindIntegration => :is_wind_integration,
    :is_LoadsCuttingCoefficient => :load_cutting_coefficient,
    :is_WindsCuttingCoefficient => :wind_cutting_coefficient,
    :is_MaxIterationsNum => :max_iterations,
    :is_CalculPrecision => :calculation_precision,
    :is_ConsiderDataCentra => :consider_data_center,
    :is_ConsiderFrequencyControl => :consider_frequency_control,
    :is_ConsiderBESS => :consider_bess,
    :is_ConsiderMultiCUTs => :consider_multi_cuts,
)

function Base.getproperty(cfg::UCConfig, name::Symbol)
    canonical = get(_LEGACY_UCCONFIG_FIELDS, name, name)
    return getfield(cfg, canonical)
end

const DEFAULT_LOAD_CURTAILMENT_PENALTY_SCALE = 1e4

"""
    uc_load_curtailment_penalty(config_param::UCConfig)

Return the unified load-shedding penalty used across Benchmark, Benders, CCG,
DRO objectives, and scheduling cost exports.
"""
function uc_load_curtailment_penalty(config_param::UCConfig)
    return Float64(config_param.load_cutting_coefficient) * DEFAULT_LOAD_CURTAILMENT_PENALTY_SCALE
end

"""
    uc_wind_curtailment_penalty(config_param::UCConfig)

Return the unified wind-curtailment penalty used across all SCUC algorithms and
scheduling cost exports.
"""
function uc_wind_curtailment_penalty(config_param::UCConfig)
    return Float64(config_param.wind_cutting_coefficient)
end

model_env_int(name::String, default::Int64) = uc_env_int(name, default)
model_env_float(name::String, default::Float64) = uc_env_float(name, default)

function config_from_env()
    consider_bess = model_env_int("MODEL_CONSIDER_BESS", parse(Int64, get(ENV, "BENDERS_CONSIDER_BESS", get(ENV, "CONSIDER_BESS", "0"))))
    return UCConfig(
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
`ThermalUnits` (legacy alias: `unit`)

Structure representing dispatchable conventional or thermal generation units.
"""
mutable struct ThermalUnits
    # Topological mapping
    index::Vector{Int64}                  # Generator ID array
    locatebus::Vector{Int64}              # Connected bus ID array

    # Power output constraints
    p_max::Vector{Float64}                # Maximum active power limits (p.u.)
    p_min::Vector{Float64}                # Minimum active power limits (p.u.)
    ramp_up::Vector{Float64}              # Normal operational ramp-up limits (p.u./time)
    ramp_down::Vector{Float64}            # Normal operational ramp-down limits (p.u./time)
    startup_ramp::Vector{Float64}         # Startup condition ramp limits (p.u.)
    shutdown_ramp::Vector{Float64}        # Shutdown condition ramp limits (p.u.)

    # Temporal scheduling constraints
    min_up_time::Vector{Float64}          # Minimum continuous up-time requirement (h)
    min_down_time::Vector{Float64}        # Minimum continuous down-time requirement (h)

    # Initial border states (t=0)
    x_0::Vector{Float64}                  # Initial online status (1: online, 0: offline)
    t_0::Vector{Float64}                  # Accumulative hours historically online prior to dispatch
    t_1::Vector{Float64}                  # Accumulative hours historically offline prior to dispatch
    p_0::Vector{Float64}                  # Initial generated active power (p.u.)

    # Performance & operation cost parameters
    coeff_a::Vector{Float64}              # Quadratic fuel cost coefficient ($/MW^2)
    coeff_b::Vector{Float64}              # Linear fuel cost coefficient ($/MW)
    coeff_c::Vector{Float64}              # Fixed no-load operational cost ($)
    coeff_hot_startup::Vector{Float64}    # Hot startup cost penalty ($)
    coeff_cold_startup::Vector{Float64}   # Cold startup cost penalty ($)
    coeff_shutdown::Vector{Float64}       # Normal shutdown cost ($)
    cold_start_time_limit::Vector{Float64} # Cold start time horizon limit (h)

    # Frequency response parameters
    Hg::Vector{Float64}                   # Generation unit inertia constant (s)
    Dg::Vector{Float64}                   # Mechanical damping constant (p.u.)
    Kg::Vector{Float64}                   # Governor gain (inverse of droop characteristic)
    Fg::Vector{Float64}                   # Fraction of total power generated by high-pressure turbine stages
    Tg::Vector{Float64}                   # Governor/Turbine operational time constant (s)
    Rg::Vector{Float64}                   # Unit governor speed regulation or droop factor (p.u.)

    function ThermalUnits(
        index, locatebus, p_max, p_min, ramp_up, ramp_down, startup_ramp, shutdown_ramp,
        min_up_time, min_down_time,
        x_0, t_0, p_0, coeff_a, coeff_b, coeff_c, coeff_hot_startup, coeff_cold_startup, coeff_shutdown, cold_start_time_limit,
        Hg, Dg, Kg, Fg, Tg, Rg;
        t_1 = zeros(Float64, length(t_0)),
    )
        return new(
            index, locatebus, p_max, p_min, ramp_up, ramp_down, startup_ramp, shutdown_ramp,
            min_up_time, min_down_time, x_0, t_0, Float64.(t_1), p_0, coeff_a, coeff_b, coeff_c,
            coeff_hot_startup, coeff_cold_startup, coeff_shutdown, cold_start_time_limit,
            Hg, Dg, Kg, Fg, Tg, Rg,
        )
    end
end

const unit = ThermalUnits

const _LEGACY_THERMAL_UNIT_FIELDS = Dict{Symbol, Symbol}(
    :shut_up => :startup_ramp,
    :shut_down => :shutdown_ramp,
    :min_shutup_time => :min_up_time,
    :min_shutdown_time => :min_down_time,
    :coffi_a => :coeff_a,
    :coffi_b => :coeff_b,
    :coffi_c => :coeff_c,
    :coffi_cold_shutup_1 => :coeff_hot_startup,
    :coffi_cold_shutup_2 => :coeff_cold_startup,
    :coffi_cold_shutdown_1 => :coeff_shutdown,
    :coffi_cold_shutdown_2 => :cold_start_time_limit,
)

function Base.getproperty(u::ThermalUnits, name::Symbol)
    canonical = get(_LEGACY_THERMAL_UNIT_FIELDS, name, name)
    return getfield(u, canonical)
end

"""
`TransmissionLines` (legacy alias: `transmissionline`)

Structure representing the AC transmission network branches.
"""
struct TransmissionLines
    index::Vector{Int64}                  # Branch/Line ID
    from::Vector{Int64}                   # Sending bus ID
    to::Vector{Int64}                     # Receiving bus ID
    x::Vector{Float64}                    # Branch series reactance (p.u.)
    p_max::Vector{Float64}                # Forward active power flow capacity
    p_min::Vector{Float64}                # Reverse active power flow capacity

    function TransmissionLines(index, from, to, x, p_max, p_min)
        return new(index, from, to, x, p_max, p_min)
    end
end

const transmissionline = TransmissionLines

"""
`Loads` (legacy alias: `load`)

Structure representing baseline electrical demand across various network nodes.
"""
mutable struct Loads
    index::Vector{Int64}                  # Load ID
    locatebus::Vector{Int64}              # Connected bus ID
    load_curve::Array{Float64}            # Time-series active power demand matrix (ND x NT)

    function Loads(index, locatebus, load_curve)
        return new(index, locatebus, load_curve)
    end
end

const load = Loads

"""
`StorageUnits` (legacy alias: `pss`)

Structure representing energy storage units, such as Pumped-Storage Systems (PSS) or Batteries (BESS).
"""
struct StorageUnits
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

    function StorageUnits(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ)
        return new(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ)
    end
end

const pss = StorageUnits

"""
`DataCenters` (legacy alias: `data_centra`)

Structure representing spatial Data Centers acting as dispatchable, computationally-linked flexible loads.
"""
struct DataCenters
    index::Vector{Int64}                       # Data center ID
    locatebus::Vector{Int64}                   # Connected power bus ID
    p_max::Vector{Float64}                     # Maximum permissible power consumption
    p_min::Vector{Float64}                     # Minimum mandatory power consumption
    voltage_regulation::Vector{Float64}        # Voltage-dependent active power regulation capability
    idle_power::Vector{Float64}                # Baseline or static idle power consumption
    sv_constant::Vector{Float64}               # Equivalent server energy constant (models PUE characteristics)
    λ::Vector{Float64}                         # IT computational task continuous arrival rate
    μ::Vector{Float64}                         # IT computational task service processing capability
    computational_power_tasks::Matrix{Float64} # Time-series IT task allocation matrix (ND2 x NT)

    function DataCenters(index, locatebus, p_max, p_min, voltage_regulation, idle_power, sv_constant, λ, μ, computational_power_tasks)
        return new(index, locatebus, p_max, p_min, voltage_regulation, idle_power, sv_constant, λ, μ, computational_power_tasks)
    end
end

const data_centra = DataCenters

function Base.getproperty(dc::DataCenters, name::Symbol)
    name === :idale && return getfield(dc, :idle_power)
    return getfield(dc, name)
end
