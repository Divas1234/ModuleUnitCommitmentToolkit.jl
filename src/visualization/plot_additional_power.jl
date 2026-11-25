using Plots
using LaTeXStrings

function calculate_sum_additionalpower(units, winds, Sampling_Statue, bess, δf_positor)
    current_Rc = 0.5
    thermal_cap = max(sum(units.p_max), eps(Float64))
    wind_cap = sum(winds.p_max)
    active_p = units.p_max .* Sampling_Statue
    current_Kg = sum(units.Kg .* active_p) / thermal_cap
    valid_rg = [units.Rg[i] > 0 ? active_p[i] / units.Rg[i] : 0.0 for i in eachindex(units.p_max)]
    current_Rg = sum(valid_rg) > 0 ? thermal_cap / sum(valid_rg) : 1.0
    current_Kw = isempty(winds.Kw) ? 0.0 : sum(winds.Kw .* winds.p_max) / max(wind_cap, eps(Float64))
    valid_rw = [winds.Rw[i] > 0 ? winds.p_max[i] / winds.Rw[i] : 0.0 for i in eachindex(winds.p_max)]
    current_Rw = sum(valid_rw) > 0 ? max(wind_cap, eps(Float64)) / sum(valid_rw) : 1.0
    sum_conventionalunit_power = sum(units.p_max)
    sum_windfarms_power = wind_cap
    total_cap = max(sum_conventionalunit_power + sum_windfarms_power, eps(Float64))
    ratio_1, ratio_2 = sum_conventionalunit_power / total_cap, sum_windfarms_power / total_cap
    n_steps = size(δf_positor, 1)
    conventionalunits_addpower = zeros(n_steps, 1)
    windfarms_addpower = zeros(n_steps, 1)
    bess_addpower = zeros(n_steps, 1)

    for t in 1:n_steps
        conventionalunits_addpower[t, 1] = 0.5 * current_Kg / current_Rg * δf_positor[t, 1] * ratio_1 / 100 * 2
        windfarms_addpower[t, 1] = current_Kw / current_Rw * δf_positor[t, 1] * ratio_2 / 100 * 2
        bess_addpower[t, 1] = 0.5 * 1 / current_Rc * δf_positor[t, 1] / 100 * 2
    end

    return conventionalunits_addpower, windfarms_addpower, bess_addpower
end

# Plots.plot(sum_ConventionalUnitsPower_bench[1:1201, 1]; label = "TUC")
# Plots.plot!(sum_ConventionalUnitsPower_proposed[1:1201, 1]; label = "FDUC")
# Plots.plot!(sum_ConventionalUnitsPower_enhanced[1:1201, 1]; label = "CCFDUC")

# Plots.plot(sum_WindPower_bench[1:1201, 1]; label = "TUC")
# Plots.plot!(sum_WindPower_proposed[1:1201, 1]; label = "FDUC")
# Plots.plot!(sum_WindPower_enhanced[1:1201, 1]; label = "CCFDUC")

# Plots.plot(sum_Bess_bench[1:1201, 1]; label = "TUC")
# Plots.plot!(sum_Bess_proposed[1:1201, 1]; label = "FDUC")
# Plots.plot!(sum_Bess_enhanced[1:1201, 1]; label = "CCFDUC")

function draw_SFR_additionalpower(
    sum_ConventionalUnitsPower_bench,
    sum_WindPower_bench,
    sum_Bess_bench,
    sum_ConventionalUnitsPower_proposed,
    sum_WindPower_proposed,
    sum_Bess_proposed,
    sum_ConventionalUnitsPower_enhanced,
    sum_WindPower_enhanced,
    sum_Bess_enhanced,
)
    # p1 = Plots.plot(collect(0:0.05:60),
    # 	sum_ConventionalUnitsPower_bench[1:1201, 1] .+ sum_WindPower_bench[1:1201, 1] .+ sum_Bess_bench[1:1201, 1];
    # 	xlims = (0, 30),
    # 	ylims = (0, 4.0),
    # 	size = (300, 300),
    # 	xlabel = L"t / s",
    # 	ylabel = L"\textrm{Output \,/\, p.u.}",
    # 	label = "TUC",
    # 	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
    # 	# foreground_color_legend = nothing,
    # 	tickfontfamily = "Palatino Bold",
    # 	legendfontfamily = "Palatino Bold",
    # 	labelfontfamily = "Palatino Bold",
    # 	framestyle = :box,
    # 	foreground_color_grid = :grey,
    # 	lw = 2,
    # 	grid = :true,
    # 	xticks = (collect(0:10:60), collect(0:10:60)))

    p1 = Plots.plot(
        collect(0:0.05:30),
        sum_ConventionalUnitsPower_proposed[1:601, 1] .+ sum_WindPower_proposed[1:601, 1] .+ sum_Bess_proposed[1:601, 1];
        xlims = (0, 30),
        ylims = (0, 0.35),
        size = (300, 300),
        xlabel = L"t / s",
        ylabel = L"\textrm{Output \,/\, p.u.}",
        label = "FDUC",
        # xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
        # foreground_color_legend = nothing,
        tickfontfamily = "Palatino Bold",
        legendfontfamily = "Palatino Bold",
        labelfontfamily = "Palatino Bold",
        framestyle = :box,
        foreground_color_grid = :grey,
        lw = 3,
        lc = :orange,
        la = 0.75,
        # ls = :dash,
        grid = :true,
        xticks = (collect(0:10:30), collect(0:10:30)),
    )

    # p1 = Plots.plot!(collect(0:0.05:60), sum_ConventionalUnitsPower_proposed[1:1201, 1] .+ sum_WindPower_proposed[1:1201, 1] .+ sum_Bess_proposed[1:1201, 1];
    # 	label = "FDUC",
    # 	lw = 2.0)
    p1 = Plots.plot!(
        collect(0:0.05:60),
        sum_ConventionalUnitsPower_enhanced[1:1201, 1] .+ sum_WindPower_enhanced[1:1201, 1] .+ sum_Bess_enhanced[1:1201, 1];
        label = "CCFDUC",
        la = 0.5,
        lc = :blue,
        lw = 3.0,
    )

    return p1
end
