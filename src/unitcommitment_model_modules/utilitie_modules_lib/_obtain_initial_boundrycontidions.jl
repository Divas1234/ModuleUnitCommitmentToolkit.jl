"""
    calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

Calculate Generation Shift Distribution Factors (GSDF) for transmission network.

GSDF represents the sensitivity of line flows to power injections at each bus.
This is used for linearized DC power flow constraints in the optimization model.

# Arguments

  - `config_param::config`: Configuration parameters with `is_NetWorkCon` flag
  - `NL::Int`: Number of transmission lines
  - `units::unit`: Generator unit data
  - `lines::transmissionline`: Transmission line data
  - `loads::load`: Load data
  - `NG::Int`: Number of generators
  - `NB::Int`: Number of buses
  - `ND::Int`: Number of loads

# Returns

  - `Gsdf::Union{Matrix{Float64}, Nothing}`: GSDF matrix (NL × NB) or nothing if network
    constraints are disabled or no lines exist

# Note

Returns `nothing` if network constraints are disabled (`is_NetWorkCon != 1`)
or if there are no transmission lines (`NL == 0`).
"""
function calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)
    Gsdf = nothing  # Initialize as nothing (will be set if network constraints enabled)

    if config_param.is_NetWorkCon == 1
        if NL > 0  # Ensure lines exist before calculating power flow
            Adjacmatrix_BtoG, Adjacmatrix_B2D, Gsdf = linearpowerflow(units, lines, loads, NG, NB, ND, NL)
        else
            println("Warning: Network constraints enabled (is_NetWorkCon=1), but NL=0. Skipping Gsdf calculation.",)
        end
    end

    return Gsdf
end

"""
    calculate_initial_unit_status(units, NG)

Calculate initial on/off status for all generator units.

This function determines the initial commitment state of each generator based
on the `units.x_0` field, which represents the initial state from the previous
time period or initial conditions.

# Arguments

  - `units::unit`: Generator unit data with `x_0` field (initial status)
  - `NG::Int`: Number of generators

# Returns

  - `onoffinit::Vector{Int}`: Initial on/off status (1 = on, 0 = off) for each generator

# Algorithm

  - If `units.x_0[i] > 0.5`, unit i is considered initially on (status = 1)
  - Otherwise, unit i is considered initially off (status = 0)
  - If `units.x_0` is empty or invalid, all units are assumed to start offline

# Example

```julia
initial_status = calculate_initial_unit_status(units, 10)
# Returns: [1, 0, 1, 0, ...] indicating which units are initially on
```
"""
function calculate_initial_unit_status(units, NG)
    onoffinit = zeros(NG, 1)

    if !isempty(units.x_0) && size(units.x_0, 1) == NG
        # Convert continuous initial state to binary (threshold at 0.5)
        for i ∈ 1:NG
            onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
        end
    else
        println("Warning: Initial unit status units.x_0 not found or invalid. Assuming all units start offline (onoffinit=0).",)
    end

    return onoffinit
end

"""
    define_contingency_size(units, NG)

Define the size of the largest credible contingency for frequency control.

This function calculates the maximum power loss that could occur from a single
generator outage, which is used in frequency response constraints.

# Arguments

  - `units::unit`: Generator unit data with `p_max` field
  - `NG::Int`: Number of generators

# Returns

  - `Δp_contingency::Float64`: Contingency size (MW), typically 30% of the largest unit capacity

# Algorithm

  - Finds the maximum generator capacity
  - Sets contingency size to 30% of this maximum
  - Returns 0.0 if there are no generators (NG == 0)

# Note

The 30% factor is a typical assumption for N-1 contingency analysis.
This can be adjusted based on system requirements.
"""
function define_contingency_size(units, NG)
    # Calculate contingency as 30% of largest unit capacity
    # This represents the maximum credible single generator outage
    Δp_contingency = (NG > 0) ? maximum(units.p_max[:, 1]) * 0.3 : 0.0

    return Δp_contingency
end
