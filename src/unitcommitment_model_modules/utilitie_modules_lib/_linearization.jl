"""
    linearizationfuelcurve(units, NG)

Linearize the quadratic fuel cost curve for generators into piecewise linear segments.

This function approximates the quadratic cost function `C(p) = a*p² + b*p + c`
using a 3-segment piecewise linear approximation. This linearization is necessary
for mixed-integer linear programming (MILP) solvers.

# Arguments

  - `units`: Generator unit data structure containing:
      + `p_min`: Minimum power output (MW)
      + `p_max`: Maximum power output (MW)
      + `coffi_a`: Quadratic coefficient (a) in cost function
      + `coffi_b`: Linear coefficient (b) in cost function
      + `coffi_c`: Constant coefficient (c) in cost function
  - `NG::Int`: Number of generators

# Returns

  - `refcost::Vector{Float64}`: Reference cost at minimum power output for each generator
  - `eachslope::Matrix{Float64}`: Slope of each linear segment (NG × 3 matrix)

# Algorithm

 1. Divide the power range [p_min, p_max] into 3 equal segments
 2. Calculate cost at 4 breakpoints (p_min, p_min+Δ, p_min+2Δ, p_max)
 3. Compute slopes between consecutive breakpoints

# Example

```julia
refcost, slopes = linearizationfuelcurve(units, 10)
# refcost: 10-element vector of baseline costs
# slopes: 10×3 matrix of segment slopes
```
"""
function linearizationfuelcurve(units, NG)
    # Calculate power increment for each linear segment
    # Divide power range into 3 equal segments
    linearpower_limits = (units.p_max - units.p_min) ./ 3

    # Initialize cost matrix: 4 breakpoints for each generator
    cost = zeros(NG, 4)

    # Calculate cost at minimum power (first breakpoint)
    temp = units.p_min
    cost[:, 1] = units.coffi_a .* (units.p_min .^ 2) + units.coffi_b .* units.p_min + units.coffi_c

    # Calculate cost at remaining 3 breakpoints
    for i ∈ 2:4
        temp = temp + linearpower_limits
        cost[:, i] = units.coffi_a .* (temp .^ 2) + units.coffi_b .* temp + units.coffi_c
    end

    # Calculate slopes for each of the 3 linear segments
    eachslope = zeros(NG, 3)
    for i ∈ 1:3
        # Slope = (cost[i+1] - cost[i]) / power_increment
        eachslope[:, i] = (cost[:, i + 1] - cost[:, i]) ./ linearpower_limits
    end

    # Return reference cost (at p_min) and slopes matrix (transposed for convenience)
    return cost[:, 1], eachslope'
end
