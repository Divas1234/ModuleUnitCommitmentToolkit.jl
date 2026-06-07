using Plots, DelimitedFiles, LaTeXStrings, PlotThemes
# Plots.theme(:ggplot2),
Plots.theme(:dao)
function draw_case1_SFRcurve(xdata, ydata₁, ydata₂, ydata₂_set)
	p1 = Plots.plot(
		xdata,
		ydata₁;
		size = [300, 200],
		xlabel = "Time [s]",
		ylabel = "Frequency deviation [p.u.]",
		# ylims = (-0.5, 0.2),
		# yticks = (-0.50:0.1:0.1, (-0.50 / 50):(0.1 / 50):0.1),
		legendfontsize = 6,
		xtickfontsize = 7,
		ytickfontsize = 7,
		xguidefontsize = 7,
		yguidefontsize = 7,
		titlefontsize = 7,
		lw = 0.75,
		lc = :orange,
		framestyle = semi,
		linealpha = 0.85,
		legend = :bottomright,
		foreground_color_grid = :lightgrey,
		# foreground_color_minor_grid = :lightgrey,
		gridalpha = 0.5,
		label = "ASFR"
	)
	Plots.plot!(
		xdata,
		ydata₂;
		lw = 0.75,
		lc = :blue,
		linealpha = 0.85,
		label = "Bayesian filter"
	)
	lower_limit, upper_limit = calculate_confidence_limit(ydata₂_set)
	Plots.plot!(
		xdata,
		lower_limit;
		lw = 0.50,
		linealpha = 0.85,
		# lc = :green,
		label = "Lower limit"
	)
	Plots.plot!(
		xdata,
		upper_limit;
		lw = 0.50,
		linealpha = 0.85,
		# lc = :green,
		label = "Upper limit"
	)

	# figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 3/case_1/"
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
