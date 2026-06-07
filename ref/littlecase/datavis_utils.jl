using CSV
using JuliaFormatter

function get_winds_and_loadcurves(winds, loads)
	# Plots.plot(winds.scenarios_curve')
	windcurves = DataFrame(winds.scenarios_curve, :auto)
	loadcurves = DataFrame(loads.load_curve, :auto)
	saved_dir = joinpath(pwd(), "output/boundaryconditions/")
	CSV.write(joinpath(saved_dir, "winds_curves.csv"), windcurves)
	CSV.write(joinpath(saved_dir, "loads_curves.csv"), loadcurves)

	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\draw_loaddemand.R`)
	return run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\draw_windcurves.R`)
end

# TODO - compare frequency derivations produced by three UC models.
function get_frequencyderivation(units::unit, winds::wind, NG, NW, x_states, model_types)
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
	current_Rw = 1 / sum(winds.Kw .* inverse_winds_Rw .* (ones(NW, 1) - winds.Fcmode) .*
						 winds.p_max) /
				 sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max))

	#  powers for intia frequency response
	localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
	sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) +
						sum(winds.p_max))
	scalling_imbalanced_power = 1.0
	# model_types = "RFCUC"
	if model_types == "RFCUC"
		μ, σ = 0, 0.5e-3
		flag_method_type = 1
		num_NN = 10 # sampled scenarios for chance constraints
		fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(units,
			winds,
			NG,
			NW,
			NN,
			flag_method_type,
			μ,
			σ,)
		candiate_frequencyderivation = zeros(NN, NT)
		x = copy(x_states)
		for t in 1:NT
			for n in 1:num_NN
				fittingparameter = fittingparameter_vector[n, :] * (-1)
				candiate_frequencyderivation[n, t] = fittingparameter[1] / sumapparentpower *
													 (sum(x[:, t] .* units.Hg .* units.p_max) +
													  sum(current_Mw .* adjustablewindsVSCpower)) +
													 fittingparameter[2] / sum(units.p_max) *
													 (sum(x[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
													 fittingparameter[3] / sum(units.p_max) *
													 (sum(x[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
													 fittingparameter[4]
			end
		end
		@show candiate_frequencyderivation
		min_values = map(minimum, eachcol(candiate_frequencyderivation)) / scalling_imbalanced_power
	end

	if model_types == "FCUC" || model_types == "TUC"
		model_types = "FCUC"

		flag_method_type = 0
		fittingparameter = generate_fitting_parameters(units, winds, NG, NW, flag_method_type, 0)
		fittingparameter = fittingparameter * (-1)
		x = copy(x_states)
		candiate_frequencyderivation = zeros(1, NT)
		for t in 1:NT
			candiate_frequencyderivation[t] = fittingparameter[1, 1] / sumapparentpower *
											  (sum(x[:, t] .* units.Hg .* units.p_max) +
											   sum(current_Mw .* adjustablewindsVSCpower)) +
											  fittingparameter[1, 2] / sum(units.p_max) *
											  (sum(x[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
											  fittingparameter[1, 3] / sum(units.p_max) *
											  (sum(x[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
											  fittingparameter[1, 4]
		end
		min_values = candiate_frequencyderivation / scalling_imbalanced_power
	end
	return min_values
end

# TODO RoCoF
function get_rocof_vals(units, x_states)
	Δp = maximum(units.p_max[:, 1]) * 0.25
	scalling_imbalanced_power = 1.25
	aggregated_H = zeros(1, 24)
	aggregated_rocof = zeros(1, 24)
	f_base = 50
	p_base = 100
	x = copy(x_states)
	for t in 1:NT
		aggregated_H[1, t] = sum(winds.Mw[:, 1] .* winds.Fcmode[:, 1] .* winds.p_max[:, 1]) +
							 2 * sum(x[:, t] .* units.Hg[:, 1] .* units.p_max[:, 1]) /
							 (sum(units.p_max[:, 1]) + sum(winds.Fcmode .* winds.p_max))
		aggregated_rocof[1, t] = Δp / scalling_imbalanced_power / aggregated_H[1, t] * f_base
	end
	return aggregated_H, aggregated_rocof
end

# TODO - compare frequency derivations produced by three UC models.
function get_frequencyderivation(units::unit, winds::wind, NG, NW, x_states, model_types)
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
	current_Rw = 1 / sum(winds.Kw .* inverse_winds_Rw .* (ones(NW, 1) - winds.Fcmode) .*
						 winds.p_max) /
				 sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max))

	#  powers for intia frequency response
	localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
	sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) +
						sum(winds.p_max))
	scalling_imbalanced_power = 1.25
	# model_types = "RFCUC"
	if model_types == "RFCUC"
		μ, σ = 0, 0.5e-3
		flag_method_type = 1
		num_NN = 10 # sampled scenarios for chance constraints
		fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(
			units, winds, NG, NW, NN, flag_method_type, μ, σ,)
		candiate_frequencyderivation = zeros(NN, NT)
		x = copy(x_states)
		for t in 1:NT
			for n in 1:num_NN
				fittingparameter = fittingparameter_vector[n, :] * (-1)
				candiate_frequencyderivation[n, t] = fittingparameter[1] / sumapparentpower * (sum(x[:, t] .* units.Hg .* units.p_max) + sum(current_Mw .* adjustablewindsVSCpower)) +
													 fittingparameter[2] / sum(units.p_max) * (sum(x[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
													 fittingparameter[3] / sum(units.p_max) * (sum(x[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
													 fittingparameter[4]
			end
		end
		@show candiate_frequencyderivation
		min_values = map(minimum, eachcol(candiate_frequencyderivation)) / scalling_imbalanced_power
	end

	if model_types == "FCUC" || model_types == "TUC"
		model_types = "FCUC"

		flag_method_type = 0
		fittingparameter = generate_fitting_parameters(
			units, winds, NG, NW, flag_method_type, 0,)
		fittingparameter = fittingparameter * (-1)
		x = copy(x_states)
		candiate_frequencyderivation = zeros(1, NT)
		for t in 1:NT
			candiate_frequencyderivation[t] = fittingparameter[1, 1] / sumapparentpower * (sum(x[:, t] .* units.Hg .* units.p_max) + sum(current_Mw .* adjustablewindsVSCpower)) +
											  fittingparameter[1, 2] / sum(units.p_max) * (sum(x[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
											  fittingparameter[1, 3] / sum(units.p_max) * (sum(x[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
											  fittingparameter[1, 4]
		end
		min_values = candiate_frequencyderivation / scalling_imbalanced_power
	end
	return min_values
end

# TODO RoCoF
function get_rocof_vals(units, x_stateus)
	Δp = maximum(units.p_max[:, 1]) * 0.25
	scalling_imbalanced_power = 1.25
	aggregated_H = zeros(1, 24)
	aggregated_rocof = zeros(1, 24)
	x = copy(x_stateus)
	for t in 1:NT
		aggregated_H[1, t] = sum(winds.Mw[:, 1] .* winds.Fcmode[:, 1] .* winds.p_max[:, 1]) +
							 2 * sum(x[:, t] .* units.Hg[:, 1] .* units.p_max[:, 1]) / (sum(units.p_max[:, 1]) + sum(winds.Fcmode .* winds.p_max))
		aggregated_rocof[1, t] = Δp / scalling_imbalanced_power / aggregated_H[1, t]
	end
	return aggregated_H, aggregated_rocof
end
