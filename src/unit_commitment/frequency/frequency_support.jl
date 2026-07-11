function safe_frequency_coeff(values, index::Int64; default::Float64 = 0.0)
    if values === nothing || index > length(values)
        return default
    end
    value = Float64(values[index])
    return isfinite(value) ? value : default
end

function unit_primary_response_coeff(units, index::Int64)
    kg = safe_frequency_coeff(units.Kg, index)
    rg = safe_frequency_coeff(units.Rg, index; default = 1.0)
    if abs(rg) <= eps(Float64)
        return 0.0
    end
    return max(0.0, kg / rg)
end

function unit_turbine_response_coeff(units, index::Int64)
    return unit_primary_response_coeff(units, index) * safe_frequency_coeff(units.Fg, index)
end

function wind_frequency_capacity_support(winds)
    if winds === nothing
        return (inertia = 0.0, damping = 0.0, primary = 0.0)
    end
    NW = length(winds.index)
    return (
        inertia = sum(wind_virtual_inertia_coeff(winds, w) * safe_frequency_coeff(winds.p_max, w) for w in 1:NW),
        damping = sum(wind_virtual_damping_coeff(winds, w) * safe_frequency_coeff(winds.p_max, w) for w in 1:NW),
        primary = sum(wind_droop_response_coeff(winds, w) * safe_frequency_coeff(winds.p_max, w) for w in 1:NW),
    )
end

function frequency_sum_apparent_power(units, winds)
    wind_capacity = winds === nothing ? 0.0 : sum(winds.p_max)
    return max(sum(units.p_max) + wind_capacity, eps(Float64))
end

function wind_virtual_inertia_coeff(winds, wind_index::Int64)
    return wind_frequency_mode(winds, wind_index) >= 0.5 ? max(0.0, safe_frequency_coeff(winds.Mw, wind_index)) : 0.0
end

function wind_virtual_damping_coeff(winds, wind_index::Int64)
    return wind_frequency_mode(winds, wind_index) >= 0.5 ? max(0.0, safe_frequency_coeff(winds.Dw, wind_index)) : 0.0
end

function wind_droop_response_coeff(winds, wind_index::Int64)
    if wind_frequency_mode(winds, wind_index) >= 0.5
        return 0.0
    end
    rw = safe_frequency_coeff(winds.Rw, wind_index; default = 1.0)
    if abs(rw) <= eps(Float64)
        return 0.0
    end
    return max(0.0, safe_frequency_coeff(winds.Kw, wind_index) / rw)
end

function wind_frequency_mode(winds, wind_index::Int64)
    return safe_frequency_coeff(winds.Fcmode, wind_index; default = 0.0)
end
