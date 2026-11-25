function frequency_nadir_sampling_dataset(units, winds, contingency::Float64)
    NG = length(units.index)
    states = frequency_commitment_samples(NG)
    f0_hz = frequency_env_float("FREQUENCY_BASE_HZ", 50.0)
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    delta_p_pu = contingency / sum_apparent_power
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
        y[row] = littlecase_frequency_nadir(H, R, D, F, T, delta_p_pu; f0_hz = f0_hz)
    end
    finite_mask = [isfinite(y[r]) && all(isfinite, @view X[r, :]) for r in axes(X, 1)]
    if any(finite_mask)
        return X[finite_mask, :], y[finite_mask]
    end
    return X, fill(f0_hz * delta_p_pu, length(y))
end

function frequency_commitment_samples(NG::Int64)
    states = Vector{Vector{Float64}}()
    if NG <= 0
        return states
    elseif NG <= 10
        for mask in 1:((Int64(1) << NG) - 1)
            push!(states, [Float64((mask >> (i - 1)) & 1) for i in 1:NG])
        end
    else
        # Stratified deterministic sampling for large fleets (avoids 2^NG blowup and Int64 overflow)
        push!(states, ones(Float64, NG))
        for k in 1:min(NG, 32)
            idx = round.(Int, range(1, NG; length = k))
            s = zeros(Float64, NG)
            s[idx] .= 1.0
            push!(states, s)
            s_comp = ones(Float64, NG)
            s_comp[idx] .= 0.0
            any(>(0.5), s_comp) && push!(states, s_comp)
        end
        for frac in (0.2, 0.35, 0.5, 0.65, 0.8, 0.9)
            n_on = clamp(round(Int, frac * NG), 1, NG)
            s = zeros(Float64, NG)
            s[1:n_on] .= 1.0
            push!(states, s)
            s_rev = zeros(Float64, NG)
            s_rev[(NG - n_on + 1):NG] .= 1.0
            push!(states, s_rev)
        end
        unique!(states)
    end
    return states
end

function aggregate_littlecase_frequency_parameters(units, winds, state)
    unit_capacity = max(sum(units.p_max), eps(Float64))
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    thermal_power = units.p_max .* state
    wind_support = wind_frequency_capacity_support(winds)
    H = (sum(units.Hg .* thermal_power) + 0.5 * wind_support.inertia) / sum_apparent_power
    K_eff = sum((units.Kg ./ max.(units.Rg, eps(Float64))) .* thermal_power) / sum_apparent_power
    current_Rg = K_eff > eps(Float64) ? 1.0 / K_eff : Inf
    current_Fg = K_eff > eps(Float64) ? (sum((units.Kg .* units.Fg ./ max.(units.Rg, eps(Float64))) .* thermal_power) / sum_apparent_power) / K_eff : 0.0
    D = (sum(units.Dg .* thermal_power) + wind_support.damping + wind_support.primary) / sum_apparent_power
    active_p = sum(thermal_power)
    T = active_p > eps(Float64) ? sum(units.Tg .* thermal_power) / active_p : mean(units.Tg)
    return H, current_Rg, D, current_Fg, T
end

function littlecase_frequency_nadir(H::Float64, R::Float64, D::Float64, F::Float64, T::Float64, delta_p_pu::Float64; f0_hz::Float64 = 50.0)
    if H <= eps(Float64) || !isfinite(R) || R <= eps(Float64) || T <= eps(Float64)
        return (D > eps(Float64) ? f0_hz * delta_p_pu / D : Inf)
    end
    K = 1.0 / R
    nadir_pu = hd_sfr_nadir_pu(H, D, K, T, clamp(F, 0.0, 0.999), delta_p_pu; include_overdamped = true)
    return isfinite(nadir_pu) ? f0_hz * nadir_pu : Inf
end

function littlecase_inertia_feature(units, winds, state)
    return (sum(units.Hg .* units.p_max .* state) + 0.5 * wind_frequency_capacity_support(winds).inertia) / frequency_sum_apparent_power(units, winds)
end

function littlecase_fg_response_feature(units, state)
    return sum((units.Kg .* units.Fg ./ units.Rg) .* units.p_max .* state) / max(sum(units.p_max), eps(Float64))
end

function littlecase_primary_response_feature(units, state)
    return sum((units.Kg ./ units.Rg) .* units.p_max .* state) / max(sum(units.p_max), eps(Float64))
end
