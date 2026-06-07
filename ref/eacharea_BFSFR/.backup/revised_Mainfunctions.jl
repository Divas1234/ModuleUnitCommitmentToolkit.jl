include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl")

if Sys.iswindows()
	figpath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\"
elseif Sys.isapple()
	figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/"
end
# figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/"

# ANCHOR - generate frequencydynamic data under different uncertain variability environment
"""
	distribution_type: the uncertain variability distribution type,
	- "Gaussian" for uncertain variability following Gaussian distribution
	- "Weibull" for uncertain variability following Weibull distribution
	- "None" for FCR binding test

	whitenoise_parameter: the parameter for the white noise
	fcr_binding: the binding of FCR for additional power when providing frequency supporting
"""
whitenoise_parameter_vec = 1e-4:1e-4:5e-3
distribution_type = "Gaussian"
for whitenoise_parameter in whitenoise_parameter_vec
	automatic_workflow_function(figpath, distribution_type, whitenoise_parameter)
end

# ANCHOR - get structured frequency derivation data through BF-SFR
file_name = "converter_yes_little_noise.csv"
distribution_type = "Weibull" # "Weibull"
sum_frequencyderivatoins_data = get_sumstructed_frequencyderivation_data(file_name, distribution_type)
file_dir_abs = joinpath(pwd(), "res", "$distribution_type(various_uncertain_variability_features)")

@assert isdir(file_dir_abs)
# """
# 	# located at the end of each folders ()
# 	# ./res/Gaussian(various_uncertain_variability_features)
# 	# ./res/Weibull(various_uncertain_variability_features)
# """
CSV.write(joinpath(file_dir_abs, "$distribution_type"*"_frequencyderivations_data.csv"), sum_frequencyderivatoins_data)

current_dir = pwd()
tar_file = joinpath(file_dir_abs, "Weibull_frequencyderivations_data.csv")
des_file = joinpath(pwd(), "res", "Weibull_frequencyderivations_data.csv")
cp(tar_file, des_file, force = true)

run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_Gaussian_frequencyderivations_underdifferent_uncertain_cases.R`)
run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_Weiibull_frequencyderivations_underdifferent_uncertain_cases.R`)

# ANCHOR testing binding FCR
fcr_threshold_parameter_vec = collect(6.0:0.5:8.0);
whitenoise_parameter = 3e-4;
distribution_type = "None";
for fcr_threshold in fcr_threshold_parameter_vec
	automatic_workflow_function(figpath, distribution_type, whitenoise_parameter, fcr_threshold)
end

# move folders to fcr_binding folder for dealing with.
source_dir = joinpath(pwd(), "res")
target_dir = joinpath(source_dir, "fcr_bindings")
mkpath(target_dir)
tem = filter(x -> isdir(joinpath(source_dir, x)) && occursin(r"^fcr_binding\(\d+\)$", x), readdir(source_dir))
dirs = !isempty(tem) ? tem : filter(x -> isdir(joinpath(source_dir, x)) && occursin(r"^fcr_binding\(\d+\.\d+\)$", x), readdir(source_dir))
fcr_bindings_folders = joinpath.(source_dir, dirs)
for d in fcr_bindings_folders
	src = d
	dest = joinpath(target_dir, basename(d))
	mv(src, dest, force = true)
	println("Moved $src -> $dest")
end

function get_figures_frequencyderivations_withDiff_frequencyreserves()
	# NOTE - the following code is for testing the FCR binding with different uncertain variability features
	file_name_list = ["converter_yes_little_noise.csv", "converter_yes_big_noise.csv", "converter_not_little_noise.csv", "converter_not_big_noise.csv"
	]
	distribution_type = "None" # "Weibull"
	function raw_frequencyderivations_differentmethods(file_name, distribution_type)
		sum_frequencyderivatoins_data = get_sumstructed_frequencyderivation_data(file_name, distribution_type)
		file_dir_abs = joinpath(pwd(), "res", "fcr_bindings")
		CSV.write(joinpath(file_dir_abs, string("fcr_bindings_frequencyderivations_", "$file_name")), sum_frequencyderivatoins_data)
	end

	for file_name in file_name_list
		raw_frequencyderivations_differentmethods(file_name, distribution_type)
		@show re_source_dir = joinpath(target_dir, ("fcr_bindings_frequencyderivations_" * "$file_name"))
		@show re_target_dir = joinpath(source_dir, ("fcr_bindings_frequencyderivations_" * "$file_name"))
		mv(re_source_dir, re_target_dir, force = true)
	end

	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_not_big_noise.R`)
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_not_little_noise.R`)
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_yes_big_noise.R`)
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_yes_little_noise.R`)
end

get_figures_frequencyderivations_withDiff_frequencyreserves()