function frequency_nadir_sampling_dataset(units, winds, contingency::Float64)
    NG = length(units.index)
    states = frequency_commitment_samples(NG)
    X = zeros(Float64, length(states), 4)
    y = zeros(Float64, length(states))
    for (row, state) in enumerate(states)
        H, R, D, F, T = aggregate_littlecase_frequency_parameters(units, winds, state)
        X[row, :] = [
            littlecase_inertia_feature(units, winds, state),
            littlecase_fg_response_feature(units, state),
            littlecase_primary_response_feature(units, state),
            1.0,
        ]
        y[row] = littlecase_frequency_nadir(H, R, D, F, T, contingency)
    end
    return X, y
end

function frequency_commitment_samples(NG::Int64)
    states = Vector{Vector{Float64}}()
    for mask in 0:(2 ^ NG - 1)
        state = [Float64((mask >> (i - 1)) & 1) for i in 1:NG]
        state[1] = 1.0
        push!(states, state)
    end
    return states
end

function aggregate_littlecase_frequency_parameters(units, winds, state)
    unit_capacity = max(sum(units.p_max), eps(Float64))
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    thermal_power = units.p_max .* state
    current_Hg = sum(units.Hg .* thermal_power) / unit_capacity
    current_Rg = 1.0 / max(sum((units.Kg ./ units.Rg) .* thermal_power) / unit_capacity, eps(Float64))
    current_Fg = (sum((units.Kg .* units.Fg ./ units.Rg) .* thermal_power) / unit_capacity) * current_Rg
    wind_support = wind_frequency_capacity_support(winds)
    H = (sum((2.0 * current_Hg) .* thermal_power) + wind_support.inertia) / sum_apparent_power / 2.0
    D = (sum(units.Dg .* thermal_power) + wind_support.damping + wind_support.primary) / sum_apparent_power
    T = mean(units.Tg)
    return H, current_Rg, D, current_Fg, T
end

function littlecase_frequency_nadir(H::Float64, R::Float64, D::Float64, F::Float64, T::Float64, contingency::Float64)
    if H <= eps(Float64) || R <= eps(Float64) || T <= eps(Float64)
        return Inf
    end
    ω_n = sqrt(max((D * R + 1.0) / (2.0 * H * R * T), eps(Float64)))
    ζ = (D * R * T + 2.0 * H * R + F * T) / (2.0 * (D * R + 1.0)) * ω_n
    if ζ >= 1.0
        return contingency * R / (D * R + 1.0)
    end
    ω_r = ω_n * sqrt(max(1.0 - ζ^2, eps(Float64)))
    α = sqrt(max((1.0 - 2.0 * T * ζ * ω_n + (T * ω_r)^2) / (1.0 - ζ^2), 0.0))
    t_nadir = abs((1.0 / ω_r) * atan((ω_r * T) / (ζ * ω_r * T - 1.0)))
    return contingency * R / (D * R + 1.0) * (1.0 + sqrt(1.0 - ζ^2) * α * exp(-ζ * ω_n * t_nadir))
end

function littlecase_inertia_feature(units, winds, state)
    return (sum(units.Hg .* units.p_max .* state) + wind_frequency_capacity_support(winds).inertia) / frequency_sum_apparent_power(units, winds)
end

function littlecase_fg_response_feature(units, state)
    return sum((units.Kg .* units.Fg ./ units.Rg) .* units.p_max .* state) / max(sum(units.p_max), eps(Float64))
end

function littlecase_primary_response_feature(units, state)
    return sum((units.Kg ./ units.Rg) .* units.p_max .* state) / max(sum(units.p_max), eps(Float64))
end
