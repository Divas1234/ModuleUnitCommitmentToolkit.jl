function formataggreatedparam(units, winds, NW, NG, Sampling_Statue)

	# normalized winds parameters through COI
	vsmFC_number            = sum(winds.Fcmode[:, 1])
	doopFC_number           = length(winds.Fcmode[:, 1]) - vsmFC_number
	adjustablewindsVSCpower = winds.Fcmode .* winds.p_max
	# current_Kw            = sum(winds.Kw ./ winds.Rw .* (ones(NW, 1) - winds.Fcmode) .* winds.p_max) / sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max)) # Kw
	inverse_winds_Rw = zeros(NW, 1)
	for i in 1:NW
		if winds.Fcmode[i, 1] == 0
			inverse_winds_Rw[i, 1] = 1 / winds.Rw[i, 1]
		end
	end
	current_Kw = sum(winds.Kw .* inverse_winds_Rw .* (ones(NW, 1) - winds.Fcmode) .* winds.p_max) / sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max))
	current_Dw = sum(winds.Dw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Dw
	current_Mw = sum(winds.Mw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Mw
	current_Hw = current_Mw / 2
	current_Rw = 1.0

	# units parameters
	adjustabletheramlpower = units.p_max .* Sampling_Statue
	current_Kg             = sum(units.Kg ./ units.Rg .* adjustabletheramlpower) / sum(adjustabletheramlpower) # Kg
	current_Tg             = sum(units.Tg .* adjustabletheramlpower) / sum(adjustabletheramlpower) # T
	current_Fg_and_Rg      = sum(units.Kg .* units.Fg ./ units.Rg .* adjustabletheramlpower) / sum(adjustabletheramlpower)
	current_Fg             = current_Fg_and_Rg / current_Kg
	current_Rg             = 1
	current_Dg             = sum(units.Dg .* adjustabletheramlpower) / sum(adjustabletheramlpower)
	current_Hg             = sum(units.Hg .* adjustabletheramlpower) / sum(adjustabletheramlpower)
	current_Mg             = current_Hg * 2

	# total powers
	#  powers for intia frequency response
	localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
	#  powers for primary and second frequency responses
	sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) + sum(winds.p_max))
	# potential prob. # δp
	p_step = maximum(units.p_max) * 1.0

	# sumD and sumH
	# current_sumD = (
	#     sum(units.Dg .* adjustabletheramlpower) +
	#     sum(winds.Dw .* winds.p_max .* winds.Fcmode + winds.Kw .* winds.p_max .* (ones(NW, 1) - winds.Fcmode))
	#     ) / sumapparentpower
	# current_sumH = (
	#     sum(current_Mg .* adjustabletheramlpower) +
	#     sum(current_Mw .* adjustablewindsVSCpower)
	#     ) / (sum(adjustabletheramlpower) + sum(adjustablewindsVSCpower)) / 2
	current_sumD = (sum(units.Dg .* adjustabletheramlpower)) / sumapparentpower
	current_sumH = (sum(current_Mg .* adjustabletheramlpower)) / (sum(adjustabletheramlpower) + sum(adjustablewindsVSCpower)) / 2

	# f_db = 0.2 # param-1 of deadarea frequencychange for units
	# t_db = -1 * current_M / current_D * log(1 - f_db * current_D / (current_M * p_step))

	# simplify parameters
	# part-1 units parameters
	Mg, Hg, Dg, Tg, Rg, Fg, Kg = current_Mg, current_Hg, current_Dg, current_Tg, current_Rg, current_Fg, current_Kg
	# part-2 winds parameters
	Rw, Dw, Mw, Hw, Tw, Kw = current_Rw, current_Dw, current_Mw, current_Hw, current_Tg, current_Kw
	# part-3 power unbalances
	δp = p_step
	D, H, T = current_sumD, current_sumH, Tg
	return Mg, Hg, Dg, Tg, Rg, Fg, Kg, Rw, Dw, Mw, Hw, Tw, Kw, δp, D, H, T

	# # a1, a2, a3, a4, a₅
	# a₁ = 2 * H * T * Rg * Rw
	# a₂ = 0.5 * (Rg * Rw * (2 * H + T * D) + (Kw * Rg * T))
	# a₃ = Kw * Rg + Kg * Rw + Dw * Rg * Rw + Fg * Kg * Rw * T
	# π  = Rg * Rw / a₁
	# a₅ = π * δp

	# β₁      = a₁ / a₃
	# γ₁      = sqrt(Complex(a₂^2 - a₁ * a₃))
	# γ₂      = sqrt(Complex(a₁ - 2 * a₂ * T * a₃ * T * T)) * sqrt(a₁)
	# t_nadir = a₁ * acosh(Complex(abs(a₁ - a₂ * T) / γ₂)) / γ₁
	# ℓ₁      = γ₁ / a₁
	# Δf      = β₁ * (exp(-a₂ / a₁) * cosh(Complex(ℓ₁ * t_nadir)) - 1 + (a₂ - a₃ * T) / γ₁ * sinh(Complex(ℓ₁ * t_nadir))) * (-1) / 10
	# f_nadir = 50.2 - abs(real(Δf)) + 0.1

	# return f_nadir, t_nadir, H, δp, Kg, Fg, Rg, Dg

end
