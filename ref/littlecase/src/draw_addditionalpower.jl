function calculate_sum_additionalpower(units, winds, Sampling_Statue, bess, δf_positor)
	current_Rc = 0.5
	Sampling_Statue = [1, 1, 0]
	current_Kg, current_Rg, current_Kw, current_Rw, current_Dw = calculate_diffdynamicparameter(units, winds, Sampling_Statue, 1)
	sum_conventionalunit_power = sum(units.p_max)
	sum_windfarms_power = sum(winds.p_max)
	# sum_bess_power = sum(bench_pss_charge_p⁺)
	ratio_1, ratio_2 = sum_conventionalunit_power / (sum_conventionalunit_power + sum_windfarms_power),
	sum_windfarms_power / (sum_conventionalunit_power + sum_windfarms_power)
	conventionalunits_addpower = zeros(1201, 1)
	windfarms_addpower = zeros(1201, 1)
	bess_addpower = zeros(1201, 1)

	for t in 1:1201
		conventionalunits_addpower[t, 1] = 0.5 * current_Kg / current_Rg * δf_positor[t, 1] * ratio_1 / 100 * 2
		windfarms_addpower[t, 1] = current_Kw / current_Rw * δf_positor[t, 1] * ratio_2 / 100 * 2
		bess_addpower[t, 1] = 0.5 * 1 / current_Rc * δf_positor[t, 1] / 100 * 2
	end

	# Plots.plot(conventionalunits_addpower)
	# Plots.plot!(windfarms_addpower)
	# Plots.plot!(bess_addpower)

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

function draw_SFR_additionalpower(sum_ConventionalUnitsPower_bench, sum_WindPower_bench, sum_Bess_bench,
	sum_ConventionalUnitsPower_proposed, sum_WindPower_proposed, sum_Bess_proposed,
	sum_ConventionalUnitsPower_enhanced, sum_WindPower_enhanced, sum_Bess_enhanced)
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

	p1 = Plots.plot(collect(0:0.05:60), sum_ConventionalUnitsPower_bench[1:1201, 1] .+ (sum_WindPower_bench[1:1201, 1] .* 0.50 .+ sum_Bess_bench[1:1201, 1]) .* 1.00;
		label = "TUC",
		la = 0.95,
        lc=colorant"#000000",
		lw = 3.0)
	
	p1 = Plots.plot!(collect(0:0.05:30),
		sum_ConventionalUnitsPower_proposed[1:601, 1] .+ sum_WindPower_proposed[1:601, 1] .+ sum_Bess_proposed[1:601, 1];
		xlims = (0, 30),
		ylims = (0, 0.35),
		size = (300, 300),
		xlabel = "t / s",
		ylabel = "Output / p.u.",
		label = "FCUC",
		tickfontfamily = "Helvetica",
		legendfontfamily = "Helvetica", foreground_color_legend = nothing,
		xtickfontsize = 8, ytickfontsize = 8, legendfontsize = 8, xguidefontsize = 8, yguidefontsize = 8, titlefontsize = 8, linealpha = 0.75, ylabelfontsize = 10, xlabelfontsize = 10,
		labelfontfamily = "Palatino Bold",
		# framestyle = :box,
		tick_direction = :out,
		foreground_color_grid = :grey,
		lw = 3,
        lc=colorant"#1a80bb",
		la = 0.95,
		# ls = :dash,
		grid = :true,
		xticks = (collect(0:10:30), collect(0:10:30)))

	# p1 = Plots.plot!(collect(0:0.05:60), sum_ConventionalUnitsPower_proposed[1:1201, 1] .+ sum_WindPower_proposed[1:1201, 1] .+ sum_Bess_proposed[1:1201, 1];
	# 	label = "FDUC",
	# 	lw = 2.0)
	p1 = Plots.plot!(collect(0:0.05:60), sum_ConventionalUnitsPower_enhanced[1:1201, 1] .+ sum_WindPower_enhanced[1:1201, 1] .+ sum_Bess_enhanced[1:1201, 1];
		label = "r-FCUC",
		la = 0.95,
        lc=colorant"#a00000",
		lw = 3.0)

	return p1
end
