include("../paths.jl")

using XLSX
using Statistics
using Printf
using CSV
using DataFrames

# Include legacy data loaders and SCUC modeling components
include("../../../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../../../src/read_inputdata_modules/readdatas.jl")
include("../../standard_pcm/period_scuc.jl")
include("../core/pcm_overlap_core.jl")

function run_criteria_evaluation()
    println("="^80)
    println("RUNNING MULTI-CRITERIA EVALUATION AND SPEEDUP COMPARISON")
    println("="^80)

    ENV["MODULE_UC_DATA_FILE"] = joinpath(ADAPTIVE_PCM_PROJECT_ROOT, "data", "data_118.xlsx")
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData,
    HydroCurve = readxlssheet()

    # Declare variables as global for legacy compatibility
    global config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, scenarios_prob, winds

    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)
    config_param.is_NetWorkCon = 0
    winds, NW = genscenario(WindsFreqParam, 0)
    winds.scenarios_nums = 1
    winds.scenarios_curve = winds.scenarios_curve[1:1, :]

    scenarios_prob = 1.0
    exec_NT = 24
    N_sets = 7
    alpha = 0.25
    epsilon = 0.10
    min_overlap = 2
    max_overlap = 12

    required_horizon = exec_NT * N_sets
    repeat_to_horizon(curve) = repeat(Matrix{Float64}(curve), 1, cld(required_horizon, size(curve, 2)))[:, 1:required_horizon]

    # Preserve native multi-day uncertainty when the workbook already contains a
    # 168-hour curve. Repeat only for legacy 24-hour profiles.
    if size(loads.load_curve, 2) < required_horizon
        loads.load_curve = repeat_to_horizon(loads.load_curve)
    end
    if size(winds.scenarios_curve, 2) < required_horizon
        winds.scenarios_curve = repeat_to_horizon(winds.scenarios_curve)
    end

    # Silence solvers during evaluation
    task_local_storage(:is_sampling_running, true)

    # Define modes to compare
    modes = [("Fixed Overlap (0h)", "fixed_0"), ("Fixed Overlap (4h)", "fixed_4"), ("Fixed Overlap (12h)", "fixed_12"),
        ("Adaptive (Decay)", "decay"), ("Adaptive (ML CART)", "ml_prediction")]

    # Results DataFrame
    df_results = DataFrame(; Mode = String[], SolveTime_sec = Float64[], Speedup = Float64[], TotalCost_USD = Float64[],
        CostGap_pct = Float64[], StartupCost_USD = Float64[], WindCurtailment_MWh = Float64[], AvgOverlap_h = Float64[])

    # Dictionary to keep track of total costs for gap computation
    cost_dict = Dict{String, Float64}()

    for (name, mode_str) ∈ modes
        println("\n" * "-"^60)
        println("Running Simulation Mode: $name")
        println("-"^60)

        overlap_history = Int64[]
        pre_results = nothing
        total_cost = 0.0
        total_startup_cost = 0.0
        total_wind_curtailment = 0.0

        t_start = time()

        # Run sequential rolling UC
        for k ∈ 1:N_sets
            start_time = (k - 1) * exec_NT + 1

            x_ref_curr = solve_local_reference_commitment(loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob,
                hydros, start_time, exec_NT, max_overlap, NB, NG, ND, NC, ND2, NL, NH, k)
            T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
                loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap, pre_results, k, mode_str, nothing, x_ref_curr)
            push!(overlap_history, T_overlap)
            total_NT = exec_NT + T_overlap

            # Update boundary conditions
            mini_units, step_loads, step_winds = update_adaptive_boundary_conditions(
                k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results)

            # Solve SCUC using GLPK
            res = each_period_scucmodel_modules(total_NT, NB, NG, ND, NC, ND2, mini_units, step_loads, step_winds, lines,
                DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)

            if res === nothing
                println("  Warning: Model failed to solve at interval $k. Skipping mode.")
                total_cost = NaN
                break
            end

            # Extract committed cost and performance metrics
            committed_res = truncate_and_commit_results(res, exec_NT)
            committed_costs = compute_committed_cost(
                committed_res, exec_NT, mini_units, loads, winds, lines, DataCentras, config_param, k, hydros, scenarios_prob)

            total_cost += sum(committed_costs)
            total_startup_cost += sum(committed_res["su_cost"]) + sum(committed_res["sd_cost"])

            # Wind curtailment
            pᵩ = committed_res["pᵩ"] # curtailment variable (NW x NT x NS)
            total_wind_curtailment += sum(pᵩ) * scenarios_prob

            pre_results = res
        end

        solve_duration = time() - t_start

        if !isnan(total_cost)
            avg_overlap = mean(overlap_history)
            cost_dict[name] = total_cost

            # Record metrics
            push!(df_results,
                (name, round(solve_duration; digits = 2), 0.0, # Will fill speedup later
                    round(total_cost; digits = 2), 0.0, # Will fill gap later
                    round(total_startup_cost; digits = 2), round(total_wind_curtailment; digits = 2), round(avg_overlap; digits = 1)))
            println(@sprintf("  => Completed in %.2fs | Cost: %.2f USD | Avg Overlap: %.1fh", solve_duration, total_cost, avg_overlap))
        end
    end

    # Baseline mode is "Fixed Overlap (12h)" (highest lookahead accuracy)
    baseline_mode = "Fixed Overlap (12h)"
    baseline_cost = get(cost_dict, baseline_mode, 0.0)
    baseline_time = df_results[df_results.Mode .== baseline_mode, :SolveTime_sec][1]

    # Slowest mode is "Fixed Overlap (12h)" or "Fixed Overlap (0h)"
    # We compute speedup relative to "Fixed Overlap (12h)"
    for r ∈ eachrow(df_results)
        r.Speedup = round(baseline_time / r.SolveTime_sec; digits = 2)
        if baseline_cost > 0.0
            r.CostGap_pct = round(((r.TotalCost_USD - baseline_cost) / baseline_cost) * 100.0; digits = 4)
        end
    end

    # Save comparative statistics
    outdir = joinpath(ADAPTIVE_PCM_PROJECT_ROOT, "output", "details_schedule_results")
    mkpath(outdir)
    csv_path = joinpath(outdir, "criteria_comparison_results.csv")
    CSV.write(csv_path, df_results)

    # 2. Output and Save Training Dataset Summary Statistics
    dataset_path = joinpath(outdir, "offline_training_dataset.csv")
    summary_path = joinpath(outdir, "training_dataset_summary.txt")

    println("\nAnalyzing training dataset statistics...")
    if isfile(dataset_path)
        df_data = CSV.read(dataset_path, DataFrame)

        # Open summary text file
        open(summary_path, "w") do f
            write(f, "="^80 * "\n")
            write(f, "DECISION TREE REGRESSOR TRAINING DATASET STATISTICS SUMMARY\n")
            write(f, "="^80 * "\n\n")

            write(f, @sprintf("Total Training Samples: %d\n\n", size(df_data, 1)))

            # Feature statistics
            write(f, "Feature Variables Distribution:\n")
            write(f, "-"^80 * "\n")
            write(f, @sprintf("%-12s | %-10s | %-10s | %-10s | %-10s\n", "Feature", "Mean", "Std Dev", "Min", "Max"))
            write(f, "-"^80 * "\n")

            for col ∈ names(df_data)[1:(end - 1)]
                vals = df_data[:, col]
                write(f, @sprintf("%-12s | %-10.4f | %-10.4f | %-10.4f | %-10.4f\n", col, mean(vals), std(vals), minimum(vals), maximum(vals)))
            end
            write(f, "-"^80 * "\n\n")

            # Target Label Distribution
            write(f, "Target Label (Optimal Overlap T_o*) Distribution:\n")
            write(f, "-"^80 * "\n")
            labels = df_data.To_star
            unique_labels = sort(unique(labels))

            for lbl ∈ unique_labels
                count = sum(labels .== lbl)
                pct = (count / length(labels)) * 100.0
                write(f, @sprintf("  Overlap Window T_o = %2d hours: %3d samples (%5.2f%%)\n", lbl, count, pct))
            end
            write(f, "-"^80 * "\n\n")

            # Summary analysis
            write(f, "Correlation Analysis (with Target Label T_o*):\n")
            write(f, "-"^80 * "\n")
            for col ∈ names(df_data)[1:(end - 1)]
                x = df_data[:, col]
                y = df_data.To_star
                r_val = std(x) > 0 ? (mean(x .* y) - mean(x)*mean(y)) / (std(x)*std(y)) : 0.0
                write(f, @sprintf("  %-12s vs T_o*: Correlation Coefficient = %+.4f\n", col, r_val))
            end
            write(f, "="^80 * "\n")
        end
        println("Dataset summary saved to: ", summary_path)
    else
        println("Warning: Training dataset CSV not found, skipping dataset summary statistics.")
    end

    # Print results to console
    println("\n" * "="^80)
    println("CRITERIA PERFORMANCE COMPARISON REPORT")
    println("="^80)
    show(df_results; allrows = true)
    println("\n" * "="^80)
end

# Run evaluation
run_criteria_evaluation()
