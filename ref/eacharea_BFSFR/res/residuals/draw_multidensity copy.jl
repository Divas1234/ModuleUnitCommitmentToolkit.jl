using CSV
using DataFrames, Distributions, CSV, Statistics, KernelDensity
using MultivariateStats, Interpolations
using Random
using Plots
Random.seed!(1234)

df = CSV.read("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\residuals\\sampledata1.csv", DataFrame)

# means = [mean(row) for row in eachrow(df)]
# stds = [std(row) for row in eachrow(df)]

data = Matrix(df)

function get_distributiondensity(data)
    local function get_kdeestimation_data(data, bandwidth)
        kde_result = kde(data, bandwidth = bandwidth)
        return kde_result
    end

    time = 1201

    zgrid = zeros(time, 2048)
    ygrid = zeros(time, 2048)
    # Plots.plot(zgrid[10,:])

    num_filters = size(data, 1)
    for i in 1:num_filters
        kde_result = get_kdeestimation_data(data[i, :], 0.0025)
        ygrid[i, :] = kde_result.x
        zgrid[i, :] = kde_result.density
    end
    return ygrid, zgrid
end

ygrid, zgrid = get_distributiondensity(data)
xdata = range(1, 1201, length = 1201)

# Plots.surface(zgrid)
# Plots.plot(zgrid[30,:])

zgrid_interpolated = zeros(size(xdata, 1), size(ygrid, 2))
num_xaxis = size(xdata, 1)
num_yaxis = size(ygrid, 2)
new_ygrid = range(minimum(ygrid), maximum(ygrid), length = num_yaxis)

for i in 2:num_xaxis
    _id_start = findfirst(x -> x >= minimum(ygrid[i, :]), new_ygrid)
    _id_end = findfirst(x -> x >= maximum(ygrid[i, :]), new_ygrid)
    # @show [i _id_start _id_end]
    tem = collect(_id_start:1:_id_end)
    for j in eachindex(tem)
        # @show [i j]
        _iid_start = findfirst(x -> x >= new_ygrid[j, 1], ygrid[i, :])
        _iid_end = findfirst(x -> x >= new_ygrid[j + 1, 1], ygrid[i, :])
        _iid_end = (_iid_end == nothing) ? length(ygrid[i, :]) : _iid_end
        mean_value = mean(zgrid[i, _iid_start:_iid_end])
        # @show mean_value
        if mean_value != 0.0
            zgrid_interpolated[i, j] = mean_value
        else
            @info "error..."
        end
    end
end

# Plots.surface(zgrid_interpolated * 100)

# Plots.heatmap(zgrid_interpolated)
# Plots.surface(zgrid)

CSV.write("ygrid.csv", DataFrames.DataFrame(ygrid = ygrid))
CSV.write("xdata.csv", DataFrames.DataFrame(xdata = xdata))
CSV.write("zdata_interpolated.csv", DataFrame(zdata_interpolated, :auto))
