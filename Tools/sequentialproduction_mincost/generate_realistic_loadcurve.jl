# ============================================================================
# Generator & Exporter: Stochastic Power Grid Load Curve (168 Hours)
#
# Features:
# 1. High Stochastic Uncertainty: Random walk drift + multi-scale noise
# 2. Flexible Baseline: Smooth daily trends without hardcoded morning/evening peak ramps
# 3. Emphasizes Load & Renewable Balance Uncertainty
# ============================================================================

using XLSX, Random, DataFrames

function generate_stochastic_load_curve(; N_days = 7, base_load = 280.0, volatility = 25.0)
    Random.seed!(42)
    load_values = Float64[]
    current_load = base_load

    for day in 1:N_days
        # Daily smooth oscillation baseline (diurnal variation)
        for h in 1:24
            # Smooth diurnal wave + stochastic random walk component
            diurnal_component = 30.0 * sin(2π * (h - 6) / 24)
            stochastic_noise = randn() * volatility * 0.4
            
            # Mean-reverting random walk drift
            drift = 0.15 * (base_load - current_load) + randn() * 8.0
            current_load = current_load + drift

            val = base_load + diurnal_component + stochastic_noise + (current_load - base_load) * 0.3
            val = clamp(val, 180.0, 420.0)
            push!(load_values, round(val; digits = 2))
        end
    end

    return load_values
end

function update_excel_load_curve(load_values::Vector{Float64})
    excel_path = joinpath(pwd(), "data", "data.xlsx")
    println("\nUpdating Excel load curve at: $excel_path...")

    # Read existing excel workbook
    xf = XLSX.readxlsx(excel_path)
    snames = XLSX.sheetnames(xf)

    # Reconstruct tables for all sheets
    tables_vec = Pair{String, Any}[]
    for name in snames
        sh = xf[name]
        data = sh[:]
        if name == "load_curve"
            N_total = length(load_values)
            df = DataFrame(time = Float64.(1:N_total), load_curve = load_values)
            push!(tables_vec, name => df)
        else
            # Extract header and rows into DataFrame
            header = Symbol.(vec(data[1, :]))
            header = [ismissing(h) || h == :missing ? Symbol("col_$i") : h for (i, h) in enumerate(header)]
            rows = data[2:end, :]
            df = DataFrame(rows, header; makeunique = true)
            push!(tables_vec, name => df)
        end
    end

    # Write back all sheets safely
    XLSX.writetable(excel_path, tables_vec; overwrite = true)
    println("  ✓ Successfully updated sheet 'load_curve' in data.xlsx!")
end

# Generate and export
load_vals = generate_stochastic_load_curve(N_days = 7)
update_excel_load_curve(load_vals)

println("\n" * "="^80)
println("✓ Stochastic Load Curve (Uncertainty Emphasized) Successfully Generated (168 Hours)")
println("="^80 * "\n")

