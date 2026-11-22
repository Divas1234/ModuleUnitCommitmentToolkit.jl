"""
	validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, psses, scenarios_prob, NL)

Validates the input dimensions and data consistency for the SUC model.

# Returns

  - `Bool`: True if all checks pass, false otherwise.
"""
function validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, psses, scenarios_prob, NL)
    if NT <= 0 || NB <= 0 || NG <= 0
        @warn "Core dimensions must be positive: got NT=$NT, NB=$NB, NG=$NG."
        return false
    end

    if ND < 0 || NC < 0 || ND2 < 0 || NL < 0
        @warn "Entity counts must be non-negative: got ND=$ND, NC=$NC, ND2=$ND2, NL=$NL."
        return false
    end

    if !(isfinite(scenarios_prob) && 0.0 < scenarios_prob <= 1.0)
        @warn "Scenario probability `scenarios_prob` ($scenarios_prob) must be in (0, 1]."
        return false
    end

    # Generator dimensions
    if length(units.index) != NG || length(units.p_max) != NG || length(units.p_min) != NG
        @warn "Number of generators in `units` (index=$(length(units.index)), p_max=$(length(units.p_max)), p_min=$(length(units.p_min))) does not match NG ($NG)."
        return false
    end

    # Load dimensions
    if length(loads.index) != ND
        @warn "Number of loads in `loads.index` ($(length(loads.index))) does not match ND ($ND)."
        return false
    end
    if ND > 0 && (size(loads.load_curve, 1) != ND || size(loads.load_curve, 2) < NT)
        @warn "Load curve dimensions ($(size(loads.load_curve))) are incompatible with ND=$ND, NT=$NT."
        return false
    end

    # Wind dimensions
    NW = length(winds.index)
    if length(winds.locatebus) != NW || length(winds.p_max) != NW
        @warn "Wind metadata lengths (locatebus=$(length(winds.locatebus)), p_max=$(length(winds.p_max))) do not match NW ($NW)."
        return false
    end
    if winds.scenarios_nums <= 0
        @warn "Number of wind scenarios `winds.scenarios_nums` ($(winds.scenarios_nums)) must be positive."
        return false
    end

    # Transmission line dimensions
    if NL > 0 && (length(lines.index) != NL || length(lines.from) != NL || length(lines.to) != NL || length(lines.p_max) != NL)
        @warn "Transmission line dimensions (index=$(length(lines.index)), from=$(length(lines.from)), to=$(length(lines.to)), p_max=$(length(lines.p_max))) do not match NL ($NL)."
        return false
    end

    # Storage dimensions
    if NC > 0
        if psses === nothing || !hasproperty(psses, :index) || length(psses.index) != NC
            @warn "Storage input `psses` is missing or its index length does not match NC ($NC)."
            return false
        end
    end

    # Data center dimensions
    if ND2 > 0
        if data_centers === nothing || !hasproperty(data_centers, :index) || length(data_centers.index) != ND2
            @warn "Data center input `data_centers` is missing or its index length does not match ND2 ($ND2)."
            return false
        end
    end

    return true
end

if isdefined(@__MODULE__, :UCProblemData)
    function validate_inputs(data::UCProblemData; scenarios_prob::Float64 = 1.0 / max(1, data.NS))
        return validate_inputs(
            data.NT, data.NB, data.NG, data.ND, data.NC, data.ND2,
            data.units, data.loads, data.winds, data.lines, data.data_centers,
            data.config_param, data.storages, scenarios_prob, data.NL,
        )
    end
end
