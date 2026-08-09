# ============================================================================
# Generator & Exporter: Stochastic Power Grid Load Curve (168 Hours)
#
# Features:
# 1. Day-to-day load profiles are intentionally different, not repeated copies.
# 2. Multi-scale uncertainty: daily energy shifts, random walk drift, and noise.
# 3. Explicit strong ramp events highlight the value of overlap look-ahead.
# ============================================================================

using XLSX, Random, Statistics

function read_base_load_curve(excel_path::String)
    xf = XLSX.readxlsx(excel_path)
    sh = xf["load_curve"]
    raw_vals = sh["B2:B$(size(sh[:], 1))"][:]
    vals = Float64.(filter(!ismissing, raw_vals))
    if isempty(vals)
        error("Sheet 'load_curve' in $excel_path does not contain any load values.")
    end
    return vals[1:min(24, length(vals))]
end

function ramp_pulse(hour::Int, start_hour::Int, rise_hours::Int, hold_hours::Int, fall_hours::Int, amplitude::Float64)
    rise_end = start_hour + rise_hours
    hold_end = rise_end + hold_hours
    fall_end = hold_end + fall_hours

    if hour < start_hour || hour >= fall_end
        return 0.0
    elseif hour < rise_end
        return amplitude * (hour - start_hour + 1) / rise_hours
    elseif hour < hold_end
        return amplitude
    else
        return amplitude * (1.0 - (hour - hold_end + 1) / fall_hours)
    end
end

function generate_stochastic_load_curve(base_profile::Vector{Float64}; n_days::Int = 7, seed::Int = 20260808)
    Random.seed!(seed)

    # More severe peak-valley volatility is intentionally imposed here to
    # stress-test whether ramp-driven overlap criteria can react to sharp
    # net-load transitions. The events are placed around rolling-window
    # boundaries and inside the look-ahead overlap range, because T_ramp is
    # triggered by strong ramps after the 24-hour execution window.
    daily_energy_factor = [0.94, 1.13, 0.88, 1.18, 0.96, 1.24, 0.86]
    daily_shape_tilt = [-0.080, 0.105, -0.095, 0.120, -0.070, 0.140, -0.085]

    load_values = Float64[]
    drift = 0.0
    base_mean = mean(base_profile)

    for day ∈ 1:n_days
        for h ∈ 1:24
            hour = (day - 1) * 24 + h
            base = base_profile[h]

            # Slow mean-reverting uncertainty shared across adjacent hours.
            drift = 0.82 * drift + randn() * 0.018

            # Shape perturbation makes evening-heavy and morning-light days.
            shape = 1.0 + daily_shape_tilt[day] * sin(2π * (h - 14) / 24)

            # Local volatility grows around normal ramp periods and remains
            # smaller in valley periods so that peak-valley contrast is visible.
            ramp_sensitive_noise = (h in 6:10 || h in 17:21) ? randn() * 0.055 : randn() * 0.025

            # Strong ramp events. Positive pulses represent sharp demand surges;
            # the negative pulse creates a fast down-ramp followed by recovery.
            event_factor = 0.0
            event_factor += ramp_pulse(hour, 27, 2, 3, 2, 0.34)    # Interval 1 look-ahead surge
            event_factor += ramp_pulse(hour, 55, 2, 4, 2, -0.30)   # Interval 2 look-ahead drop/rebound
            event_factor += ramp_pulse(hour, 82, 2, 3, 2, 0.38)    # Interval 3 look-ahead surge
            event_factor += ramp_pulse(hour, 106, 3, 3, 2, -0.32)  # Interval 4 look-ahead drop
            event_factor += ramp_pulse(hour, 131, 2, 4, 2, 0.42)   # Interval 5 look-ahead surge
            event_factor += ramp_pulse(hour, 154, 2, 3, 2, -0.28)  # Interval 6 look-ahead drop

            val = base * daily_energy_factor[day] * shape * (1.0 + drift + ramp_sensitive_noise + event_factor)
            val = clamp(val, 0.55 * minimum(base_profile), 1.60 * maximum(base_profile))
            push!(load_values, round(val; digits = 2))
        end
    end

    return load_values
end

function update_excel_load_curve(load_values::Vector{Float64}; excel_path::String = joinpath(pwd(), "data", "data_118.xlsx"))
    println("\nUpdating Excel load curve at: $excel_path...")

    XLSX.openxlsx(excel_path; mode = "rw") do xf
        if !("load_curve" in XLSX.sheetnames(xf))
            error("Sheet 'load_curve' not found in $excel_path")
        end
        sh = xf["load_curve"]
        sh["A1"] = "time"
        sh["B1"] = "load_curve"
        for (i, val) ∈ enumerate(load_values)
            sh[i + 1, 1] = Float64(i)
            sh[i + 1, 2] = Float64(val)
        end
    end

    println("  ✓ Successfully updated sheet 'load_curve' in data_118.xlsx!")
    println("  ✓ Hours: $(length(load_values)); min=$(minimum(load_values)); max=$(maximum(load_values)); max ramp=$(maximum(abs.(diff(load_values))))")
end

# Generate and export
excel_path = joinpath(pwd(), "data", "data_118.xlsx")
base_profile = read_base_load_curve(excel_path)
load_vals = generate_stochastic_load_curve(base_profile; n_days = 7)
update_excel_load_curve(load_vals; excel_path = excel_path)

println("\n" * "="^80)
println("✓ Stochastic 118-Bus Load Curve with Strong Ramp Events Generated (168 Hours)")
println("="^80 * "\n")
