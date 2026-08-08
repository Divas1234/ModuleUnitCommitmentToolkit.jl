using Pkg
Pkg.activate("d:/GithubClonefiles/module_unitcommitment/pkg")

using XLSX
using Statistics
using Printf
using CSV
using DataFrames

# Include legacy data loaders and SCUC modeling components
include("d:/GithubClonefiles/module_unitcommitment/src/renewableresource_modules/stochasticsimulation.jl")
include("d:/GithubClonefiles/module_unitcommitment/src/read_inputdata_modules/readdatas.jl")
include("period_scuc_modules.jl")
include("adaptive_period_scuc_modules.jl")

function run_offline_dataset_generation()
    println("="^80)
    println("OFFLINE DATASET GENERATION FOR ADAPTIVE OVERLAP WINDOWS")
    println("="^80)

    # 1. Read base case data
    println("Loading base case data...")
    ENV["MODULE_UC_DATA_FILE"] = "d:/GithubClonefiles/module_unitcommitment/data/data.xlsx"
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
    
    # Declare variables as global so the legacy solve_and_extract_results can access them
    global config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, scenarios_prob, winds
    
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )
    
    # Store base curves
    base_winds, NW = genscenario(WindsFreqParam, 0)
    global winds = base_winds
    base_loads = deepcopy(loads)
    global scenarios_prob = 1.0 / base_winds.scenarios_nums

    exec_NT = 24
    N_sets = 7
    T_max = 12
    min_overlap = 2

    # Scenarios for scaling data to create historical variety
    load_scales = [0.90, 1.00, 1.10]
    wind_scales = [0.80, 1.00, 1.20]

    # Initialize empty DataFrame for training data
    df_dataset = DataFrame(
        # Features
        x0_1 = Float64[], x0_2 = Float64[], x0_3 = Float64[],
        t0_1 = Float64[], t0_2 = Float64[], t0_3 = Float64[],
        t1_1 = Float64[], t1_2 = Float64[], t1_3 = Float64[],
        L_norm = Float64[],
        sigma_load = Float64[],
        R_wind_max = Float64[],
        # Target
        To_star = Int64[]
    )

    # Silence solvers during sweeps
    task_local_storage(:is_sampling_running, true)

    total_scenarios = length(load_scales) * length(wind_scales)
    scen_idx = 1

    for l_scale in load_scales
        for w_scale in wind_scales
            println("\n" * "-"^60)
            println(@sprintf("Processing Scenario %d/%d (Load Scale: %.2f, Wind Scale: %.2f)", scen_idx, total_scenarios, l_scale, w_scale))
            println("-"^60)
            scen_idx += 1

            # Update the global loads and winds so that solve_and_extract_results uses the scaled ones
            global loads = deepcopy(base_loads)
            loads.load_curve = base_loads.load_curve .* l_scale

            global winds = deepcopy(base_winds)
            winds.scenarios_curve = base_winds.scenarios_curve .* w_scale

            # Pre-calculate peak load
            peak_load = maximum(sum(loads.load_curve; dims = 1))
            if peak_load <= 0.0; peak_load = 1.0; end
            total_capacity = sum(units.p_max)

            # Step 1: Run baseline simulation with maximum overlap to get state trajectory
            println("Running baseline simulation...")
            pre_results_baseline = nothing
            baseline_states = Vector{Dict{String, Array{Float64}}}(undef, N_sets)
            baseline_units_states = Vector{unit}(undef, N_sets)

            # Loop through intervals to get starting states
            for k in 1:N_sets
                start_time = (k - 1) * exec_NT + 1
                
                # Truncate maximum overlap dynamically based on available time horizon
                max_possible_overlap = size(loads.load_curve, 2) - (start_time + exec_NT - 1)
                T_max_interval = min(T_max, max_possible_overlap)
                total_NT = exec_NT + T_max_interval

                # Update boundary conditions
                mini_units, step_loads, step_winds = update_adaptive_boundary_conditions(
                    k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results_baseline
                )
                baseline_units_states[k] = deepcopy(mini_units)

                # Solve baseline UC
                res = each_period_scucmodel_modules(
                    total_NT, NB, NG, ND, NC, ND2, mini_units, step_loads, step_winds, lines,
                    DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH
                )
                if res === nothing
                    println("  Warning: Baseline UC failed at interval $k, skipping scenario.")
                    break
                end
                baseline_states[k] = res
                pre_results_baseline = res
            end

            # Skip this scenario if any baseline interval failed
            if any(isassigned.(Ref(baseline_states), 1:N_sets) .== false)
                continue
            end

            # Step 2: For each interval, perform overlap window sweeps
            for k in 1:N_sets
                start_time = (k - 1) * exec_NT + 1
                curr_units = baseline_states[k]
                init_units = baseline_units_states[k]

                # Extract features for interval k
                x_0_curr = init_units.x_0
                t_0_curr = init_units.t_0
                t_1_curr = init_units.t_1

                # Truncate overlap range for current interval
                max_possible_overlap = size(loads.load_curve, 2) - (start_time + exec_NT - 1)
                T_max_interval = min(T_max, max_possible_overlap)

                # Lookahead window calculation
                end_horizon = min(size(loads.load_curve, 2), start_time + exec_NT + T_max_interval - 1)
                total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
                total_wind_cap = sum(winds.p_max)

                net_load_lookahead = zeros(length(total_load_lookahead))
                for t in eachindex(total_load_lookahead)
                    scen_curves = winds.scenarios_curve[:, min(size(loads.load_curve, 2), start_time + t - 1)]
                    avg_wind_factor = mean(scen_curves)
                    net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
                end

                avg_net_load = mean(net_load_lookahead)
                L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)
                sigma_load = std(total_load_lookahead)

                # Max wind ramp
                wind_ramps = [abs(winds.scenarios_curve[s, t+1] - winds.scenarios_curve[s, t]) for s in 1:winds.scenarios_nums, t in start_time:(end_horizon-1)]
                R_wind_max = isempty(wind_ramps) ? 0.0 : maximum(wind_ramps)

                # Compute baseline cost (T_max)
                res_max = baseline_states[k]
                committed_res_max = truncate_and_commit_results(res_max, exec_NT)
                committed_cost_max = compute_committed_cost(
                    committed_res_max, exec_NT, init_units, loads, winds, lines,
                    DataCentras, config_param, k, hydros, scenarios_prob
                )
                C_max = sum(committed_cost_max)

                # Sweep overlap windows To
                println(@sprintf("  Interval %d: Sweeping overlap window lengths up to %d...", k, T_max_interval))
                T_o_star = T_max_interval

                for To in 0:T_max_interval
                    total_NT_To = exec_NT + To

                    # Update boundary conditions for current To
                    step_units, step_loads, step_winds = update_adaptive_boundary_conditions(
                        k, NG, exec_NT, total_NT_To, start_time, units, loads, winds,
                        k == 1 ? nothing : baseline_states[k-1]
                    )

                    res_To = each_period_scucmodel_modules(
                        total_NT_To, NB, NG, ND, NC, ND2, step_units, step_loads, step_winds, lines,
                        DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH
                    )

                    if res_To !== nothing
                        committed_res_To = truncate_and_commit_results(res_To, exec_NT)
                        committed_cost_To = compute_committed_cost(
                            committed_res_To, exec_NT, step_units, loads, winds, lines,
                            DataCentras, config_param, k, hydros, scenarios_prob
                        )
                        C_To = sum(committed_cost_To)
                        loss = abs(C_To - C_max) / C_max

                        if loss <= 0.005 # 0.5% threshold
                            T_o_star = To
                            println(@sprintf("    To = %2d: Loss = %.6f (<= 0.5%%) [OPTIMAL]", To, loss))
                            break
                        else
                            println(@sprintf("    To = %2d: Loss = %.6f (> 0.5%%)", To, loss))
                        end
                    else
                        println(@sprintf("    To = %2d: Model INFEASIBLE", To))
                    end
                end

                # Record sample
                push!(df_dataset, (
                    x_0_curr[1], x_0_curr[2], x_0_curr[3],
                    t_0_curr[1], t_0_curr[2], t_0_curr[3],
                    t_1_curr[1], t_1_curr[2], t_1_curr[3],
                    L_norm, sigma_load, R_wind_max,
                    T_o_star
                ))
            end
        end
    end

    # Save to CSV
    outdir = "d:/GithubClonefiles/module_unitcommitment/output/details_schedule_results"
    mkpath(outdir)
    csv_path = joinpath(outdir, "offline_training_dataset.csv")
    CSV.write(csv_path, df_dataset)
    println("\n" * "="^80)
    println("Dataset generation complete!")
    println("Total samples generated: ", size(df_dataset, 1))
    println("Dataset saved to: ", csv_path)
    println("="^80)
end

# Run the dataset generation
run_offline_dataset_generation()
