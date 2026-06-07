using CSV, DataFrames, Distributions, Statistics, KernelDensity
using MultivariateStats, Interpolations
using Random, Plots
Random.seed!(1234)

# Read the CSV file
df = CSV.read("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\residuals\\sampledata3.csv", DataFrame)

# Convert DataFrame to Matrix
data = Matrix(df)

function get_distributiondensity(data)
    function get_kdeestimation_data(data, bandwidth)
        kde_result = kde(data, bandwidth=bandwidth)
        return kde_result
    end

    time = 1201
    zgrid = zeros(time, 2048)
    ygrid = zeros(time, 2048)
    num_filters = size(data, 1)

    for i in 1:num_filters
        kde_result = get_kdeestimation_data(data[i, :], 0.0005)
        ygrid[i, :] = kde_result.x
        zgrid[i, :] = kde_result.density
    end
    return ygrid, zgrid
end

# Compute density grids
ygrid, zgrid = get_distributiondensity(data)
xdata = range(1, 1201, length=1201)

# # Interpolation
# zgrid_interpolated = zeros(length(xdata), size(ygrid, 2))
# num_xaxis = length(xdata)
# num_yaxis = size(ygrid, 2)
# new_ygrid = range(minimum(ygrid), maximum(ygrid), length=num_yaxis)

# for i in 2:num_xaxis
#     # Find indices for the new y-grid within the range of ygrid[i, :]
#     _id_start = findfirst(x -> x >= minimum(ygrid[i, :]), new_ygrid)
#     _id_end = findlast(x -> x <= maximum(ygrid[i, :]), new_ygrid)

#     if _id_start === nothing || _id_end === nothing
#         @warn "Invalid range for i=$i, skipping..."
#         continue
#     end

#     tem = collect(_id_start:_id_end)
#     for j in 1:(length(tem)-1)
#         # Find corresponding indices in ygrid[i, :] for interpolation
#         y_start = new_ygrid[tem[j]]
#         y_end = new_ygrid[tem[j+1]]

#         _iid_start = findfirst(x -> x >= y_start, ygrid[i, :])
#         _iid_end = findlast(x -> x <= y_end, ygrid[i, :])

#         if _iid_start === nothing || _iid_end === nothing
#             @warn "No valid range for i=$i, j=$j, assigning zero"
#             zgrid_interpolated[i, tem[j]] = 0.0
#             continue
#         end

#         # Compute mean of zgrid values within the range
#         mean_value = mean(zgrid[i, _iid_start:_iid_end])
#         if !isnan(mean_value) && mean_value != 0.0
#             zgrid_interpolated[i, tem[j]] = mean_value
#         else
#             @warn "Mean value is zero or NaN for i=$i, j=$j"
#             zgrid_interpolated[i, tem[j]] = 0.0
#         end
#     end
# end

# # Save outputs
# CSV.write("ygrid.csv", DataFrame(ygrid, :auto))
# CSV.write("xdata.csv", DataFrame(xdata=xdata))
# CSV.write("zdata.csv", DataFrame(zgrid,:auto))
# CSV.write("zdata_interpolated.csv", DataFrame(zgrid_interpolated, :auto))

# Optional: Visualize for debugging
# heatmap(zgrid_interpolated, title="Interpolated Density")
# Plots.surface(zgrid_interpolated * 100, title="Interpolated Surface")
n_ticks = length(0:500:2048)
tick_labels = range(minimum(ygrid), stop=maximum(ygrid), length=n_ticks)

p1 = Plots.surface(zgrid;
    colorbar=false,              # Disable the color bar
    colormap=:bwr,
    alpha=0.5,
    # ylims = (-0.5, 0.2),
    ztickfontsize=12, xtickfontsize=12, ytickfontsize=12, legendfontsize=10, xguidefontsize=10, yguidefontsize=10,
    titlefontsize=8, linealpha=0.75, ylabelfontsize=14, xlabelfontsize=14, zlabelfontsize=14,
    # tickfontfamily = "Palatino Bold",
    # legendfontfamily = "Palatino Bold",
    # tickfontfamily = "Computer Modern",
    # legendfontfamily = "Computer Modern",
    fontfamily="Helvetica",
    tickfontfamily="Helvetica",
    legendfontfamily="Helvetica", lw=1.5,
    yticks=(0:200:1200, 0:10:60),
    xticks=(0:500:2048, round.(tick_labels, digits=3)),
    camera=(45, 30),
    size=(800, 600),
    marker=:circle,                       # Set marker to circle
    # fontfamily="Helvetica",             # Set font to Helvetica
    xlabel="Δf(t) (Hz)",                # X-axis label
    ylabel="t (s)",                     # Y-axis label
    zlabel="Posterior density",                 # Optional Z-axis label for clarity
)
base_dir = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\surface\\"
Plots.savefig(p1, joinpath(base_dir, "3D_surface_plot_sampledata1.pdf"))

# ---

df = CSV.read("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\residuals\\sampledata4.csv", DataFrame)

# Convert DataFrame to Matrix
data = Matrix(df)

ygrid, zgrid = get_distributiondensity(data)
xdata = range(1, 1201, length=1201)
n_ticks = length(0:500:2048)
tick_labels = range(minimum(ygrid), stop=maximum(ygrid), length=n_ticks)

p1 = Plots.surface(zgrid;
    colorbar=false,              # Disable the color bar
    colormap=:viridis,
    # ylims = (-0.5, 0.2),
    ztickfontsize=12, xtickfontsize=12, ytickfontsize=12, legendfontsize=10, xguidefontsize=10, yguidefontsize=10,
    titlefontsize=8, linealpha=0.75, ylabelfontsize=14, xlabelfontsize=14, zlabelfontsize=14,
    # tickfontfamily = "Palatino Bold",
    # legendfontfamily = "Palatino Bold",
    # tickfontfamily = "Computer Modern",
    # legendfontfamily = "Computer Modern",
    fontfamily="Helvetica",
    tickfontfamily="Helvetica",
    legendfontfamily="Helvetica", lw=1.5,
    yticks=(0:200:1200, 0:10:60),
    xticks=(0:500:2048, round.(tick_labels, digits=3)),
    camera=(45, 30),
    size=(800, 600),
    marker=:circle,                       # Set marker to circle
    # fontfamily="Helvetica",             # Set font to Helvetica
    xlabel="Δf(t) (Hz)",                # X-axis label
    ylabel="t (s)",                     # Y-axis label
    zlabel="Posterior density",                 # Optional Z-axis label for clarity
)

Plots.savefig(p1, joinpath(base_dir, "3D_surface_plot_sampledata2.pdf"))

