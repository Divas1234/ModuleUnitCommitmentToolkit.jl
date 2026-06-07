using Logging
disable_logging(Logging.Warn) # disable_logging
# disable_logging(Logging.BelowMinLevel) # enable logging
include("src/environment_config.jl")
include("datavis_utils.jl")

#? boundrycondition
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad = readxlssheet();
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData);

winds, NW = genscenario(WindsFreqParam, 1);

#ANCHOR - generating winds and load curve and save them into ./output/boundaryconditions folder
# get_winds_and_loadcurves(winds, loads)

# boundrycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit,
# 	loads::load, lines::transmissionline, winds::wind, stroges::stroge);

μ, σ = 0, 0.5e-3
flag_method_type = 1
NN = 10 # sampled scenarios for chance constraints
fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(units, winds, NG, NW, NN, flag_method_type, μ, σ)

# LINK check withFCR limits
fcr_thres_vector = collect(0.00025:0.0005:0.00675)
confidence_vector = collect(0.50:0.05:0.95)
res_vectors = zeros(length(fcr_thres_vector), length(confidence_vector))

e_x₀, e_p₀, e_pᵨ, e_pᵩ, e_seq_sr⁺, e_seq_sr⁻, e_pss_charge_p⁺, e_pss_charge_p⁻, e_su_cost, e_sd_cost, e_prod_cost,
e_cost_sr⁺, e_cost_sr⁻ = enhance_FCUC_scucmodel_withFCR(NN, NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, fittingparameter_vector, fcr_thres_vector[end - 3, 1],
	confidence_vector[end - 3, 1],);
savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3);

obj_dir = joinpath(pwd(), "littlecase//output//enhance_pros//")
txt_files_list = filter(f -> endswith(f, ".txt") && isfile(joinpath(obj_dir, f)), readdir(obj_dir; join = true))

des_dir = joinpath(pwd(), "littlecase//output//enhance_pros//withFCR//")
for file_dir in txt_files_list
	des_file_dir = joinpath(des_dir, basename(file_dir))
	mv(file_dir, des_file_dir; force = true)
end

# LINK check withoutFCR limits
e_x₀, e_p₀, e_pᵨ, e_pᵩ, e_seq_sr⁺, e_seq_sr⁻, e_pss_charge_p⁺, e_pss_charge_p⁻, e_su_cost, e_sd_cost, e_prod_cost,
e_cost_sr⁺, e_cost_sr⁻ = enhance_FCUC_scucmodel_withoutFCR(NN, NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, fittingparameter_vector);
savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3);
txt_files_list = filter(f -> endswith(f, ".txt") && isfile(joinpath(obj_dir, f)), readdir(obj_dir; join = true))

des_dir = joinpath(pwd(), "littlecase//output//enhance_pros//withoutFCR//")
for file_dir in txt_files_list
	des_file_dir = joinpath(des_dir, basename(file_dir))
	mv(file_dir, des_file_dir; force = true)
end

#NOTE other models.

x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻ = FCUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param);
savebalance_result(p₀, pᵨ, pᵩ, pss_charge_p⁺, pss_charge_p⁻, 2)

bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost,
bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻ = SUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)
savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)

# NOTE - frequency nadir comparisons

# ?nadir
model_types = "RFCUC"
RFCUC_nadir = get_frequencyderivation(units::unit, winds::wind, NG, NW, e_x₀, model_types)
model_types = "FCUC"
FCUC_nadir = get_frequencyderivation(units::unit, winds::wind, NG, NW, x₀, model_types)
model_types = "TUC"
TUC_nadir = get_frequencyderivation(units::unit, winds::wind, NG, NW, bench_x₀, model_types)

nadir_res_vectors = zeros(3, 24)
nadir_res_vectors[1, :] = RFCUC_nadir
nadir_res_vectors[2, :] = FCUC_nadir
nadir_res_vectors[3, :] = TUC_nadir
nadir_res_vectors = nadir_res_vectors / 1.25
using Plots, DataFrames
Plots.plot(nadir_res_vectors')
DataFrames.DataFrame(nadir_res_vectors, :auto)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\nadir.csv", DataFrames.DataFrame(nadir_res_vectors, :auto); writeheader = false)

# !rocof
rfcuc_sumH, rfcuc_sumRoCoF = get_rocof_vals(units, e_x₀)
fcuc_sumH, fcuc_sumRoCoF = get_rocof_vals(units, x₀)
tuc_sumH, tuc_sumRoCoF = get_rocof_vals(units, bench_x₀)
rocof_res_vectors = zeros(3, 24)
rocof_res_vectors[1, :] = rfcuc_sumRoCoF
rocof_res_vectors[2, :] = fcuc_sumRoCoF
rocof_res_vectors[3, :] = tuc_sumRoCoF
rocof_res_vectors = rocof_res_vectors / 1.25
Plots.plot(rocof_res_vectors')
DataFrames.DataFrame(rocof_res_vectors, :auto)
CSV.write("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\rocof.csv", DataFrames.DataFrame(rocof_res_vectors, :auto); writeheader = false)
