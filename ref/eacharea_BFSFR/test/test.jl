# Date: 2021-09-29
using Pkg
Pkg.activate("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/.pkg/")
using DelimitedFiles, Random, Plots, PlotlyJS, PGFPlotsX, Gaston, PlotThemes
gr()
Random.seed!(1234)
include("src/BFLib_consideringFRlimit.jl")
include("src/calcualte_SFRresult.jl")
include("src/draw_SFRcurve.jl")
include("src/CASE1_draw_PDFinfomation.jl")
include("src/draw_SFRsurface.jl")
# include("CASE1_draw_SFRcurve.jl")
theme(:default)

xdata, bench1_ydata1, bench1_ydata2, bench1_ydata3, sampledata1 = Form_SFRcurveData(1, 1)

# large nosie
xdata, bench2_ydata1, bench2_ydata2, bench2_ydata3, sampledata2 = form_SFRcurveData(2, 1)

# case1 with withBESSandWinds
# !large noise
xdata, bench3_ydata1, bench3_ydata2, bench3_ydata3, sampledata3 = form_SFRcurveData(1, 2)
# large nosie
xdata, bench4_ydata1, bench4_ydata2, bench4_ydata3, sampledata4 = form_SFRcurveData(2, 2)

p6, p7 = draw_sfr_surfacedistribution(sampledata1, sampledata2)
p6

# FIXME - draw_sfr_surfacedistribution
Plots.plot(sampledata1[100, :], legeng = false)

using Plots, KernelDensity
num = 2048
kde_xdata, kde_ydata = zeros(size(sampledata1, 1), num), zeros(size(sampledata1, 1), num)
maximum(kde(sampledata1[4, :]).x), minimum(kde(sampledata1[4, :]).x)
maximum(kde(sampledata1[1, :]).density), minimum(kde(sampledata1[1, :]).density)

new_sampledata1 = zeros(size(sampledata1))
maximum(sampledata1(1, :))
for i in 1:1024
    tem₁ = maximum(sampledata1[i, :])
    tem₂ = minimum(sampledata1[i, :])
    new_sampledata1[i, :] .= (sampledata1[i, :] .- tem₂ * ones(1, 100)[1, :]) / (tem₁ - tem₂)
end

for i in 2:1201
    kde_xdata[i, :], kde_ydata[i, :] = kde(new_sampledata1[i, :]).x[:, 1], kde(new_sampledata1[i, :]).density[:, 1]
end
kde_xdata
kde_ydata
xdata = collect(1:1:2048)
ydata = collect(1:1:2048)
p1 = Plots.plot(kde_xdata[2, :], zeros(size(kde_ydata[2, :])), kde_ydata[2, :], legend = false, ls = :dash, lw = 0.5, color = :black, alpha = 0.5)
for i in 3:1201
    p1 = Plots.plot!(kde_xdata[i, :], zeros(size(kde_ydata[i, :])) .+ i, kde_ydata[i, :])
end
p1

# Plots.plot(kde_xdata[4,:], kde_ydata[4,:], legend = false)
# Plots.plot!(kde_xdata[5,:], kde_ydata[5,:], legend = false)
# Plots.plot!(kde_xdata[6,:], kde_ydata[6,:], legend = false)
# Plots.plot!(kde_xdata[7,:], kde_ydata[7,:], legend = false)
# Plots.plot!(kde_xdata[8,:], kde_ydata[8,:], legend = false)
# Plots.plot!(kde_xdata[9,:], kde_ydata[9,:], legend = false)

using Plots
Plots.plot(rand(10), rand(10), lc = colorant"#a00000", legend = false)

temflag = 0
Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter(temflag)
D, M, H, Tᵣ, Fₕ, R, K = Dg, Mg, Hg, Tg, Fg, Rg, Kg
R = Rg / Kg
δp = δp * 1.0
wₙ = sqrt((D + K / R) / (2 * H * Tᵣ))
ζ = (2 * H + (Fₕ * (K / R) + D) * Tᵣ) / (2 * sqrt(2 * H * Tᵣ) * sqrt(D + K / R))
# ζ = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
wᵣ = wₙ * sqrt(1 - ζ^2)
ψ = asin(sqrt(1 - ζ^2))

xdata = collect(0:δt:endtime)
ydata = zeros(size(xdata, 1), 1)
f_base = 50

for i in 1:size(xdata, 1)
    t = xdata[i, 1]
    # δf = R * δp / (D * R + 1)
    # δf = δf * (1 + α * exp(-1.0 * ζ * wₙ * t) * sin(wᵣ * 1.0 * t + ψ))
    δf = δp / (2 * H * Tᵣ * (wₙ^2))
    δf = δf + δp / (2 * Hg * wᵣ) * exp(-ζ * wₙ * t) * (sin(wᵣ * t) - 1 / (wₙ * Tᵣ) * sin(wᵣ * t + ψ))
    ydata[i, 1] = f_base - δf
end
ydata[1:2, 1] = ydata[1:2, 1] .* 1.00
ydata[:, 1] = ydata[:, 1] .+ 0.0
different_ASFR = zeros(size(xdata, 1), 1)
increment_Padd = zeros(size(xdata, 1), 1)
for i in 1:Int64(size(xdata, 1) - 1)
    different_ASFR[i, 1] = (ydata[i + 1, 1] - ydata[i, 1]) / δt
    str = (Fg + (1 - Fg) / Tg) * exp(-1.0 / Tg * i * δt)
    increment_Padd[i, 1] = (Kg / Rg) * str * (f_base - ydata[i, 1])
end
