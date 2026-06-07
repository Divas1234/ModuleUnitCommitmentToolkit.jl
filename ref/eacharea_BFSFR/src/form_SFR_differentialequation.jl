# different-equation from the original SFR model
using Plots
function formparameter()
	D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
	Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = M, H, D, Tᵣ, R, Fₕ, K, 6.1, 60
	wₙ = sqrt((D * R + 1) / (2 * H * R * Tᵣ))
	ζ = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
	wᵣ = wₙ * sqrt(1 - ζ^2)
	α = sqrt(abs((1 - 2 * Tᵣ * ζ * wₙ + Tᵣ^2 * wᵣ^2) / (1 - ζ^2)))
	ψ = atan((wᵣ * Tᵣ) / (1 - ζ * wₙ * Tᵣ)) - atan(sqrt(1 - ζ^2) / ζ * (-1))
	xdata = collect(0:0.05:endtime)
	ydata = zeros(size(xdata, 1), 1)
	f_base = 50
	for i in eachindex(xdata)
		# for i in 1:size(xdata, 1)
		t = xdata[i, 1]
		δf = R * δp / (D * R + 1)
		δf = δf * (1 + α * exp(-1.0 * ζ * wₙ * t) * sin(wᵣ * 1.25 * t + ψ))
		ydata[i, 1] = f_base - δf
	end
	# ydata[1:2, 1] = ydata[1:2, 1] .* 1.005
	# ydata[:, 1] = ydata[:, 1] .+ 0.1
	return xdata, ydata, Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime
end

xdata, ydata, Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter()
Plots.plot(xdata, ydata)

# form differential equation
function differential_SFR()
	tem1, tem2, Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter()
	xdata = collect(0:0.05:endtime)
	ydata = zeros(size(xdata, 1), 1)
	zdata = zeros(size(xdata, 1), 1)
	gradient_data = zeros(size(xdata, 1), 1)
	Δt = 0.05
	Δp = δp * (-1.0)
	for i in 2:size(xdata, 1)
		δfₜ = ydata[i-1, 1]
		β = Fg + (1 - Fg) / (Tg) * exp(-1.0 / Tg * xdata[i-1, 1])
		δp_addₜ = (Kg / Rg) * β * δfₜ
		temp_δpₜ = 1.0 * (Δp - δp_addₜ - Dg * δfₜ)
		grad_δfₜ = temp_δpₜ / (2 * Hg)
		temp_δfₜ = δfₜ + grad_δfₜ * Δt
		Δp = Δp - δp_addₜ * Δt
		ydata[i, 1] = temp_δfₜ
		zdata[i, 1] = temp_δpₜ
		gradient_data[i, 1] = grad_δfₜ
	end
	p1 = Plots.plot(xdata, gradient_data, label = "Gradient")
	p2 = Plots.plot(xdata, ydata, label = "frequency")
	p3 = Plots.plot(xdata, zdata, label = "mismatch_power")
	p0 = Plots.plot(p1, p2, p3; layout = @layout[a; b; c])
	return p0
end

differential_SFR()
