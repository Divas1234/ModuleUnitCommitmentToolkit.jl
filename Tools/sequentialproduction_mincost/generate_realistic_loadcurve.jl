# ============================================================================
# Generator & Exporter: Realistic Dual-Peak Power Grid Load Curve (168 Hours)
#
# Features:
# 1. Daily Morning Peak (早高峰 07:00-09:30): Rapid ramp-up due to industrial start & morning activities
# 2. Daily Evening Peak (晚高峰 17:00-20:30): Rapid ramp-up + peak load due to residential & evening demand
# 3. Night Off-Peak (夜间低谷 00:00-06:00): Low steady baseline
# 4. Midday Plateau (午间平稳 10:00-16:30): Moderate steady demand
# 5. Weekend variations (Days 6-7): Slightly lower peak demand & milder ramps
# ============================================================================

using XLSX, Random, DataFrames

function generate_dual_peak_load_curve(; N_days = 7, base_min = 200.0, morning_peak = 330.0, evening_peak = 370.0)
    Random.seed!(42)
    load_values = Float64[]

    for day in 1:N_days
        # Apply weekend reduction factor (Days 6 & 7)
        is_weekend = (day == 6 || day == 7)
        scale = is_weekend ? 0.90 : 1.00

        # Hourly base profile for a single day (1 to 24)
        daily_profile = Float64[
            # 01:00 - 06:00 : Night Off-Peak (Low & Steady)
            base_min + rand() * 5.0,        # 01:00
            base_min + rand() * 4.0,        # 02:00
            base_min - 2.0 + rand() * 3.0,  # 03:00 (Valley bottom)
            base_min + rand() * 3.0,        # 04:00
            base_min + 5.0 + rand() * 4.0,  # 05:00
            base_min + 15.0 + rand() * 5.0, # 06:00

            # 07:00 - 09:30 : MORNING PEAK RAMP (早高峰强爬坡区段)
            base_min + 55.0 + rand() * 6.0, # 07:00 (Ramp start)
            morning_peak - 20.0 + rand() * 5.0, # 08:00 (Steep ramp)
            morning_peak + rand() * 8.0,    # 09:00 (Morning peak)

            # 10:00 - 16:30 : Midday Plateau (午间平稳)
            morning_peak - 15.0 + rand() * 5.0, # 10:00
            morning_peak - 25.0 + rand() * 6.0, # 11:00
            morning_peak - 30.0 + rand() * 5.0, # 12:00
            morning_peak - 20.0 + rand() * 6.0, # 13:00
            morning_peak - 15.0 + rand() * 5.0, # 14:00
            morning_peak - 10.0 + rand() * 6.0, # 15:00
            morning_peak + 5.0 + rand() * 5.0,  # 16:00

            # 17:00 - 20:30 : EVENING PEAK RAMP (晚高峰强爬坡与最高峰)
            evening_peak - 30.0 + rand() * 6.0, # 17:00 (Evening ramp start)
            evening_peak - 10.0 + rand() * 5.0, # 18:00 (Steep ramp)
            evening_peak + rand() * 8.0,        # 19:00 (Evening peak)
            evening_peak - 15.0 + rand() * 6.0, # 20:00

            # 21:00 - 24:00 : Night Ramp Down (夜间退峰)
            evening_peak - 60.0 + rand() * 6.0, # 21:00
            base_min + 70.0 + rand() * 5.0,     # 22:00
            base_min + 35.0 + rand() * 4.0,     # 23:00
            base_min + 10.0 + rand() * 4.0      # 24:00
        ]

        # Apply daily scaling and add to global time series
        for val in daily_profile
            push!(load_values, round(val * scale; digits = 2))
        end
    end

    return load_values
end

function update_excel_load_curve(load_values::Vector{Float64})
    excel_path = joinpath(pwd(), "data", "data.xlsx")
    println("\nUpdating Excel load curve at: $excel_path...")

    # Build new load curve matrix (168 x 2)
    N_total = length(load_values)
    matrix_data = Matrix{Any}(undef, N_total + 1, 2)
    matrix_data[1, 1] = "time"
    matrix_data[1, 2] = "load_curve"

    for i in 1:N_total
        matrix_data[i + 1, 1] = Float64(i)
        matrix_data[i + 1, 2] = load_values[i]
    end

    # Update XLSX file sheet load_curve
    XLSX.openxlsx(excel_path, mode = "rw") do xf
        sheet = xf["load_curve"]
        for i in 1:N_total
            sheet[i + 1, 1] = Float64(i)
            sheet[i + 1, 2] = load_values[i]
        end
        println("  ✓ Successfully updated sheet 'load_curve' in data.xlsx!")
    end
end

# Generate and export
load_vals = generate_dual_peak_load_curve(N_days = 7)
update_excel_load_curve(load_vals)

println("\n" * "="^80)
println("✓ Realistic Dual-Peak Load Curve Successfully Generated (168 Hours)")
println("="^80 * "\n")
