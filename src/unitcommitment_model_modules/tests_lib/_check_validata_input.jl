"""
    validate_inputs(units, loads, winds, lines, DataCentras, config_param)

Validates the input data for the SUC model.

# Arguments

  - `units::unit`: Generator unit data
  - `loads::load`: Load data
  - `winds::wind`: Wind generation data
  - `lines::transmissionline`: Transmission line data
  - `DataCentras::data_centra`: Data center data
  - `config_param::config`: Configuration parameters

# Returns

  - `Bool`: True if all checks pass, false otherwise.
"""
function validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)
    # Check if the number of generators matches the expected value
    if size(units.p_max, 1) != NG
        @warn "Number of generators in `units` ($(size(units.p_max, 1))) does not match NG ($NG). This might lead to errors."
        return false
    end

    if size(loads.index, 1) != ND
        @warn "Number of loads in `loads` ($(length(loads.index))) does not match ND ($ND). This might lead to errors."
        return false
    end

    wind_farms = length(winds.index)
    if length(winds.p_max) != wind_farms
        @warn "Wind-farm indices ($wind_farms) and capacities ($(length(winds.p_max))) have inconsistent lengths."
        return false
    end
    if size(winds.scenarios_curve, 1) != winds.scenarios_nums || size(winds.scenarios_curve, 2) < NT
        @warn "Wind scenario matrix $(size(winds.scenarios_curve)) is inconsistent with scenarios_nums=$(winds.scenarios_nums) or NT=$NT."
        return false
    end

    if NL > 0 && size(lines.index, 1) != NL
        @warn "Number of transmission lines in `lines` ($(length(lines.index))) does not match NL ($NL). This might lead to errors."
        return false
    end

    # Implement other input validation logic here

    # Return true if all checks pass, false otherwise
    return true
end
