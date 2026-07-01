# using KDEstimation
# using Distributions, Plots, StatsPlots
using Random: seed!
# Plots.theme(:ggplot2),
# Plots.theme(:dao)

function draw_case1_frequencydistribution(data, data2)
    row, column = size(data, 1), size(data, 2)
    aver_matrix = zeros(1, column)
    for i in 1:column
        aver_matrix[1, i] = mean(data[:, i])
    end
    frequency_nadir_column = argmin(aver_matrix)[2]
    xdata = data[:, frequency_nadir_column]
    # println(xdata)
    # max_xdata = maximum(xdata)
    # xdata_1 = xdata / 5000
    # println(xdata_1)
    p1 = Plots.histogram(
        xdata;
        # ydata,
        # size           = [300, 200],
        xlabel = L"\Delta f(t) \,\,\textrm{[\,\,Hz\,\,]}",
        ylabel = L"\textrm{Number}",
        fc = :deepskyblue,
        framestyle = :semi,
        tick_direction = :out,
        fa = 0.5,
        label = L"\textrm{discretized\,\, SFR:\,\,\, w/\,\, little \,\, noise}",
        # label = false,
    )

    row2, column2 = size(data2, 1), size(data2, 2)
    aver_matrix2 = zeros(1, column2)
    for i in 1:column2
        aver_matrix2[1, i] = mean(data2[:, i])
    end
    frequency_nadir_column2 = argmin(aver_matrix2)[2]
    xdata2 = data2[:, frequency_nadir_column2]
    xdata2 = xdata2 .- aver_matrix2[1, frequency_nadir_column2] .+ aver_matrix[1, frequency_nadir_column]
    p1 = Plots.histogram!(
        xdata2;
        lw = 0.1,
        xlabel = L"\Delta f(t) \,\,\textrm{[\,\,Hz\,\,]}",
        ylabel = L"\textrm{Number}",
        fc = :firebrick1,
        # linealpha = 0.5,
        # gridalpha = 0.5,
        fa = 0.5,
        # label = "Probabilistic distribution",
        label = L"\textrm{discretized\,\, SFR:\,\,\, w/\,\, large \,\, noise}",        # label = false,
    )
    # figpath = "C:/Users/15703/OneDrive/桌面/letter_code/master_code/master - 4/case_1/"
    # Plots.savefig(p1, figpath * "SFR_PDFinfo.pdf")
    return p1
end

function draw_case1_SFRdistribution(data1, data2)
    row, column = size(data1, 1), size(data1, 2)
    aver_matrix = zeros(row, 1)
    for i in 1:row
        aver_matrix[i, 1] = mean(data1[i, :])
    end
    aver_matrix
    # Plots.plot(-aver_matrix)
    frequency_nadir_column = argmin(-aver_matrix)[1]
    xdata = data1[frequency_nadir_column, :]
    # fkde1 = KDEestimation(xdata)

    row2, column2 = size(data2, 1), size(data2, 2)
    aver_matrix2 = zeros(row, 1)
    for i in 1:row
        aver_matrix2[i, 1] = mean(data2[i, :])
    end
    # Plots.plot(-aver_matrix2)
    frequency_nadir_column2 = argmin(-aver_matrix2)[1]
    xdata2 = data2[frequency_nadir_column2, :]
    xdata2 = xdata2 .- aver_matrix2[frequency_nadir_column2, 1] .+ aver_matrix[frequency_nadir_column, 1]
    # fkde2 = KDEestimation(xdata2)

    # calculate_Q1Q2percentile(xdata2)

    fig = Plots.density(
        -xdata,
        size = (300, 300),
        # xlabel = L"t \,\,\textrm{[\,\,s\,\,]}",
        # size=(400, 300),
        background_color_inside = :transparent,
        # ylims=(0, 1.5e4),
        xlabel = L"\Delta f(t) / Hz",
        ylabel = "Posterior distribution density",
        # xrotation = 30,
        xtickfontsize = 8,
        ytickfontsize = 8,
        legendfontsize = 8,
        xguidefontsize = 8,
        yguidefontsize = 8,
        titlefontsize = 8,
        linealpha = 0.75,
        ylabelfontsize = 10,
        xlabelfontsize = 10,
        # tickfontfamily = "Palatino Bold",
        # legendfontfamily = "Palatino Bold",

        # tickfontfamily = "Computer Modern",
        # legendfontfamily = "Computer Modern",

        fontfamily = "Helvetica",
        tickfontfamily = "Helvetica",
        legendfontfamily = "Helvetica",
        lw = 1.5,
        foreground_color_legend = nothing,
        grid = false,
        ga = 0.25,
        # xtickfontsize=6, ytickfontsize=6, xlabelfontsize=10, ylabelfontsize=10, legendfontsize=8,
        # xticks = (-0.692:0.002:-0.678, (-0.692):(0.002):-0.678),
        # digits=3,
        # yticks = (0::-0.67, -0.70:(0.05 / 5):-0.65),
        framestyle = :semi,
        # ylims = (0, 8000),
        # lw = 1.0,
        # xlims = (-0.345, -0.340),
        ylims = (0, 1000),
        fill = (0, 0.25, colorant"#97a6c4"),
        # lc = :deepskyblue,
        label = "Residual 1: Normal(0,1e-2)",
    )
    fig = Plots.density!(
        -xdata2,
        lw = 1.5,
        # lw = 1.0,
        fill = (0, 0.25, colorant"#1a80bb"),
        # label=L"\textbf{Case 2}",
        label = "Residual 2: Normal(0,1e-1)",        # lc = :firebrick1,
    )
    return fig
end

function draw_case1_boxplot(data1, data2)
    row, column = size(data1, 1), size(data1, 2)
    aver_matrix = zeros(row, 1)
    for i in 1:row
        aver_matrix[i, 1] = mean(data1[i, :])
    end
    aver_matrix
    frequency_nadir_column = argmin(-aver_matrix)[1]
    xdata1 = data1[frequency_nadir_column, :]

    row2, column2 = size(data2, 1), size(data2, 2)
    aver_matrix2 = zeros(row, 1)
    for i in 1:row2
        aver_matrix2[i, 1] = mean(data2[i, :])
    end
    frequency_nadir_column2 = argmin(-aver_matrix2)[1]
    xdata2 = data2[frequency_nadir_column2, :]
    xdata2 = xdata2 .- aver_matrix2[frequency_nadir_column2, 1] .+ aver_matrix[frequency_nadir_column, 1]

    p1 = Plots.boxplot(
        -xdata1;
        # ylims=(-0.345, -0.340),
        size = (300, 300),
        # size                    = (667 * 0.45, 500 * 0.5),
        # xtickfontsize           = 10,                                                              ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
        xticks = (1:1:2, ["Case 1", "Case 2"]),
        ylabel = L"\Delta f(t) / Hz",
        # xlabel                  = L"\Delta f(t) / Hz",
        # xlabel                  = L"\textrm{Different\,\,uncertain\,\, variability\,\, settings}",
        bar_width = 0.350,
        # notch                   = true,
        # ylims                   = (-0.35, -0.3325),
        xlims = (-1, 2.5),
        background_color_inside = :transparent,
        whisker_range = 1.50,
        xtickfontsize = 8,
        ytickfontsize = 8,
        legendfontsize = 8,
        xguidefontsize = 8,
        yguidefontsize = 8,
        titlefontsize = 8,
        linealpha = 0.75,
        ylabelfontsize = 10,
        xlabelfontsize = 10,
        # tickfontfamily          = "Palatino Bold",
        # legendfontfamily        = "Palatino Bold",
        tick_direction = :out,
        # tickfontfamily          = "Computer Modern",
        # legendfontfamily        = "Computer Modern",

        fontfamily = "Helvetica",
        tickfontfamily = "Helvetica",
        legendfontfamily = "Helvetica",
        foreground_color_legend = nothing,
        grid = false,
        outliers = false,
        # framestyle       = :box,
        legend = :bottomleft,
        # label            = L"\textbf{Case 1}: N(0,0.01)",
        # label            = L"\textbf{Case 1}",
        label = "Residual 1:Normal(0,1e-2)",
        ga = 0.25,
        # fill             = (0, 0.25, colorant"#97a6c4"),
        fa = 0.5,
        lw = 1.5,
    )
    p1 = Plots.boxplot!(
        -xdata2;
        label = "Residual 2:Normal(0,1e-1)",
        bar_width = 0.350,
        whisker_range = 1.50,
        fa = 0.25,
        # fill          = (0, 0.25, colorant"#384860"),
        lw = 1.5,
    )
    return p1
end
# function KDEestimation(data)
#     seed!(1234)
#     lscv_res = lscv(Normal,data,FFT())
#     h = minimizer(lscv_res)
#     fkde = kde(Normal, h, data, FFT())
#     return fkde
# end

function calculate_Q1Q2percentile(data)
    tem = sort(data)
    println("================================================")
    println([tem[1250, 1], tem[3750, 1]])
    return println("================================================")
end
