using Plots, DelimitedFiles, LaTeXStrings, PlotThemes
# Plots.theme(:dao)
# plotlyjs()
function draw_sfr_curve1(xdata, ydata₁, ydata₂, ydata₃)
	p1 = Plots.plot(
		xdata[1:601, 1],
		ydata₂[1:601, 1];
		size = (300, 300),
		lc = 2,
		xlabel = "t / s",
		ylabel = L"\Delta f(t) \,/\,Hz",
		xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
		foreground_color_grid = :lightgrey,
		gridalpha = 0.5,
		label = "BF-SFR",
	)
	# Plots.plot!(xdata, ydata₂;label = "   BF_SFR")
	Plots.plot!(xdata[1:601, 1], ydata₃[1:601, 1]; label = "simulator")

	# figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 2/case_4/"
	# Plots.savefig(p1, figpath * "SFRcurve.pdf")
	return p1
end

function draw_sfr_curve2(xdata, ydata₁, ydata₂, ydata₃)
	p1 = Plots.plot(
		xdata[1:601, 1],
		ydata₂[1:601, 1];
		size = (300, 300),
		lc = 2,
		xlabel = L"t / s",
		ylabel = L"\Delta f(t) \,/\,Hz",
		xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
		legend = :bottomright,
		foreground_color_grid = :lightgrey,
		gridalpha = 0.5,
		label = "BF-SFR",
	)
	# Plots.plot!(xdata, ydata₂;lc = 2,label = "   BF_SFR")
	Plots.plot!(xdata[1:601, 1], ydata₃[1:601, 1]; lc = 2, label = "simulator")

	# figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 2/case_4/"
	# Plots.savefig(p1, figpath * "SFRcurve.pdf")
	return p1
end

function calculate_confidence_limit(sampledata)
	NL, NT = size(sampledata, 1), size(sampledata, 2)
	lower_limit, upper_limit = zeros(NT, 1), zeros(NT, 1)
	for t in 1:NT
		lower_limit[t, 1] = minimum(sampledata[:, t])
		upper_limit[t, 1] = maximum(sampledata[:, t])
	end
	return lower_limit, upper_limit
end

function draw_sfr_curve3(xdata, ydata₁, ydata₂, ydata₃, ydata₄, sampledata1, sampledata2)
	tem1, tem2 = zeros(1201, 2), zeros(1201, 2)
	for i in 1:1201
		tem1[i, 1], tem1[i, 2] = mean(sampledata1[i, :]), std(sampledata1[i, :])
		tem2[i, 1], tem2[i, 2] = mean(sampledata2[i, :]), std(sampledata2[i, :])
	end

	p1 = Plots.plot(xdata[1:1201, 1], ydata₁[1:1201, 1];
		color = colorant"#b8b8b8",
		la = 1,
		fa = 0.5,
		ribbon = tem1[:, 2] .* 20, label = false)
	Plots.plot!(xdata[1:1201, 1], ydata₃[1:1201, 1];
		color = colorant"#b8b8b8",
		fa = 0.75,
		la = 1,
		ribbon = tem2[:, 2] .* 20, label = false)
	Plots.plot!(
		xdata[1:1201, 1],
		ydata₁[1:1201, 1];
		# size                    = (400, 300),
		  size                    = (300, 300),
		  lc                      = colorant"#2066a8",
		  la                      = 0.95,
		  xlabel                  = L"t / s",
		  tick_direction          = :out,
		  palette                 = :grays,
		  outerarix               = true,
		  ylabel                  = L"\Delta f / Hz",
		  fontfamily              = "Helvetica",
		  tickfontfamily          = "Helvetica",
		  legendfontfamily        = "Helvetica",
		  foreground_color_legend = nothing,
		  xtickfontsize           = 8,
		  ytickfontsize           = 8,
		  legendfontsize          = 8,
		  xguidefontsize          = 8,
		  yguidefontsize          = 8,
		  titlefontsize           = 8,
		  linealpha               = 0.75,
		  ylabelfontsize          = 10,
		  xlabelfontsize          = 10,
		  foreground_color_grid   = :grey,
		  xticks                  = (collect(0:5:60), collect(0:5:60)),
		  gridalpha               = 0.5,
		  lw                      = 1.50,
		  grid                    = false,
		  background_color_inside = :transparent,
		  xlims                   = (-2, 62),
		# framestyle              = :box,
		  axiswidth               = 2.5,
		  ylims                   = (-0.4, 0.2),
		  label                   = "Case 1 (w/o converter): BF-SFR",
	)
	Plots.plot!(xdata[1:1201, 1], ydata₃[1:1201, 1]; lw = 1.50, la = 0.95, lc = colorant"#3594cc", label = "Case 2 (w/   converter): BF-SFR")
	Plots.plot!(xdata[1:1201, 1], ydata₂[1:1201, 1]; lw = 1.50, la = 0.95, lc = colorant"#a00000", label = "Case 1 (w/o converter): simulator")
	Plots.plot!(xdata[1:1201, 1], ydata₄[1:1201, 1]; lw = 1.50, la = 0.50, lc = colorant"#a00000", label = "Case 2 (w/   converter): simulator")
	return p1

end
# using Plots, DelimitedFiles, LaTeXStrings, PlotThemes
# # Plots.theme(:dao)
# function draw_sfr_curve1(xdata, ydata₁, ydata₂, ydata₃)
#     p1 = Plots.plot(
#         xdata[1:601, 1],
#         ydata₂[1:601, 1];
#         size=(300, 300),
#         lc=2,
#         xlabel=L"t / s",
#         ylabel=L"\Delta f(t) \,/\,Hz",
#         xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xguidefontsize=6, yguidefontsize=6, titlefontsize=6, linealpha=0.75, ylabelfontsize=8, xlabelfontsize=8,
#         legend=:bottomright,
#         foreground_color_grid=:lightgrey,
#         gridalpha=0.5,
#         label="BF-SFR"
#     )
#     # Plots.plot!(xdata, ydata₂;label = "   BF_SFR")
#     Plots.plot!(xdata[1:601, 1], ydata₃[1:601, 1]; label="simulator")

#     # figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 2/case_4/"
#     # Plots.savefig(p1, figpath * "SFRcurve.pdf")
#     return p1
# end

# function draw_sfr_curve2(xdata, ydata₁, ydata₂, ydata₃)
#     p1 = Plots.plot(
#         xdata[1:601, 1],
#         ydata₂[1:601, 1];
#         size=(300, 300),
#         lc=2,
#         xlabel=L"t / s",
#         ylabel=L"\Delta f(t) \,/\,Hz",
#         xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xguidefontsize=6, yguidefontsize=6, titlefontsize=6, linealpha=0.75, ylabelfontsize=8, xlabelfontsize=8,
#         legend=:bottomright,
#         foreground_color_grid=:lightgrey,
#         gridalpha=0.5,
#         label="BF-SFR"
#     )
#     # Plots.plot!(xdata, ydata₂;lc = 2,label = "   BF_SFR")
#     Plots.plot!(xdata[1:601, 1], ydata₃[1:601, 1]; lc=2, label="simulator")

#     # figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 2/case_4/"
#     # Plots.savefig(p1, figpath * "SFRcurve.pdf")
#     return p1
# end

# function calculate_confidence_limit(sampledata)
#     NL, NT = size(sampledata, 1), size(sampledata, 2)
#     lower_limit, upper_limit = zeros(NT, 1), zeros(NT, 1)
#     for t in 1:NT
#         lower_limit[t, 1] = minimum(sampledata[:, t])
#         upper_limit[t, 1] = maximum(sampledata[:, t])
#     end
#     return lower_limit, upper_limit
# end

# function draw_sfr_curve3(xdata, ydata₁, ydata₂, ydata₃, ydata₄)
#     p1 = Plots.plot(
#         xdata[1:601, 1],
#         ydata₁[1:601, 1];
#         size=(300, 300),
#         lc=1,
#         xlabel=L"t / s",
#         ylabel=L"\Delta f(t) \,/\,Hz",
#         legend=:bottomright,
#         xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xguidefontsize=6, yguidefontsize=6, titlefontsize=6, linealpha=0.75, ylabelfontsize=10, xlabelfontsize=10,
#         foreground_color_grid=:lightgrey,
#         gridalpha=0.25,
#         label="BF-SFR: case1"
#     )
#     Plots.plot!(xdata[1:601, 1], ydata₃[1:601, 1]; lc=2, label="BF-SFR: case 2")
#     Plots.plot!(xdata[1:601, 1], ydata₂[1:601, 1]; lc=3, label="simulator: case 1")
#     Plots.plot!(xdata[1:601, 1], ydata₄[1:601, 1]; lc=4, label="simulator: case 2")

#     return p1
# end