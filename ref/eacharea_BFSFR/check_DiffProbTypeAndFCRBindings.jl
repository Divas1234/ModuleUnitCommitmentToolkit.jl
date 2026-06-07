# ====================================================================
# Main Functions and Workflow
# ====================================================================

# Import required modules and utility functions
include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl")

const GAUSSIAN_DISTR = "Gaussian"
const WEIBULL_DISTR = "Weibull"
const NO_DISTR = "None" # Used for FCR binding tests

"""
	run_r_script(script_name::String)
	Constructs the full path to an R script in the 'res/.scripts' directory and executes it.

"""

function run_r_script(script_name::String)
	r_script_path = joinpath(pwd(), "res", ".scripts", script_name)
	if isfile(r_script_path)
		run(`Rscript $r_script_path`)
	else
		@warn "R script not found: $r_script_path"
	end
end

"""
	main()

Main workflow for running simulations, processing data, and generating figures.
"""
function main()
	# --- Configuration ---
	project_root = dirname(@__DIR__) # Assumes script is in a subdirectory of the project root
	res_dir = joinpath(project_root, "eacharea_BFSFR", "res")

	# Parameters for different simulation scenarios

	whitenoise_params = 1e-4:1e-4:5e-3
	fcr_threshold_params = 6.0:0.5:8.0
	fcr_test_whitenoise_param = 3e-4

	# --- Part 1: Generate Data for Different Uncertain Variability Environments ---
	@info "Part 1: Running simulations for various uncertainty levels..."
	for wn_param in whitenoise_params
		automatic_workflow_function(project_root, GAUSSIAN_DISTR, wn_param)
	end

	# --- Part 2: Obtain and Visualize Structured Frequency Derivative Data ---
	@info "Part 2: Processing and visualizing structured frequency derivative data..."
	for dist_type in [GAUSSIAN_DISTR, WEIBULL_DISTR]
		file_name = "converter_yes_little_noise.csv" # Source data for analysis
		sum_data = get_sumstructed_frequencyderivation_data(file_name, dist_type)

		# Define directory for results based on distribution
		feature_dir = joinpath(res_dir, "$dist_type(various_uncertain_variability_features)")
		@assert isdir(feature_dir) "Directory not found: $feature_dir"

		output_csv = joinpath(feature_dir, "$(dist_type)_frequencyderivations_data.csv")
		CSV.write(output_csv, sum_data)

		# Copy Weibull data for separate access if needed
		if dist_type == WEIBULL_DISTR
			cp(output_csv, joinpath(res_dir, "Weibull_frequencyderivations_data.csv"); force = true)
		end
	end

	# Call R scripts to generate visualization figures
	run_r_script("draw_Gaussian_frequencyderivations_underdifferent_uncertain_cases.R")
	run_r_script("draw_Weiibull_frequencyderivations_underdifferent_uncertain_cases.R")

	# --- Part 3: Run Simulations for Different FCR Binding Levels ---
	@info "Part 3: Running simulations for different FCR binding levels..."
	for fcr_threshold in fcr_threshold_params
		automatic_workflow_function(project_root, NO_DISTR, fcr_test_whitenoise_param, fcr_threshold)
	end

	# --- Part 4: Organize FCR Binding Result Folders ---
	@info "Part 4: Organizing FCR binding result folders..."
	fcr_bindings_dir = joinpath(res_dir, "fcr_bindings")
	mkpath(fcr_bindings_dir)

	# Regex to find fcr_binding folders with integer or float numbers
	fcr_folder_regex = r"^fcr_binding\(\d+(\.\d+)?\)$"
	all_res_dirs = filter(x -> isdir(joinpath(res_dir, x)), readdir(res_dir))
	fcr_source_folders = filter(x -> occursin(fcr_folder_regex, x), all_res_dirs)

	for folder_name in fcr_source_folders
		src = joinpath(res_dir, folder_name)
		dest = joinpath(fcr_bindings_dir, folder_name)
		mv(src, dest; force = true)
		println("Moved $src -> $dest")
	end

	# --- Part 5: Process FCR Data and Generate Figures ---
	@info "Part 5: Processing FCR data and generating derivative figures..."
	fcr_scenarios = [
		"converter_yes_little_noise",
		"converter_yes_big_noise",
		"converter_not_little_noise",
		"converter_not_big_noise",
	]

	for scenario in fcr_scenarios
		scenario_csv = scenario * ".csv"
		# Process data from the organized fcr_bindings directories
		sum_data = get_sumstructed_frequencyderivation_data(scenario_csv, NO_DISTR)

		# Write the processed data directly to the final destination in the 'res' folder
		res_dir = joinpath(project_root, "eacharea_BFSFR", "res", "fcr_bindings")
		output_csv = joinpath(res_dir, "fcr_bindings_frequencyderivations_$(scenario_csv)")
		CSV.write(output_csv, sum_data)
		@info "Generated FCR derivative data: $output_csv"
	end

	# Call R scripts to visualize the results
	run_r_script("draw_frequencyderivations_withfcr_bindings_converter_not_big_noise.R")
	run_r_script("draw_frequencyderivations_withfcr_bindings_converter_not_little_noise.R")
	run_r_script("draw_frequencyderivations_withfcr_bindings_converter_yes_big_noise.R")
	run_r_script("draw_frequencyderivations_withfcr_bindings_converter_yes_little_noise.R")

	@info "Workflow completed successfully."
end

# --- Script Execution ---
if abspath(PROGRAM_FILE) == @__FILE__
	main()
end

main()
