# ====================================================================
# Main Function for SFR Curve Analysis and Visualization
# ====================================================================

# Set environment variables to ASCII mode
ENV["LANG"] = "C"
ENV["LC_ALL"] = "C"
ENV["JULIA_LOCALE"] = "C"

# Import required modules and utility functions
include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl") # Contains form_SFRcurveData

"""
	run_r_script(script_path::String)

Executes an R script at the given path, with error handling.
"""
function run_r_script(script_path::String)
    if isfile(script_path)
        try
            run(`Rscript $script_path`)
            @info "Successfully executed R script: $script_path"
        catch e
            @error "Failed to execute R script: $script_path" e
        end
    else
        @warn "R script not found: $script_path"
    end
end

"""
	main()

Main workflow for SFR curve analysis, data generation, processing, and visualization.
"""
function main()
    # --- Configuration ---
    @info "Setting up configuration..."
    project_root = pwd()
    out_path = joinpath(project_root, "out")
    res_path = joinpath(project_root, "res")
    residuals_path = joinpath(res_path, "residuals")
    mkpath(out_path)
    mkpath(residuals_path)

    # Simulation parameters
    fcr_selected_threshold = 1000
    whitenoise_parameter = 5e-4

    # Plotting theme
    theme(:default)

    # --- Part 1: Generate SFR Curve Data for All Test Cases ---
    @info "Part 1: Generating SFR curve data..."
    cases = [
        (name = "converter_not_little_noise", signal = 1, flag = 1),
        (name = "converter_not_big_noise", signal = 2, flag = 1),
        (name = "converter_yes_little_noise", signal = 1, flag = 2),
        (name = "converter_yes_big_noise", signal = 2, flag = 2),
    ]

    results = Dict()
    local xdata # Make xdata available outside the loop
    for (i, case) in enumerate(cases)
        @info "Running case: $(case.name)"
        xdata, y1, y2, y3, s_data = form_SFRcurveData(case.signal, case.flag, whitenoise_parameter, fcr_selected_threshold)
        results[case.name] = (y1 = y1, y2 = y2, y3 = y3, s_data = s_data)
    end

    # --- Part 2: Create DataFrames and Export SFR Curve Data to CSV ---
    @info "Part 2: Exporting SFR curve and sample data to CSV..."
    for case in cases
        res = results[case.name]
        df = DataFrame(; xdata = xdata[:, 1], sfr_data = res.y1[:, 1] * -1, bfsfr_data = res.y2[:, 1], real_data = res.y3[:, 1])
        CSV.write(joinpath(res_path, "$(case.name).csv"), df)
        CSV.write(joinpath(res_path, "sampledata_$(case.name).csv"), DataFrame(res.s_data, :auto))
    end

    # --- Part 3: Generate Visualization Figures and Distribution Analysis ---
    @info "Part 3: Running R scripts for visualization..."
    run_r_script_draw_frequency_derivations()
    run_r_script(joinpath(res_path, "Gaussian(baseline)", "draw_frequencynadir_violinplot_little_noise.r"))
    run_r_script(joinpath(res_path, "Gaussian(baseline)", "draw_frequencynadir_violinplot_big_noise.r"))

    # --- Part 4: Organize and Move Generated Files ---
    @info "Part 4: Organizing generated files..."
    target_words = ["noise", ".pdf", "sampledata"]
    files_in_res = readdir(res_path; join = true)
    files_to_move = filter(file -> isfile(file) && any(word -> occursin(word, basename(file)), target_words), files_in_res)

    for file in files_to_move
        dest_path = joinpath(residuals_path, basename(file))
        mv(file, dest_path; force = true)
        println("Moved: $(basename(file)) to residuals directory.")
    end

    # --- Part 5: Draw SFR Curves for Different Variability Cases ---
    @info "Part 5: Generating and saving SFR curve plots..."
    p1 = draw_sfr_curve3(
        xdata,
        results["converter_not_little_noise"].y2,
        results["converter_not_little_noise"].y3,
        results["converter_yes_little_noise"].y2,
        results["converter_yes_little_noise"].y3,
        results["converter_not_little_noise"].s_data,
        results["converter_yes_little_noise"].s_data,
    )
    p2 = draw_sfr_curve3(
        xdata,
        results["converter_not_big_noise"].y2,
        results["converter_not_big_noise"].y3,
        results["converter_yes_big_noise"].y2,
        results["converter_yes_big_noise"].y3,
        results["converter_not_big_noise"].s_data,
        results["converter_yes_big_noise"].s_data,
    )

    fig1 = plot(p1, p2; size = (600, 300), layout = (1, 2))
    savefig(fig1, joinpath(out_path, "new_SFRcurves.svg"))
    savefig(p1, joinpath(out_path, "littlenoise_SFRcurves.svg"))
    savefig(p2, joinpath(out_path, "bignoise_SFRcurves.svg"))

    # --- Part 6: Draw Distribution and Boxplot Analysis ---
    @info "Part 6: Generating distribution and boxplot analyses..."
    p4 = draw_case1_SFRdistribution(results["converter_not_little_noise"].s_data, results["converter_not_big_noise"].s_data)
    p5 = draw_case1_boxplot(results["converter_not_little_noise"].s_data, results["converter_not_big_noise"].s_data)
    fig2 = plot(p5, p4; size = (600, 300), layout = (1, 2))

    savefig(p4, joinpath(out_path, "pdf.svg"))
    savefig(p5, joinpath(out_path, "boxplot.svg"))
    savefig(fig2, joinpath(out_path, "SFRPDFinformations.svg"))

    # --- Part 7: Draw 3D Surface Distribution ---
    @info "Part 7: Generating 3D surface distribution plots..."
    p6, p7 = draw_sfr_surfacedistribution(results["converter_not_little_noise"].s_data, results["converter_not_big_noise"].s_data)
    savefig(p6, joinpath(out_path, "surface1.svg"))
    savefig(p7, joinpath(out_path, "surface2.svg"))

    theme(:bright)
    gr() # Re-initialize backend for theme change
    fig3 = plot(p6, p7; size = (600, 200), layout = (1, 2))
    savefig(fig3, joinpath(out_path, "surface1and2.pdf"))

    # --- Part 8 & 9: Monte Carlo Simulation and Export ---
    @info "Part 8 & 9: Running Monte Carlo simulation and exporting results..."
    N = 10
    ydata = zeros(1201, N)
    sampled_filters = zeros(1201, 100, N)
    whitenoise_parameter, fcr_selected_threshold = 1e-4, 1000

    for i in 1:N
        ydata[:, i], ~, sampled_filters[:, :, i] =
            simulate(generate_data, particle_filter, 100, 60, i, 1, 1, 1234, whitenoise_parameter, fcr_selected_threshold)
    end

    # Extract data at time-to-nadir
    δt = 0.05 # Assuming δt is 0.05s as it's not defined in this scope
    time_to_nadir = round(Int, 7.5 / δt)
    new_ydata = zeros(100, N)
    for i in 1:N
        new_ydata[:, i] = sampled_filters[time_to_nadir, :, i]
    end

    # Export results
    output_file = joinpath(out_path, "result2_forCloudRainVis.txt")
    open(output_file, "w") do io
        writedlm(io, [" "]) # Write header/placeholder
        return writedlm(io, new_ydata, '\t')
    end
    @info "Monte Carlo results exported to $output_file"

    @info "Workflow completed successfully."
end

# --- Script Execution ---
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

main()
