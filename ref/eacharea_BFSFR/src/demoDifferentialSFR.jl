using Plots, DataFrames
const δt = 0.05

function formparameter()
    D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = M, H, D, Tᵣ, R, Fₕ, K, 6.1 * 0.5, 60
    return Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime
end

function discretized_SFR()
    δf, δf_grad, δp_add = zeros(1201, 1), zeros(1201, 1), zeros(1201, 1)
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter()

    for i in 2:Int64(1201)
        δf_grad[i, 1] = (δp - Dg * δf[i - 1, 1] - δp_add[i - 1, 1]) / (2 * Hg)
        δf[i, 1] = δf[i - 1, 1] + δf_grad[i, 1] * δt

        # sub_δp_add = (Kg / Rg) * Fg * δf[i, 1] * δt
        # α = (Kg / Rg) * (1 - Fg) / Tg * exp((-1 / Tg) * ((i - 1) * δt))
        # tem₁, tem₂ = 0, 0
        # for j in 1:(i + 1)
        #     tem₁ = tem₁ + exp((1 / Tg) * (i * δt)) * δf[i - 1, 1]
        #     tem₂ = tem₂ + exp((1 / Tg) * (i * δt)) * δf[i, 1]
        # end
        # δp_add[i, 1] = sub_δp_add + α * sum(tem₁ + tem₂) * δt

        tem₁, tem₂, tem₃ = 0, 0, 0
        α, β = Fg * (Kg / Rg) + Mg / Tg, (Dg + 1 / Rg) / Tg
        for j in 1:i
            tem₁ = tem₁ + β * δf[j, 1] * δt
        end
        # tem₁ = sum(β * δf[j,1] * δt for j in 1:i)
        tem₂ = α * δf[i, 1]
        tem₃ = (1 / Tg) * δp * (i * δt)
        δp_add[i, 1] = tem₁ + tem₂ - tem₃
    end
    return δf, δp_add
end

function frequencydynamic_ASFR()
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter()
    D, M, H, Tᵣ, Fₕ, R, K = Dg, Mg, Hg, Tg, Fg, Rg, Kg

    R = Rg / Kg
    δp = δp * 1.0

    wₙ = sqrt((D + K / R) / (2 * H * Tᵣ))
    ζ = (2 * H + (Fₕ * (K / R) + D) * Tᵣ) / (2 * sqrt(2 * H * Tᵣ) * sqrt(D + K / R))
    # ζ = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
    wᵣ = wₙ * sqrt(1 - ζ^2)
    ψ = asin(sqrt(1 - ζ^2))
    # α = sqrt(abs((1 - 2 * Tᵣ * ζ * wₙ + Tᵣ^2 * wᵣ^2) / (1 - ζ^2)))
    # ψ = atan((wᵣ * Tᵣ) / (1 - ζ * wₙ * Tᵣ)) - atan(sqrt(1 - ζ^2) / ζ * (-1))

    xdata = collect(0:δt:endtime)
    ydata = zeros(size(xdata, 1), 1)
    f_base = 50

    for i in eachindex(xdata)
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
    return ydata, different_ASFR, increment_Padd
end

δf, δp_add = discretized_SFR()
ydata, different_ASFR, increment_Padd = frequencydynamic_ASFR()

plot(-δf)
show(DataFrame([δf δp_add], :auto))

# plot!(ydata .- 50)
# plot(δp_add)
# println(δp_add)
