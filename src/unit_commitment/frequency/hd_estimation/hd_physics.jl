"""
    hd_estimation/hd_physics.jl

Single source of truth for second-order System Frequency Response (SFR) physics
used by the Inertia–Damping (H–D) Frequency Security Region (FRSR) module.

Adapted from `frequencyregions/src/common/frequency_physics.jl` with zero
external solver/plotting dependencies.

Conventions
-----------
- Swing equation: `2H dΔf/dt = ΔPm − DΔf − ΔP`.
- `H` is the inertia constant in seconds on the system apparent power base.
- `Δf` is per-unit frequency deviation (`Hz = pu * f0`, default `f0 = 50.0` Hz).
- `ΔP`, `D`, and primary droop gain `K = 1/R` are per-unit on the same base.
- `F_H ∈ [0, 1)` is the dimensionless high-pressure turbine fraction in
  `ΔPm/Δf = −K (1 + F_H T s) / (1 + T s)`.
- Thresholds: `rocof_threshold` in Hz/s, `nadir_threshold` / `qss_threshold` in Hz.
"""

const HD_DEFAULT_FREQUENCY_BASE_HZ = 50.0

"""
    hd_rocof_min_inertia(power_deviation, rocof_threshold; f0 = 50.0) -> Float64

Minimum total effective inertia `H_min` (s) so that initial RoCoF does not exceed
`rocof_threshold` (Hz/s): `RoCoF_0 = f0 * ΔP / (2H) <= RoCoF_max`.
"""
function hd_rocof_min_inertia(power_deviation::Real, rocof_threshold::Real; f0::Real = HD_DEFAULT_FREQUENCY_BASE_HZ)
    rocof_threshold > 0 || throw(ArgumentError("rocof_threshold must be positive (Hz/s); got $(rocof_threshold)"))
    power_deviation >= 0 || throw(ArgumentError("power_deviation must be non-negative (pu); got $(power_deviation)"))
    return Float64(f0) * Float64(power_deviation) / (2.0 * Float64(rocof_threshold))
end

"""
    hd_rocof_min_inertia_axis(power_deviation, rocof_threshold, H_vsm; f0 = 50.0) -> Float64

Minimum synchronous inertia `H_sync` (s) when grid-forming/VSM converters provide
`H_vsm` (s) on the same base: `H_sync >= max(0, H_min - H_vsm)`.
"""
function hd_rocof_min_inertia_axis(
    power_deviation::Real,
    rocof_threshold::Real,
    H_vsm::Real;
    f0::Real = HD_DEFAULT_FREQUENCY_BASE_HZ,
)
    return max(0.0, hd_rocof_min_inertia(power_deviation, rocof_threshold; f0 = f0) - Float64(H_vsm))
end

"""
    hd_qss_min_damping(power_deviation, qss_threshold_hz, K; f0 = 50.0) -> Float64

Minimum total effective damping `D_min` (pu) required to satisfy the quasi-steady-state
frequency deviation limit `Δf_qss = f0 * ΔP / (D + K) <= qss_threshold_hz`.
"""
function hd_qss_min_damping(
    power_deviation::Real,
    qss_threshold_hz::Real,
    K::Real;
    f0::Real = HD_DEFAULT_FREQUENCY_BASE_HZ,
)
    qss_threshold_hz > 0 || throw(ArgumentError("qss_threshold_hz must be positive (Hz); got $(qss_threshold_hz)"))
    power_deviation >= 0 || throw(ArgumentError("power_deviation must be non-negative (pu); got $(power_deviation)"))
    return max(0.0, Float64(f0) * Float64(power_deviation) / Float64(qss_threshold_hz) - Float64(K))
end

"""
    hd_nadir_threshold_pu(nadir_threshold_hz; f0 = 50.0) -> Float64

Convert a maximum frequency deviation limit from Hz to per-unit.
"""
function hd_nadir_threshold_pu(nadir_threshold_hz::Real; f0::Real = HD_DEFAULT_FREQUENCY_BASE_HZ)
    return Float64(nadir_threshold_hz) / Float64(f0)
end

"""
    hd_sfr_damping_parameters(H, D, K, T, F_H) -> (ζ, ωn)

Damping ratio `ζ` and natural frequency `ωn` (rad/s) of the second-order SFR model
`Δf/ΔP = -(1/(2HT)) (1 + Ts) / (s^2 + 2ζωn s + ωn^2)`.
"""
function hd_sfr_damping_parameters(H::Real, D::Real, K::Real, T::Real, F_H::Real)
    Hf = Float64(H)
    Df = Float64(D)
    Kf = Float64(K)
    Tf = Float64(T)
    Ff = Float64(F_H)
    ωn = sqrt((Df + Kf) / (2.0 * Hf * Tf))
    ζ = (2.0 * Hf + Tf * (Df + Kf * Ff)) / (2.0 * sqrt(2.0 * Hf * Tf * (Df + Kf)))
    return ζ, ωn
end

"""
    hd_sfr_underdamped_window(D, K, T, F_H) -> (H_lower, H_upper)

Inertia interval `(H_lower, H_upper)` on which the second-order SFR model is
under-damped (`ζ < 1`), i.e., the validity domain of the closed-form oscillatory
nadir formula. For `H >= H_upper`, the response is over-damped and the frequency
deviation is bounded by the quasi-steady-state value `ΔP / (D + K)`.
"""
function hd_sfr_underdamped_window(D::Real, K::Real, T::Real, F_H::Real)
    Df = Float64(D)
    Kf = Float64(K)
    Tf = Float64(T)
    Ff = Float64(F_H)
    (0.0 <= Ff < 1.0) || throw(ArgumentError("F_H must be in [0, 1); got $(F_H)"))
    Tf > 0.0 || throw(ArgumentError("T must be positive; got $(T)"))
    Kf > 0.0 || throw(ArgumentError("K must be positive; got $(K)"))
    a = Df - Kf * Ff + 2.0 * Kf
    b = a^2 - (Df + Kf * Ff)^2
    b >= 0.0 || throw(DomainError(b, "No under-damped SFR window (requires F_H < 1 and K > 0)."))
    sqrt_b = sqrt(b)
    return Tf * (a - sqrt_b) / 2.0, Tf * (a + sqrt_b) / 2.0
end

"""
    hd_sfr_nadir_time(H, D, K, T, F_H) -> Float64

Time `t_n > 0` (s) of the frequency nadir for an under-damped SFR response,
using `atan(ωd * T, ζ * ωn * T - 1) / ωd` to stay in `(0, π) / ωd`.
Returns `NaN` when `ζ >= 1`.
"""
function hd_sfr_nadir_time(H::Real, D::Real, K::Real, T::Real, F_H::Real)
    ζ, ωn = hd_sfr_damping_parameters(H, D, K, T, F_H)
    (isfinite(ζ) && ζ < 1.0) || return NaN
    ωd = ωn * sqrt(1.0 - ζ^2)
    return atan(ωd * Float64(T), ζ * ωn * Float64(T) - 1.0) / ωd
end

"""
    hd_sfr_nadir_pu(H, D, K, T, F_H, ΔP; include_overdamped = true) -> Float64

Maximum frequency deviation (pu, positive) of the second-order SFR model after a
step power imbalance `ΔP` (pu).

- For `ζ < 1` (under-damped): exact closed-form nadir
  `ΔP/(D + K) * (1 + sqrt(T * K * (1 - F_H) / (2H)) * exp(-ζ * ωn * t_n))`.
- For `ζ >= 1` (over-damped): returns the quasi-steady-state value `ΔP / (D + K)`
  when `include_overdamped == true`, or `NaN` when `include_overdamped == false`.
"""
function hd_sfr_nadir_pu(
    H::Real,
    D::Real,
    K::Real,
    T::Real,
    F_H::Real,
    ΔP::Real;
    include_overdamped::Bool = true,
)
    Hf = Float64(H)
    Df = Float64(D)
    Kf = Float64(K)
    Tf = Float64(T)
    Ff = Float64(F_H)
    dP = Float64(ΔP)
    (Hf > 0.0 && Tf > 0.0 && Df >= 0.0 && Kf > 0.0 && 0.0 <= Ff < 1.0 && dP >= 0.0) || return NaN
    ζ, ωn = hd_sfr_damping_parameters(Hf, Df, Kf, Tf, Ff)
    isfinite(ζ) || return NaN
    if ζ >= 1.0
        include_overdamped || return NaN
        # Exact over-damped (ζ >= 1) peak:
        # - For large inertia (H >= H_upper): monotonic approach to QSS ΔP / (D + K).
        # - For small inertia (H <= H_lower): both real poles lie left of -1/T, causing
        #   a finite-time peak above QSS at t_n = log((1 + r2*T)/(1 + r1*T)) / (r1 - r2).
        qss = dP / (Df + Kf)
        if ζ > 1.0 + 1.0e-12
            rad = sqrt(ζ^2 - 1.0)
            r1 = -ωn * (ζ - rad)
            r2 = -ωn * (ζ + rad)
            num = 1.0 + r2 * Tf
            den = 1.0 + r1 * Tf
            if num < 0.0 && den < 0.0 && (num / den) > 1.0
                t_n = log(num / den) / (r1 - r2)
                return qss * (1.0 + (r2 * den * exp(r1 * t_n) - r1 * num * exp(r2 * t_n)) / (r1 - r2))
            end
        elseif abs(ωn * Tf) > 1.0 + 1.0e-12
            # Critically damped (ζ == 1) small-inertia branch: double pole at -ωn < -1/T
            t_n = 1.0 / ωn + 1.0 / (ωn * (ωn * Tf - 1.0))
            return qss * (1.0 + (ωn * Tf - 1.0) * exp(-ωn * t_n))
        end
        return qss
    end
    t_n = hd_sfr_nadir_time(Hf, Df, Kf, Tf, Ff)
    return dP / (Df + Kf) * (1.0 + sqrt(Tf * Kf * (1.0 - Ff) / (2.0 * Hf)) * exp(-ζ * ωn * t_n))
end

"""
    hd_effective_nadir_pu(H_sync, D_sync, K, T, F_H, ΔP; H_vsm = 0.0, D_vsm = 0.0, K_conv = 0.0, include_overdamped = true) -> Float64

Evaluate maximum frequency deviation (pu) when grid-forming/VSM and droop-controlled
converters contribute virtual inertia `H_vsm`, virtual damping `D_vsm`, and converter
droop gain `K_conv = 1/R_conv`.
"""
function hd_effective_nadir_pu(
    H_sync::Real,
    D_sync::Real,
    K::Real,
    T::Real,
    F_H::Real,
    ΔP::Real;
    H_vsm::Real = 0.0,
    D_vsm::Real = 0.0,
    K_conv::Real = 0.0,
    include_overdamped::Bool = true,
)
    H_eff = Float64(H_sync) + Float64(H_vsm)
    D_eff = Float64(D_sync) + Float64(D_vsm) + Float64(K_conv)
    return hd_sfr_nadir_pu(H_eff, D_eff, K, T, F_H, ΔP; include_overdamped = include_overdamped)
end
