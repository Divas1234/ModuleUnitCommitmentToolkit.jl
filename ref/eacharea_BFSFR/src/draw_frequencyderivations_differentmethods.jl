"""
	run_r_script_draw_frequency_derivations()

Calls the R script 'res/draw_frequencyderivations_via_differentmodel_sep.r'
to generate frequency derivation plots.

The R script is expected to be in the 'res/' directory relative to the project root.
It reads CSV files from the 'res/' directory and saves PDF plots
also into the 'res/' directory.

Prerequisites:

  - Rscript executable must be in the system's PATH.
  - Required R packages (ggplot2, reshape2, tidyr, dplyr, stringr) must be installed.
"""
function run_r_script_draw_frequency_derivations()
	r_script_name = "draw_frequencyderivations_via_differentmodel_sep.r"

	script_dir = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\.scripts\\"
	# project_root_derived = dirname(script_dir) # This should be the parent directory of 'src/'

	# Full path to the R script (used for checking existence)
	r_script_full_path = joinpath(script_dir, r_script_name)

	original_dir = pwd()
	try
		# println("Changing working directory to: $res_dir_abs for R script execution.")
		# cd(res_dir_abs)

		# Now that we are in res_dir_abs, the script can be called by its name
		cmd = `Rscript $r_script_full_path input_file output_file`
		println("Executing command: $cmd in directory $(pwd())")

		process = run(cmd)
		# cmd = `Rscript $r_script_full_path`
		if process.exitcode == 0
			println("R script executed successfully.")
			# println("Output PDF files should be in the '$res_dir_abs' directory.")
			# The R script itself prints the names of saved files.
		else
			@error "R script execution failed with exit code $(process.exitcode)."
			println("Please check the R script output above for error messages from R.")
		end
	catch e
		@error "An error occurred while trying to run the R script: $e"
		Base.showerror(stderr, e)
		Base.show_backtrace(stderr, catch_backtrace())
		println() # Ensure a newline after backtrace
	finally
		println("Changing working directory back to: $original_dir")
		cd(original_dir)
		println("Current working directory: $(pwd())")
	end
end

# To use this function, you would typically call it from another Julia script
# or the REPL after including this file:
#
# include("src/call_r_script.jl")
# run_r_script_draw_frequency_derivations()
