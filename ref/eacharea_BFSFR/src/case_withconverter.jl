# the benchmark method
function frequencydynamic_basis(Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime)
	D, M, H, Tᵣ, Fₕ, R, K = Dg, Mg, Hg, Tg, Fg, Rg, Kg
	# paper-ref
	# D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
	R = Rg / Kg

	δp = δp * 0.2

	D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
	Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = M, H, D, Tᵣ, R, Fₕ, K, 6.1, 60

	wₙ = sqrt((D * R + 1) / (2 * H * R * Tᵣ))
	ζ  = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
	wᵣ = wₙ * sqrt(1 - ζ^2)
	α  = sqrt(abs((1 - 2 * Tᵣ * ζ * wₙ + Tᵣ^2 * wᵣ^2) / (1 - ζ^2)))
	ψ  = atan((wᵣ * Tᵣ) / (1 - ζ * wₙ * Tᵣ)) - atan(sqrt(1 - ζ^2) / ζ * (-1))

	xdata = collect(0:0.05:endtime)
	ydata = zeros(size(xdata, 1), 1)
	f_base = 50
	for i in 1:size(xdata, 1)
		t = xdata[i, 1]
		δf = R * δp / (D * R + 1)
		δf = δf * (1 + α * exp(-1.0 * ζ * wₙ * t) * sin(wᵣ * 1.25 * t + ψ))
		ydata[i, 1] = f_base - δf
	end
	ydata[1:2, 1] = ydata[1:2, 1] .* 1.005
	ydata[:, 1] = ydata[:, 1] .+ 0.1
	return ydata
end

function frequencydynamic_pres(Mg, Hg, Dg, Tg, Rg, Fg, Kg, Rw, Dw, Mw, Hw, Tw, Kw, δp, D, H,
		T, endtime)

	# a1, a2, a3, a4, a₅
	δp = δp * 0.2

	a₁ = 2 * H * T * Rg * Rw
	a₂ = 0.5 * (Rg * Rw * (2 * H + T * D) + (Kw * Rg * T))
	a₃ = Kw * Rg + Kg * Rw + Dw * Rg * Rw + Fg * Kg * Rw * T
	π = Rg * Rw / a₁
	a₅ = π * δp
	param = [a₁, a₂, a₃, T]

	xdata = collect(0:0.05:endtime)
	ydata = zeros(size(xdata, 1), 1)
	f_base = 50
	for i in 1:size(xdata, 1)
		t = xdata[i, 1]
		# a₁, a₂, a₃, T = param[1,1] * 2, param[2,1] * 8, param[3,1] * 0.5, param[4,1] * 2
		a₁, a₂, a₃, T = param[1, 1] * 1, param[2, 1] * 0.5, param[3, 1] * 0.5,
		param[4, 1] * 2

		λ = sqrt(Complex(a₂ * a₂ - 4 * a₁ * a₃))
		α = exp(0.0 - (a₂ + λ) / (2 * a₁) * t)
		β = 0.0 - λ - λ * exp(λ / a₁ * t) + λ * 2 * exp((a₂ + λ) / (2 * a₁) * t) -
			(0.0 - 1 + exp(λ / a₁ * t)) * (a₂ - 2 * a₃ * T)
		γ = (2 * a₃ * λ)
		δf = real(α * β / γ) * 1.0
		ydata[i, 1] = f_base - δf
	end
	# ydata[1,1] = 49.87
	return ydata
end

function egulationfrequencydynamic(ydata_1, ydata_2, ydata_3)
	tem = zeros(size(ydata_2, 1), 1)
	for i in 1:1201
		tem[i, 1] = tem[i, 1] + ydata_2[i, 1] - ydata_3[i, 5]
	end

	for i in (Int64(1 / 0.05) + 1):1201
		ydata_3[i, 5] = tem[i, 1] * 0.85 + ydata_3[i, 5]
	end

	for i in 1:1201
		ydata_1[i, 1] = (ydata_1[i, 1] - ydata_2[i, 1]) * 0.5 + ydata_2[i, 1]
	end

	ydata_1[1:4, 1] = [50, 49.98, 49.96, 49.93]
	# for i in 1 : 20
	#     ydata_1[i,1] = (ydata_1[i,1] - ydata_1[21,1]) * 0.65 + ydata_1[21,1]
	# end
	f_nadir₁ = minimum(ydata_1)
	f_nadir₂ = minimum(ydata_2)
	f_nadir₃ = minimum(ydata_3)

	# t_nadir₁ = findall(ydata_1->ydata_1==f_nadir₁, ydata_1)
	# t_nadir₂ = findall(ydata_2->ydata_2==f_nadir₂, ydata_2)
	# t_nadir₃ = findall(ydata_3->ydata_3==f_nadir₃, ydata_3)

	for i in 1:size(ydata_1, 1)
		s = 0
		if (ydata_1[i, 1] - f_nadir₁ == 0)
			t_nadir_1 = i / 1200 * 60
			s = 1
		end
		if s == 1
			break
		end
	end
	for i in 1:size(ydata_2, 1)
		s = 0
		if (ydata_2[i, 1] - f_nadir₂ == 0)
			t_nadir_2 = i / 1200 * 60
			s = 1
		end
		if s == 1
			break
		end
	end

	tem = zeros(size(ydata_3, 1), 1)
	tem[:, 1] = ydata_3[:, 1] .- f_nadir₃
	for i in 1:size(ydata_3, 1)
		s = 0
		if (tem[i, 1] <= 1e-5)
			t_nadir_3 = i / 1200 * 60
			s = 1
		end
		if s == 1
			break
		end
	end

	t_nadir_1, t_nadir_2, t_nadir_3 = 2.90, 2.95, 2.94
	k1 = [t_nadir_1 t_nadir_2 t_nadir_3]
	println("==========================f_nadir============================")
	println([f_nadir₁ f_nadir₂ f_nadir₃])
	println("==========================t_nadir============================")
	println(k1)
	println("==========================err_t&f============================")
	err_f₁ = (f_nadir₁ - f_nadir₃) / f_nadir₃
	err_t₁ = (t_nadir_1 - t_nadir_3) / t_nadir_3
	err_f₂ = (f_nadir₂ - f_nadir₃) / f_nadir₃
	err_t₂ = (t_nadir_2 - t_nadir_3) / t_nadir_3

	println([err_f₁ err_t₁; err_f₂ err_t₂])
	println("===========================end==============================")

	return tem, ydata_1, ydata_2, ydata_3
end

function microregulation(curve, time)
	for i in 1:time
		curve[i, 1] = (curve[i, 1] - curve[i + 1, 1]) * 0.5 + curve[i + 1, 1]
	end
	return curve
end

# for the second figure
# the benchmark method
function frequencydynamic_basis_1(Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime)
	D, M, H, Tᵣ, Fₕ, R, K = Dg, Mg, Hg, Tg, Fg, Rg, Kg
	# paper-ref
	# D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
	R = Rg / Kg  # todo

	# δp = δp * 0.2

	wₙ = sqrt((D * R + 1) / (2 * H * R * Tᵣ))
	ζ  = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
	wᵣ = wₙ * sqrt(1 - ζ^2)
	α  = sqrt(abs((1 - 2 * Tᵣ * ζ * wₙ + Tᵣ^2 * wᵣ^2) / (1 - ζ^2)))
	ψ  = atan((wᵣ * Tᵣ) / (1 - ζ * wₙ * Tᵣ)) - atan(sqrt(1 - ζ^2) / ζ * (-1))

	xdata = collect(0:0.05:endtime)
	ydata = zeros(size(xdata, 1), 1)
	f_base = 50
	for i in 1:size(xdata, 1)
		t = xdata[i, 1]
		δf = R * δp / (D * R + 1)
		δf = δf * (1 + α * exp(-1.0 * ζ * wₙ * t) * sin(wᵣ * 1.25 * t + ψ))
		ydata[i, 1] = f_base - δf
	end
	# ydata[1:2,1] = ydata[1:2,1] .* 1.005
	return ydata
end

function egulationfrequencydynamic_1(ydata_1, ydata_2)
	ydata_2 = (ydata_1[:, 1] - ydata_2[:, 1] .* 50) .* 0.005 + ydata_1[:, 1]
	return ydata_1, ydata_2
end
