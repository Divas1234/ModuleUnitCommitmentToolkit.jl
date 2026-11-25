using Plots
using LaTeXStrings

function draw_powerbalance(
    bench_x₀,
    bench_p₀,
    bench_pᵨ,
    bench_pᵩ,
    bench_seq_sr⁺,
    bench_seq_sr⁻,
    bench_pss_charge_p⁺,
    bench_pss_charge_p⁻,
    bench_su_cost,
    bench_sd_cost,
    bench_prod_cost,
    bench_cost_sr⁺,
    bench_cost_sr⁻,
    secnairos;
    winds,
    loads,
    NG::Int = size(bench_x₀, 1),
    NW::Int = length(winds.p_max),
    NT::Int = size(bench_p₀, 2),
    ND::Int = size(loads.load_curve, 1),
    NC::Int = div(size(bench_pss_charge_p⁺, 1), max(1, winds.scenarios_nums)),
)
    #! Plots power balance
    selected_scenarios = secnairos
    #! calculate different output of grid-connected generators
    conventional_generators_output = bench_p₀[(NG * (selected_scenarios - 1) + 1):(NG * selected_scenarios), 1:NT]
    winds_generators_mppt_output = zeros(NW, NT)
    for w in 1:NW
        winds_generators_mppt_output[w, :] = winds.scenarios_curve[selected_scenarios, 1:NT] * winds.p_max[w, 1]
    end
    winds_generators_output = winds_generators_mppt_output .- bench_pᵩ[(NW * (selected_scenarios - 1) + 1):(NW * selected_scenarios), 1:NT]
    loadcurtailments = bench_pᵨ[(ND * (selected_scenarios - 1) + 1):(ND * selected_scenarios), 1:NT]
    bess_discharge_power = NC > 0 ? bench_pss_charge_p⁻[(NC * (selected_scenarios - 1) + 1):(NC * selected_scenarios), 1:NT] : zeros(0, NT)
    bess_charge_power = NC > 0 ? bench_pss_charge_p⁺[(NC * (selected_scenarios - 1) + 1):(NC * selected_scenarios), 1:NT] : zeros(0, NT)
    #! calculate different output of samilar generators
    sum_conventional_generators_output = NG > 0 ? sum(conventional_generators_output; dims = 1)[1, :] : zeros(NT)
    sum_winds_generators_output = NW > 0 ? sum(winds_generators_output; dims = 1)[1, :] : zeros(NT)
    sum_loadcurtailments = ND > 0 ? sum(loadcurtailments; dims = 1)[1, :] : zeros(NT)
    sum_bess_discharge_power = NC > 0 ? sum(bess_discharge_power; dims = 1)[1, :] : zeros(NT)
    sum_bess_charge_power = NC > 0 ? sum(bess_charge_power; dims = 1)[1, :] : zeros(NT)
    #! NOTE: ploting
    basline_output = zeros(1, NT)[1, :]
    xdata = collect(1:NT)
    p1 = Plots.plot(
        xdata,
        basline_output;
        fillrange = sum_conventional_generators_output,
        size = (250, 280),
        xlabel = L"t / h",
        ylabel = L"\textrm{Output \,/\, p.u.}",
        framestyle = :box,
        foreground_color_grid = :grey,
        # lc = :cornflowerblue,
        tickfontfamily = "Palatino Bold",
        # legendfontfamily = "Palatino Bold",
        # fa=0.5,
        background_color_inside = :transparent,
        grid = :true,
        # foreground_color_legend = nothing,
        gc = 0.75,
        lw = 0.5,
        lc = :red,
        ls = :dash,
        xlims = (0, 25),
        ylims = (-1, 6.6),
        gridlinewidth = 1,
        # fillalpha = 0.5,
        c = RGB(159 / 255, 66 / 255, 64 / 255),
        # legend_columns=-1,
        label = L"\textrm{conventional \,\,units}",
        legend = :topright,
    )
    p1 = Plots.plot!(
        xdata,
        sum_conventional_generators_output;
        fillrange = sum_conventional_generators_output .+ sum_winds_generators_output,
        fillalpha = 0.95,
        lw = 0.5,
        ls = :dash,
        lc = :blue,
        c = RGB(94 / 255, 133 / 255, 149 / 255),
        label = L"\textrm{winds\,\, farms}",
    )
    p1 = Plots.plot!(
        xdata,
        sum_conventional_generators_output .+ sum_winds_generators_output;
        fillrange = sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power,
        fillalpha = 0.95,
        lc = :blue,
        ls = :dash,
        lw = 0.5,
        c = RGB(137 / 255, 176 / 255, 81 / 255),
        label = L"\textrm{BESS \,(discharge)}",
    )
    p1 = Plots.plot!(
        xdata,
        sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power;
        fillrange = sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power .+ sum_loadcurtailments,
        fillalpha = 0.95,
        ls = :dash,
        lw = 0.5,
        lc = :blue,
        c = RGB(251 / 255, 234 / 255, 90 / 255),
        label = L"\textrm{Load\, shedding}",
    )

    p1 = Plots.plot!(
        xdata,
        basline_output;
        fillrange = (-sum_bess_charge_power),
        fillalpha = 0.95,
        label = L"\textrm{BESS \,(charge)}",
        c = RGB(49 / 255, 163 / 255, 84 / 255),
    )

    p1 = Plots.plot!(xdata, -sum_bess_charge_power; ls = :dash, lw = 0.5, lc = :blue, label = "")

    return p1
end
