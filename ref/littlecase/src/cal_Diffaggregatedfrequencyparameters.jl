function calculate_diffdynamicparameter(units, winds, Sampling_Statue, flag)
	# D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
	# Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = M, H, D, Tᵣ, R, Fₕ, K, 6.1, 60
	# # # ------------------log-----------------------
	# # # Mw, Hw, Dw, Rw, Re = 2.0, 1.0, 0.3, 1/0.4, 1/0.4
	# # Mw, Hw, Dw, Rw, Re = 2.0, 1.0, 0.3, 1/0.5, 1/0.4
	# # Mg, Hg, Dg = Mg + Mw, Hg + Hw, Dg + Dw + 1/0.5 + 0.0
	# # # --------------------------------------------
	NW = size(winds.p_max, 1)
	# normalized winds parameters through COI
	vsmFC_number = sum(winds.Fcmode[:, 1])
	doopFC_number = length(winds.Fcmode[:, 1]) - vsmFC_number
	adjustablewindsVSCpower = winds.Fcmode .* winds.p_max
	inverse_winds_Rw = zeros(NW, 1)
	for i in 1:NW
		if winds.Fcmode[i, 1] == 0
			inverse_winds_Rw[i, 1] = 1 / winds.Rw[i, 1]
		end
	end
	current_Kw = 1.0
	current_Dw = sum(winds.Dw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Dw
	current_Mw = sum(winds.Mw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Mw
	current_Hw = current_Mw / 2
	current_Rw =
		1 / sum(winds.Kw .* inverse_winds_Rw .* (ones(NW, 1) - winds.Fcmode) .* winds.p_max) /
		sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max))

	# units parameters
	adjustabletheramlpower = units.p_max .* Sampling_Statue
	current_Kg = 1.0
	current_Tg = mean(units.Tg)
	current_Fg_div_Rg =
		sum(units.Kg .* units.Fg ./ units.Rg .* adjustabletheramlpower) / sum(units.p_max)
	current_Rg = 1 / (sum(units.Kg ./ units.Rg .* adjustabletheramlpower) / sum(units.p_max)) # Kg
	current_Fg = current_Fg_div_Rg * current_Rg
	current_Dg = sum(units.Dg .* adjustabletheramlpower) / sum(units.p_max)
	current_Hg = sum(units.Hg .* adjustabletheramlpower) / sum(units.p_max)
	current_Mg = current_Hg * 2

	#  powers for intia frequency response
	localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
	sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) + sum(winds.p_max))
	p_step = maximum(units.p_max)

	# sumD and sumH
	current_sumD =
		(
			sum(units.Dg .* adjustabletheramlpower) + sum(
				winds.Dw .* winds.p_max .* winds.Fcmode +
				winds.Kw .* winds.p_max .* (ones(NW, 1) - winds.Fcmode),
			)
		) / sumapparentpower
	current_sumH =
		(sum(current_Mg .* adjustabletheramlpower) + sum(current_Mw .* adjustablewindsVSCpower)) /
		sumapparentpower / 2

	D, H, F, R, T, K, δp = current_sumD, current_sumH, current_Fg, current_Rg, current_Tg, current_Kg, p_step
	if flag == 1
		H = H + 0.5
		D = D + 0.5 + 0.2
	end
	endtime = 60
	return current_Kg, current_Rg, current_Kw, current_Rw, current_Dw
	# return Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime
end