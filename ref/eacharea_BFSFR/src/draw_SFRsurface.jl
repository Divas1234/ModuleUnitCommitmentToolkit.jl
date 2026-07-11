#NOTE - surface
# sample -data1

function draw_sfr_surfacedistribution(sampledata1, sampledata2)
    new_sampledata = zeros(1201, 100)
    tem = zeros(1201, 2)
    for i in 1:1201
        tem[i, 1], tem[i, 2] = mean(sampledata1[i, :]), std(sampledata1[i, :])
    end

    Plots.plot(collect(1:1:1201), -tem[:, 1]; color = :lightblue, ribbon = tem[:, 2] .* 100, label = false)

    # tem[1:10, :] = tem[11:20, :]
    # Plots.plot(tem[:, 1])
    for i in 1:1201
        new_sampledata[i, :] = pdf.(Normal(0, tem[i, 2] * 20), collect(-0.1:(0.20 / 99):0.1))
    end

    if Sys.iswindows()
        sub_filepath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\out\\original_result.txt"
    elseif Sys.isapple()
        sub_filepath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/original_result.txt"
    end

    open(sub_filepath, "w") do io
        writedlm(io, [" "])
        return writedlm(io, sampledata1, '\t')
    end
    if Sys.iswindows()
        sub_filepath2 = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\out\\reformed_result.txt"
    elseif Sys.isapple()
        sub_filepath2 = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/reformed_result.txt"
    end
    open(sub_filepath2, "w") do io
        writedlm(io, [" "])
        return writedlm(io, new_sampledata, '\t')
    end

    xdata = collect(1:1:1201)
    ydata = collect(1:1:100)
    p1 = Plots.surface(
        ydata,
        xdata,
        new_sampledata;
        # zlims=(0, 1),
        size = (300, 300),
        # xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
        xlabel = L"\Delta f(t) / Hz",
        ylabel = L"t / s",
        zlabel = L"pdf",
        colorbar = false,
        tickfontfamily = "Palatino Bold",
        legendfontfamily = "Palatino Bold",
        alpha = 0.7,
        lw = 0.001,
        la = 0.75,
        lc = :blue,
        zlims = (0, 60),
        cmap = :rainbow_bgyr_35_85_c73_n256,
        # ratio = 5.5,
        # framestyle = :box,
        # color = :blues,
        xlims = (0, 100),
        xticks = (collect(0:50:100), collect(-0.10:0.1:0.10)),
        yticks = (collect(1:300:1201), collect(0:15:60)),
        camera = (60, 60),
    )
    filepath = pwd()

    #! sample - data2
    new_sampledata = zeros(1201, 100)
    tem = zeros(1201, 2)
    for i in 1:1201
        tem[i, 1], tem[i, 2] = mean(sampledata2[i, :]), std(sampledata2[i, :])
    end
    # tem[1:10, :] = tem[11:20, :]
    Plots.plot(tem[:, 2])
    for i in 1:1201
        new_sampledata[i, :] = pdf.(Normal(-0, tem[i, 2] * 20), collect(-0.1:(0.20 / 99):0.1))
    end

    if Sys.iswindows()
        sub_filepath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\out\\original_result1.txt"
    elseif Sys.isapple()
        sub_filepath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/original_result1.txt"
    end

    open(sub_filepath, "w") do io
        writedlm(io, [" "])
        return writedlm(io, sampledata2, '\t')
    end
    open(sub_filepath, "w") do io
        writedlm(io, [" "])
        return writedlm(io, new_sampledata, '\t')
    end

    xdata = collect(1:1:1201)
    ydata = collect(1:1:100)
    p2 = Plots.surface(
        ydata,
        xdata,
        new_sampledata;
        size = (300, 300),
        # zlims=(0, 1),
        # xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
        # alpha=0.85,
        # c=:Blues_9,
        xlabel = L"\Delta f(t) / Hz",
        ylabel = L"t /s",
        zlabel = L"pdf",
        # color = :blues,
        alpha = 0.7,
        lw = 0.001,
        la = 0.75,
        lc = :blue,
        cmap = :rainbow_bgyrm_35_85_c69_n256,
        colorbar = false,
        background_color_inside = :transparent,
        # xlabelfontsize = 8,
        # ylabelfontsize = 8,
        # zlabelfontsize = 8,
        xlims = (0, 100),
        zlims = (0, 60),
        tickfontfamily = "Palatino Bold",
        legendfontfamily = "Palatino Bolde",
        # framestyle = :box,
        xticks = (collect(0:50:100), collect(-0.1:0.1:0.10)),
        yticks = (collect(1:300:1201), collect(0:15:60)),
        camera = (60, 60),
    )
    return p1, p2
end
