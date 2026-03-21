# ============================================================================
# Constraint library module for the unit commitment optimization model.
#
# This module acts as a central include point for all constraint modules and exports
# their constraint-adding functions. The constraints are organized by component type:
#
# Constraint Categories:
# - Generator constraints: Unit commitment, power limits, ramping, piecewise linear costs
# - System-wide constraints: Power balance, reserves, curtailment limits
# - Network constraints: Transmission line capacity limits
# - Storage constraints: Energy storage system operation limits
# - Data center constraints: Data center power consumption and flexibility
# - Frequency constraints: Frequency response and dynamic stability
# - Hydro constraints: Hydroelectric unit operation limits
#
# Exported Functions:
#   Generator Constraints (from `_constraint_generator.jl`):
#   - `add_unit_operation_constraints!`: Unit on/off status and minimum up/down time
#   - `add_generator_power_constraints!`: Power output limits
#   - `add_ramp_constraints!`: Ramping rate limits
#   - `add_pwl_constraints!`: Piecewise linear cost function constraints
#
#   Network Constraints (from `_constraint_network.jl`):
#   - `add_transmission_constraints!`: Transmission line capacity limits
#
#   Storage Constraints (from `_constraint_storage.jl`):
#   - `add_storage_constraints!`: Energy storage system operation constraints
#   - `add_hydros_constraints!`: Hydroelectric unit constraints
#
#   System-wide Constraints (from `_constraint_systemwide.jl`):
#   - `add_curtailment_constraints!`: Load and renewable curtailment limits
#   - `add_reserve_constraints!`: System reserve requirements
#   - `add_power_balance_constraints!`: Power balance at each bus
#   - `add_frequency_constraints!`: Frequency response constraints
#
#   Data Center Constraints (from `_constraint_datacentra.jl`):
#   - `add_datacentra_constraints!`: Data center power consumption and flexibility constraints
# ============================================================================

using JuMP

# ============================================================================
# Include constraint modules
# ============================================================================
include("_constraint_generator.jl")          # Generator unit constraints
include("_constraint_systemwide.jl")         # System-wide constraints
include("_constraint_network.jl")            # Transmission network constraints
include("_constraint_storage.jl")            # Energy storage constraints
include("_constraint_datacentra.jl")         # Data center constraints
include("_constraint_frequencydynamic.jl")   # Frequency dynamics constraints

# ============================================================================
# Export constraint functions
# ============================================================================
# Generator constraints
export add_unit_operation_constraints!,
    add_generator_power_constraints!, add_ramp_constraints!, add_pwl_constraints!

# Network constraints
export add_transmission_constraints!

# Storage constraints
export add_storage_constraints!, add_hydros_constraints!

# System-wide constraints
export add_curtailment_constraints!,
    add_reserve_constraints!, add_power_balance_constraints!, add_frequency_constraints!

# Data center constraints
export add_datacentra_constraints!

println("\t→ Constraint modules included and functions exported.")
