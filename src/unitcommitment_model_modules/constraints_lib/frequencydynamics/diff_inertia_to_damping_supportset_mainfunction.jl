include("_automatic_workflow.jl")

const DROOP_PARAMETERS = collect(range(33, 40; length = 20))
const SAMPLE_DROOP_INDICES = (1, 4, 6, 10)

"""
	build_feasible_region_plot(droop_parameter)

Generate inertia-damping curve and overlay feasible polygon region.
"""
function build_feasible_region_plot(droop_parameter)
	p = generate_inertia_damping_figure(droop_parameter)
	_, sub_vertices = get_inertiatodamping_functions(droop_parameter)

	# Extract damping (x) and inertia (y) coordinates from vertices.
	x_coords = [v[2] for v in sub_vertices]
	y_coords = [v[3] for v in sub_vertices]

	# Overlay polygon region on top of the original plot.
	plot!(p, x_coords, y_coords; seriestype = :shape, fillalpha = 0.2, fillcolor = :red, label = "Feasible Region")

	return p, sub_vertices
end

selected_droops = DROOP_PARAMETERS[collect(SAMPLE_DROOP_INDICES)]
plot_list = [build_feasible_region_plot(droop)[1] for droop in selected_droops]

Plots.plot(plot_list...; layout = (2, 2), size = (400, 400), dpi = 400, legend = false)

fig_path = joinpath(pwd(), "fig/inertia_damping_feasible_region.png")

Plots.savefig(fig_path)
Plots.savefig(joinpath(pwd(), "fig/inertia_damping_feasible_region.pdf"))
