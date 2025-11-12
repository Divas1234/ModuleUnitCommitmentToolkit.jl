# ============================================================================
# Stochastic Simulation Module for Renewable Energy
#
# This module provides functions for generating stochastic scenarios of
# renewable energy production (wind, solar) for use in stochastic optimization.
# ============================================================================

include("_renewableenergysimulation.jl")

"""
    genscenario(WindsFreqParam, flag)

Generate wind power scenarios for stochastic unit commitment optimization.

This function creates multiple scenarios of wind power production based on
either random sampling (flag=1) or predefined scenarios (flag=0).

# Arguments
- `WindsFreqParam::Matrix{Float64}`: Wind frequency control parameters matrix
  with columns: [Fcmode, Kw, Rw, Mw, Dw, Tw]
- `flag::Int`: Scenario generation mode
  - `flag = 1`: Generate random scenarios using Weibull distribution
  - `flag = 0`: Use predefined deterministic scenarios

# Returns
- `winds::wind`: Wind data structure containing:
  - `index`: Wind farm indices
  - `locatebus`: Bus locations
  - `p_max`: Maximum wind power capacity
  - `scenarios_prob`: Probability of each scenario
  - `scenarios_nums`: Number of scenarios generated
  - `scenarios_curve`: Wind power scenarios matrix (NS × NT)
  - Frequency control parameters (Fcmode, Kw, Rw, Mw, Dw, Tw)
- `NW::Int`: Number of wind farms

# Example
```julia
winds, NW = genscenario(WindsFreqParam, 1)  # Random scenarios
winds, NW = genscenario(WindsFreqParam, 0)  # Deterministic scenarios
```
"""
# The actual implementation is in _renewableenergysimulation.jl
# This file just exports the function for use in other modules

export genscenario

println("\t→ The renewable energy scenarios module loaded.")
