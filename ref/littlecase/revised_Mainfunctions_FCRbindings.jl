using Logging
disable_logging(Logging.Warn) # disable_logging
include("datavis_utils.jl")
# disable_logging(Logging.BelowMinLevel) # enable logging
include("src/environment_config.jl")

#? boundrycondition
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad = readxlssheet();
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData,);

winds, NW = genscenario(WindsFreqParam, 1);

#ANCHOR - generating winds and load curve and save them into ./output/boundaryconditions folder
get_winds_and_loadcurves(winds, loads)

# boundrycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit,
# 	loads::load, lines::transmissionline, winds::wind, stroges::stroge);

μ, σ = 0, 0.5e-3
flag_method_type = 1
NN = 10 # sampled scenarios for chance constraints
fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(
	units, winds, NG, NW, NN, flag_method_type, μ, σ,)

# NOTE - comparing the scheduling cost with/without FCR restrictions

#! test the maximum threshold of frequency containment reserve
fcr_thres_vector = collect(0.00025:0.0005:0.00675)
confidence_vector = collect(0.50:0.05:0.95)
res_vectors = zeros(length(fcr_thres_vector), length(confidence_vector))
l1, l2 = length(fcr_thres_vector), length(confidence_vector)
su_result_vector, sd_result_vector, op_result_vector, reserveplus_result_vector, reserveminus_result_vector = zeros(l1, l2), zeros(l1, l2), zeros(l1, l2), zeros(l1, l2), zeros(l1, l2)
for i in 1:l1
	for j in 1:l2
		try
			~, ~, ~, ~, ~, ~, ~, ~, e_su_cost, e_sd_cost, e_prod_cost,
			e_cost_sr⁺, e_cost_sr⁻ = enhance_FCUC_scucmodel_withFCR(
				NN, NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, fittingparameter_vector, fcr_thres_vector[i, 1], confidence_vector[j, 1],)
			# savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3);
			# fcr_thres = fcr_thres + 0.0005
			su_result_vector[i, j] = e_su_cost
			sd_result_vector[i, j] = e_sd_cost
			op_result_vector[i, j] = e_prod_cost
			reserveplus_result_vector[i, j] = e_cost_sr⁺
			reserveminus_result_vector[i, j] = e_cost_sr⁻
		catch e
			@info the maximum fcr_threshold found, "fcr_thres" = fcr_thres_vector[i, 1]
			break
		end
	end
end
data_su_result_vector = DataFrames.DataFrame(su_result_vector, :auto)
data_sd_result_vector = DataFrames.DataFrame(sd_result_vector, :auto)
data_op_result_vector = DataFrames.DataFrame(op_result_vector, :auto)
data_reserveplus_result_vector = DataFrames.DataFrame(reserveplus_result_vector, :auto)
data_reserveminus_result_vector = DataFrames.DataFrame(reserveminus_result_vector, :auto)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_su_result_vector.csv", data_su_result_vector)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_sd_result_vector.csv", data_sd_result_vector)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_op_result_vector.csv", data_op_result_vector)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_reserveplus_result_vector.csv", data_reserveplus_result_vector)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_reserveminus_result_vector.csv", data_reserveminus_result_vector)

e_x₀, e_p₀, e_pᵨ, e_pᵩ, e_seq_sr⁺, e_seq_sr⁻, e_pss_charge_p⁺, e_pss_charge_p⁻, e_su_cost, e_sd_cost, e_prod_cost,
e_cost_sr⁺,
e_cost_sr⁻ = enhance_FCUC_scucmodel_withFCR(
	NN, NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, fittingparameter_vector, fcr_thres_vector[end - 3, 1], confidence_vector[end - 3, 1],);
savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3);

obj_dir = joinpath(pwd(), "output//enhance_pros//")
txt_files_list = filter(f -> endswith(f, ".txt") && isfile(joinpath(obj_dir, f)), readdir(obj_dir; join = true))

des_dir = joinpath(pwd(), "output//enhance_pros//withFCR//")
for file_dir in txt_files_list
	des_file_dir = joinpath(des_dir, basename(file_dir))
	mv(file_dir, des_file_dir; force = true)
end

e_x₀, e_p₀, e_pᵨ, e_pᵩ, e_seq_sr⁺, e_seq_sr⁻, e_pss_charge_p⁺, e_pss_charge_p⁻, e_su_cost, e_sd_cost, e_prod_cost,
e_cost_sr⁺, e_cost_sr⁻ = enhance_FCUC_scucmodel_withoutFCR(
	NN, NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, fittingparameter_vector,);
savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3);
txt_files_list = filter(f -> endswith(f, ".txt") && isfile(joinpath(obj_dir, f)), readdir(obj_dir; join = true))

des_dir = joinpath(pwd(), "output//enhance_pros//withoutFCR//")
for file_dir in txt_files_list
	des_file_dir = joinpath(des_dir, basename(file_dir))
	mv(file_dir, des_file_dir; force = true)
end

#NOTE other models.

# x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻ =FCUC_scucmodel(
# 	NT, NB, NG, ND, NC, units, loads, winds, lines, config_param);
# savebalance_result(p₀, pᵨ, pᵩ, pss_charge_p⁺, pss_charge_p⁻, 2)

# bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost,
# bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻ = SUC_scucmodel(
# 	NT, NB, NG, ND, NC, units, loads, winds, lines,
# 	config_param)
# savebalance_result(
# 	bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)

