# ============================================================================
# Data Structure Definitions for Unit Commitment Model
#
# This module defines all data structures used throughout the unit commitment
# optimization model. These structures organize input data and model parameters
# in a type-safe and accessible manner.
# ============================================================================

# ============================================================================
# Configuration Parameters Structure
# ============================================================================
"""
	config

Configuration parameters structure for the unit commitment model.

This structure contains all flags and parameters that control which constraints
and features are enabled in the optimization model.

# Fields

  - `is_NetWorkCon::Int64`: Enable transmission network constraints (1 = yes, 0 = no)
  - `is_ThermalUnitCon::Int64`: Enable thermal unit constraints (1 = yes, 0 = no)
  - `is_WindUnitCon::Int64`: Enable wind unit constraints (1 = yes, 0 = no)
  - `is_HydroUnitCon::Int64`: Enable hydro unit constraints (1 = yes, 0 = no)
  - `is_SysticalCon::Int64`: Enable system-wide constraints (1 = yes, 0 = no)
  - `is_PieceLinear::Int64`: Use piecewise linear cost approximation (1 = yes, 0 = no)
  - `is_NumSeg::Int64`: Number of segments for piecewise linearization
  - `is_Alpha::Float64`: Alpha parameter for optimization
  - `is_Belta::Float64`: Beta parameter for optimization
  - `is_CoalPrice::Int64`: Coal price parameter
  - `is_ActiveLoad::Int64`: Enable active load management (1 = yes, 0 = no)
  - `is_WindIntegration::Int64`: Enable wind integration (1 = yes, 0 = no)
  - `is_LoadsCuttingCoefficient::Float64`: Load curtailment penalty coefficient
  - `is_WindsCuttingCoefficient::Float64`: Wind curtailment penalty coefficient
  - `is_MaxIterationsNum::Int64`: Maximum number of iterations
  - `is_CalculPrecision::Float64`: Calculation precision tolerance
  - `is_ConsiderDataCentra::Int64`: Enable data center constraints (1 = yes, 0 = no)
  - `is_ConsiderFrequencyControl::Int64`: Enable frequency control (1 = yes, 0 = no)
  - `is_ConsiderBESS::Int64`: Enable battery energy storage (1 = yes, 0 = no)
  - `is_ConsiderMultiCUTs::Int64`: Enable multi-cut Benders decomposition (1 = yes, 0 = no)
"""
mutable struct config
	# Network and unit constraints
	is_NetWorkCon::Int64
	is_ThermalUnitCon::Int64
	is_WindUnitCon::Int64
	is_HydroUnitCon::Int64
	is_SysticalCon::Int64

	# Cost linearization
	is_PieceLinear::Int64
	is_NumSeg::Int64

	# Optimization parameters
	is_Alpha::Float64
	is_Belta::Float64
	is_CoalPrice::Int64

	# Load and renewable integration
	is_ActiveLoad::Int64
	is_WindIntegration::Int64
	is_LoadsCuttingCoefficient::Float64
	is_WindsCuttingCoefficient::Float64

	# Solver settings
	is_MaxIterationsNum::Int64
	is_CalculPrecision::Float64

	# Optional features
	is_ConsiderDataCentra::Int64
	is_ConsiderFrequencyControl::Int64
	is_ConsiderBESS::Int64
	is_ConsiderMultiCUTs::Int64

  # Scheduling Objective function settings
  is_SchedulingObjFuncType::Int64  # 1: Minimize Cost, 2: Minimize Emissions, etc.
end

# ============================================================================
# Generator Unit Structure
# ============================================================================
"""
	unit

Generator unit data structure containing all parameters for thermal units.

# Fields

## Basic Unit Parameters

  - `index::Vector{Int64}`: Unit indices
  - `locatebus::Vector{Int64}`: Bus location of each unit
  - `p_max::Vector{Float64}`: Maximum power output (MW)
  - `p_min::Vector{Float64}`: Minimum power output (MW)
  - `ramp_up::Vector{Float64}`: Maximum ramp-up rate (MW/h)
  - `ramp_down::Vector{Float64}`: Maximum ramp-down rate (MW/h)

## Commitment Parameters

  - `shut_up::Vector{Float64}`: Startup cost (dollars)
  - `shut_down::Vector{Float64}`: Shutdown cost (dollars)
  - `min_shutup_time::Vector{Float64}`: Minimum up time (hours)
  - `min_shutdown_time::Vector{Float64}`: Minimum down time (hours)

## Initial Conditions

  - `x_0::Vector{Float64}`: Initial on/off status (0 or 1)
  - `t_0::Vector{Float64}`: Initial time in current state (hours)
  - `t_1::Vector{Float64}`: Time since last state change (hours)
  - `p_0::Vector{Float64}`: Initial power output (MW)

## Cost Function Coefficients

  - `coffi_a::Vector{Float64}`: Quadratic cost coefficient (dollars per MW²)
  - `coffi_b::Vector{Float64}`: Linear cost coefficient (dollars per MW)
  - `coffi_c::Vector{Float64}`: Constant cost coefficient (dollars)

## Cold Start Cost Coefficients

  - `coffi_cold_shutup_1::Vector{Float64}`: Cold start cost coefficient 1
  - `coffi_cold_shutup_2::Vector{Float64}`: Cold start cost coefficient 2
  - `coffi_cold_shutdown_1::Vector{Float64}`: Cold shutdown cost coefficient 1
  - `coffi_cold_shutdown_2::Vector{Float64}`: Cold shutdown cost coefficient 2

## Frequency Control Parameters

  - `Hg::Vector{Float64}`: Inertia constant (seconds)
  - `Dg::Vector{Float64}`: Damping constant
  - `Kg::Vector{Float64}`: Mechanical power gain    # Basic unit parameters
  - `Fg::Vector{Float64}`: Fraction of power from turbine
  - `Tg::Vector{Float64}`: Time constant (seconds)
  - `Rg::Vector{Float64}`: Droop gain (Hz/MW)
"""
mutable struct unit
	# Basic unit parameters
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	ramp_up::Vector{Float64}
	ramp_down::Vector{Float64}

	# Commitment parameters
	shut_up::Vector{Float64}
	shut_down::Vector{Float64}
	min_shutup_time::Vector{Float64}
	min_shutdown_time::Vector{Float64}

	# Initial conditions
	x_0::Vector{Float64}
	t_0::Vector{Float64}
	t_1::Vector{Float64}
	p_0::Vector{Float64}

	# Cost function coefficients (quadratic: a*p² + b*p + c)
	coffi_a::Vector{Float64}
	coffi_b::Vector{Float64}
	coffi_c::Vector{Float64}

	# Cold start cost coefficients
	coffi_cold_shutup_1::Vector{Float64}
	coffi_cold_shutup_2::Vector{Float64}
	coffi_cold_shutdown_1::Vector{Float64}
	coffi_cold_shutdown_2::Vector{Float64}

	# Frequency control parameters
	Hg::Vector{Float64}  # Inertia constant
	Dg::Vector{Float64}  # Damping constant
	Kg::Vector{Float64}  # Mechanical power gain
	Fg::Vector{Float64}  # Fraction of power from turbine
	Tg::Vector{Float64}  # Time constant
	Rg::Vector{Float64}  # Droop gain

	function unit(
			index, locatebus, p_max, p_min, ramp_up, ramp_down, shut_up, shut_down, min_shutup_time, min_shutdown_time, x_0, t_0, t_1, p_0, coffi_a,
			coffi_b, coffi_c, coffi_cold_shutup_1, coffi_cold_shutup_2, coffi_cold_shutdown_1, coffi_cold_shutdown_2, Hg, Dg, Kg, Fg, Tg, Rg
	)
		return new(
			index, locatebus, p_max, p_min, ramp_up, ramp_down, shut_up, shut_down, min_shutup_time, min_shutdown_time, x_0, t_0, t_1, p_0, coffi_a,
			coffi_b, coffi_c, coffi_cold_shutup_1, coffi_cold_shutup_2, coffi_cold_shutdown_1, coffi_cold_shutdown_2, Hg, Dg, Kg, Fg, Tg, Rg
		)
	end
end

# ============================================================================
# Transmission Line Structure
# ============================================================================
"""
	transmissionline

Transmission line data structure for network constraints.

# Fields

  - `index::Vector{Int64}`: Line indices
  - `from::Vector{Int64}`: From bus indices
  - `to::Vector{Int64}`: To bus indices
  - `x::Vector{Float64}`: Line reactance (p.u.)
  - `p_max::Vector{Float64}`: Maximum power flow limit (MW)
  - `p_min::Vector{Float64}`: Minimum power flow limit (MW, typically negative of p_max)
"""
mutable struct transmissionline
	index::Vector{Int64}
	from::Vector{Int64}
	to::Vector{Int64}
	x::Vector{Float64}      # Reactance
	p_max::Vector{Float64}  # Maximum power flow
	p_min::Vector{Float64}  # Minimum power flow

	function transmissionline(index, from, to, x, p_max, p_min)
		return new(index, from, to, x, p_max, p_min)
	end
end

# ============================================================================
# Load Structure
# ============================================================================
"""
	load

Load data structure for demand modeling.

# Fields

  - `index::Vector{Int64}`: Load indices
  - `locatebus::Vector{Int64}`: Bus location of each load
  - `load_curve::Array{Float64}`: Load curve matrix (ND × NT) - demand at each time period
"""
mutable struct load
	index::Vector{Int64}
	locatebus::Vector{Int64}
	load_curve::Array{Float64}

	function load(index, locatebus, load_curve)
		return new(index, locatebus, load_curve)
	end
end

# ============================================================================
# Energy Storage System (ESS) Structure
# ============================================================================
"""
	pss

Power Storage System (PSS) / Battery Energy Storage System (BESS) data structure.

# Fields

  - `index::Vector{Int64}`: Storage unit indices
  - `locatebus::Vector{Int64}`: Bus location of each storage unit
  - `Q_max::Vector{Float64}`: Maximum energy capacity (MWh)
  - `Q_min::Vector{Float64}`: Minimum energy capacity (MWh, typically 0)
  - `p⁺::Vector{Float64}`: Maximum charging power (MW)
  - `p⁻::Vector{Float64}`: Maximum discharging power (MW)
  - `P₀::Vector{Float64}`: Initial energy state (MWh)
  - `γ⁺::Vector{Float64}`: Charging cost coefficient (dollars per MWh)
  - `γ⁻::Vector{Float64}`: Discharging cost coefficient (dollars per MWh)
  - `η⁺::Vector{Float64}`: Charging efficiency (0-1)
  - `η⁻::Vector{Float64}`: Discharging efficiency (0-1)
  - `δₛ::Vector{Float64}`: Self-discharge rate (per hour)
"""
mutable struct pss
	index::Vector{Int64}
	locatebus::Vector{Int64}
	Q_max::Vector{Float64}  # Maximum energy capacity
	Q_min::Vector{Float64}  # Minimum energy capacity
	p⁺::Vector{Float64}     # Maximum charging power
	p⁻::Vector{Float64}     # Maximum discharging power
	P₀::Vector{Float64}     # Initial energy state
	γ⁺::Vector{Float64}     # Charging cost coefficient
	γ⁻::Vector{Float64}     # Discharging cost coefficient
	η⁺::Vector{Float64}     # Charging efficiency
	η⁻::Vector{Float64}     # Discharging efficiency
	δₛ::Vector{Float64}     # Self-discharge rate

	function pss(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ)
		return new(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ)
	end
end

# ============================================================================
# Data Center Structure
# ============================================================================
"""
	data_centra

Data center structure for modeling flexible data center power consumption.

# Fields

  - `index::Vector{Int64}`: Data center indices
  - `locatebus::Vector{Int64}`: Bus location of each data center
  - `p_max::Vector{Float64}`: Maximum power consumption (MW)
  - `p_min::Vector{Float64}`: Minimum power consumption (MW)
  - `voltage_regulation::Vector{Float64}`: Voltage regulation capability
  - `idale::Vector{Float64}`: Idle power consumption (MW)
  - `sv_constant::Vector{Float64}`: Service constant parameter
  - `λ::Vector{Float64}`: Dual variable for power consumption
  - `μ::Vector{Float64}`: Dual variable for computational tasks
  - `computational_power_tasks::Matrix{Float64}`: Computational task matrix
"""
mutable struct data_centra
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	voltage_regulation::Vector{Float64}
	idale::Vector{Float64}
	sv_constant::Vector{Float64}
	λ::Vector{Float64}
	μ::Vector{Float64}
	computational_power_tasks::Matrix{Float64}

	function data_centra(
			index, locatebus, p_max, p_min, voltage_regulation, idale, sv_constant, λ, μ, computational_power_tasks
	)
		return new(
			index, locatebus, p_max, p_min, voltage_regulation, idale, sv_constant, λ, μ, computational_power_tasks
		)
	end
end

# ============================================================================
# Hydroelectric Unit Structure
# ============================================================================
"""
	hydro

Hydroelectric unit data structure.

# Fields

  - `index::Vector{Int64}`: Hydro unit indices
  - `locatebus::Vector{Int64}`: Bus location of each hydro unit
  - `p_max::Vector{Float64}`: Maximum power output (MW)
  - `p_min::Vector{Float64}`: Minimum power output (MW)
  - `q_max::Vector{Float64}`: Maximum water discharge rate (m³/s)
  - `q_0::Vector{Float64}`: Initial water discharge rate (m³/s)
  - `reservoircurve::Array{Float64}`: Reservoir curve data (water level vs. storage)
"""
mutable struct hydro
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	q_max::Vector{Float64}
	q_0::Vector{Float64}
	reservoircurve::Array{Float64}

	function hydro(index, locatebus, p_max, p_min, q_max, q_0, reservoircurve)
		return new(index, locatebus, p_max, p_min, q_max, q_0, reservoircurve)
	end
end
