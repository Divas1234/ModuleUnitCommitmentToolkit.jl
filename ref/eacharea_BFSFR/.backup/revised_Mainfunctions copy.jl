# ====================================================================
# Main Functions and Workflow
# ====================================================================

# Import required modules and utility functions
include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl")

# Set figure save path based on operating system
if Sys.iswindows()
	figpath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\"
elseif Sys.isapple()
	figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/"
end
# figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/"

# ====================================================================
# Part 1: Generate Frequency Dynamic Data under Different Uncertain Variability Environments
# ====================================================================

# ANCHOR - Generate frequency dynamic data under different uncertain variability environments
# Parameter Description:
#   distribution_type: Uncertain variability distribution type
#     - "Gaussian"  : Gaussian distribution
#     - "Weibull"   : Weibull distribution
#     - "None"      : FCR binding test
#   whitenoise_parameter: White noise parameter
#   fcr_binding: FCR binding value for additional power when providing frequency support

whitenoise_parameter_vec = 1e-4:1e-4:5e-3
distribution_type = "Gaussian"
for whitenoise_parameter in whitenoise_parameter_vec
	automatic_workflow_function(figpath, distribution_type, whitenoise_parameter)
end

# ====================================================================
# Part 2: Obtain Structured Frequency Derivative Data via BF-SFR
# ====================================================================

# ANCHOR - Obtain structured frequency derivative data
file_name = "converter_yes_little_noise.csv"
distribution_type = "Weibull" # "Weibull"
sum_frequencyderivatoins_data = get_sumstructed_frequencyderivation_data(file_name, distribution_type)
file_dir_abs = joinpath(pwd(), "res", "$distribution_type(various_uncertain_variability_features)")

@assert isdir(file_dir_abs)
# Generated file locations:
#   ./res/Gaussian(various_uncertain_variability_features)
#   ./res/Weibull(various_uncertain_variability_features)
CSV.write(joinpath(file_dir_abs, "$distribution_type"*"_frequencyderivations_data.csv"), sum_frequencyderivatoins_data)

# Copy Weibull frequency derivative data to results directory
current_dir = pwd()
tar_file = joinpath(file_dir_abs, "Weibull_frequencyderivations_data.csv")
des_file = joinpath(pwd(), "res", "Weibull_frequencyderivations_data.csv")
cp(tar_file, des_file; force = true)

# Call R scripts to draw frequency derivative visualization figures
run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_Gaussian_frequencyderivations_underdifferent_uncertain_cases.R`)
run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_Weiibull_frequencyderivations_underdifferent_uncertain_cases.R`)

# ====================================================================
# Part 3: Test Results under Different FCR Binding Levels
# ====================================================================

# ANCHOR - Test different FCR binding levels
fcr_threshold_parameter_vec = collect(6.0:0.5:8.0);  # FCR binding parameter range
whitenoise_parameter = 3e-4;  # White noise parameter
distribution_type = "None";  # Distribution type
for fcr_threshold in fcr_threshold_parameter_vec
	automatic_workflow_function(figpath, distribution_type, whitenoise_parameter, fcr_threshold)
end

# ====================================================================
# Part 4: Organize and Move FCR Binding Related Folders
# ====================================================================

# Move generated FCR binding folders to a unified directory for processing
source_dir = joinpath(pwd(), "res")  # Source directory
target_dir = joinpath(source_dir, "fcr_bindings")  # Target directory
mkpath(target_dir)
tem = filter(x -> isdir(joinpath(source_dir, x)) && occursin(r"^fcr_binding\(\d+\)$", x), readdir(source_dir))
dirs = !isempty(tem) ? tem : filter(x -> isdir(joinpath(source_dir, x)) && occursin(r"^fcr_binding\(\d+\.\d+\)$", x), readdir(source_dir))
fcr_bindings_folders = joinpath.(source_dir, dirs)
# Iterate through and move folders
for d in fcr_bindings_folders
	src = d
	dest = joinpath(target_dir, basename(d))
	mv(src, dest; force = true)
	println("Moved $src -> $dest")  # Print movement information
end

# ====================================================================
# Part 5: Generate Frequency Derivative Figures under Different Frequency Reserve Levels
# ====================================================================

function get_figures_frequencyderivations_withDiff_frequencyreserves()
	# NOTE - The following code is for testing FCR binding with different uncertain variability features
	file_name_list = ["converter_yes_little_noise.csv", "converter_yes_big_noise.csv", "converter_not_little_noise.csv", "converter_not_big_noise.csv"
	]  # File list
	distribution_type = "None" # "Weibull" # Distribution type

	# Nested function: Process raw frequency derivative data
	function raw_frequencyderivations_differentmethods(file_name, distribution_type)
		sum_frequencyderivatoins_data = get_sumstructed_frequencyderivation_data(file_name, distribution_type)
		file_dir_abs = joinpath(pwd(), "res", "fcr_bindings")
		CSV.write(joinpath(file_dir_abs, string("fcr_bindings_frequencyderivations_", "$file_name")), sum_frequencyderivatoins_data)
	end

	# Process each file and move to target directory
	for file_name in file_name_list
		raw_frequencyderivations_differentmethods(file_name, distribution_type)
		@show re_source_dir = joinpath(target_dir, ("fcr_bindings_frequencyderivations_" * "$file_name"))
		@show re_target_dir = joinpath(source_dir, ("fcr_bindings_frequencyderivations_" * "$file_name"))
		mv(re_source_dir, re_target_dir; force = true)
	end

	# Call R scripts to generate frequency derivative visualization figures under various scenarios
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_not_big_noise.R`)  # Converter No, Big Noise
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_not_little_noise.R`)  # Converter No, Little Noise
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_yes_big_noise.R`)  # Converter Yes, Big Noise
	run(`Rscript D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\draw_frequencyderivations_withfcr_bindings_converter_yes_little_noise.R`)  # Converter Yes, Little Noise
end

# Execute main function
get_figures_frequencyderivations_withDiff_frequencyreserves()
