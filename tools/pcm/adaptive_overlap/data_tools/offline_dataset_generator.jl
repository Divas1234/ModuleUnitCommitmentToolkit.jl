include("../paths.jl")

using XLSX
using Statistics
using Printf
using CSV
using DataFrames

# Include legacy data loaders and SCUC modeling components
include("../../../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../../../src/read_inputdata_modules/readdatas.jl")
include("../../standard/period_scuc.jl")
include("../core/pcm_overlap_core.jl")

function run_offline_dataset_generation()
    println("="^80)
    println("OFFLINE DATASET GENERATION FOR IEEE 118-BUS SYSTEM")
    println("="^80)

    # 1. Read base case data from data_118.xlsx
    println("Loading base case data from data_118.xlsx...")
    ENV["MODULE_UC_DATA_FILE"] = joinpath(ADAPTIVE_PCM_PROJECT_ROOT, "data", "data_118.xlsx")
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData,
    HydroCurve = readxlssheet()

    # Declare variables as global so the legacy solve_and_extract_results can access them
    global config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, scenarios_prob, winds

    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)
    config_param.is_NetWorkCon = 0

    # Store base curves
    base_winds, NW = genscenario(WindsFreqParam, 0)
    base_winds.scenarios_nums = 1
    base_winds.scenarios_curve = base_winds.scenarios_curve[1:1, :]

    required_horizon = 24 * 7
    repeat_to_horizon(curve) = repeat(Matrix{Float64}(curve), 1, cld(required_horizon, size(curve, 2)))[:, 1:required_horizon]

    # Preserve native multi-day uncertainty when the workbook already contains a
    # 168-hour curve. Repeat only for legacy 24-hour profiles.
    if size(loads.load_curve, 2) < required_horizon
        loads.load_curve = repeat_to_horizon(loads.load_curve)
    end
    if size(base_winds.scenarios_curve, 2) < required_horizon
        base_winds.scenarios_curve = repeat_to_horizon(base_winds.scenarios_curve)
    end

    global winds = base_winds
    base_loads = deepcopy(loads)
    global scenarios_prob = 1.0

    exec_NT = 24
    N_sets = 7
    T_max = 6
    min_overlap = 2

    # Scenarios for scaling data to create historical variety
    load_scales = [0.97, 1.03]
    wind_scales = [0.95, 1.05]

    # Initialize empty DataFrame with system-independent and boundary-state
    # features. X_delta_norm and X_switch_ratio quantify how much the inherited
    # rolling-boundary commitment differs from the base initial commitment.
    df_dataset = DataFrame(; U_norm = Float64[], T_dwell_rem = Float64[], L_norm = Float64[], sigma_load = Float64[],
        R_wind_max = Float64[], X_delta_norm = Float64[], X_switch_ratio = Float64[], To_star = Int64[])

    # Silence solvers during sweeps
    task_local_storage(:is_sampling_running, true)

    total_scenarios = length(load_scales) * length(wind_scales)
    scen_idx = 1

    for l_scale ∈ load_scales
        for w_scale ∈ wind_scales
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
            if peak_load <= 0.0
                peak_load = 1.0
            end
            total_capacity = sum(units.p_max)

            # Step 1: Run baseline simulation with maximum overlap to get state trajectory
            println("Running baseline simulation...")
            pre_results_baseline = nothing
            baseline_states = Vector{Dict{String, Array{Float64}}}(undef, N_sets)
            baseline_units_states = Vector{unit}(undef, N_sets)

            # Loop through intervals to get starting states
            for k ∈ 1:N_sets
                start_time = (k - 1) * exec_NT + 1

                # Truncate maximum overlap dynamically based on available time horizon
                max_possible_overlap = size(loads.load_curve, 2) - (start_time + exec_NT - 1)
                T_max_interval = min(T_max, max_possible_overlap)
                total_NT = exec_NT + T_max_interval

                # Update boundary conditions
                mini_units, step_loads, step_winds = update_adaptive_boundary_conditions(
                    k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results_baseline)
                baseline_units_states[k] = deepcopy(mini_units)

                # Solve baseline UC
                res = each_period_scucmodel_modules(total_NT, NB, NG, ND, NC, ND2, mini_units, step_loads, step_winds, lines,
                    DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)
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
            for k ∈ 1:N_sets
                start_time = (k - 1) * exec_NT + 1
                curr_units = baseline_states[k]
                init_units = baseline_units_states[k]

                # Extract system-independent features for interval k
                x_0_curr = init_units.x_0
                t_0_curr = init_units.t_0
                t_1_curr = init_units.t_1

                # U_norm: online capacity ratio
                U_norm = sum(x_0_curr .* units.p_max) / total_capacity

                # T_dwell_rem: remaining boundary restriction at this interval.
                # Online units contribute their remaining minimum online time;
                # offline units contribute their remaining minimum offline time.
                online_remaining = [x_0_curr[i] > 0.5 ? max(0.0, t_0_curr[i]) : 0.0 for i ∈ 1:NG]
                offline_remaining = [x_0_curr[i] <= 0.5 ? max(0.0, t_1_curr[i]) : 0.0 for i ∈ 1:NG]
                T_dwell_rem = max(0.0, maximum(online_remaining), maximum(offline_remaining))

                # Truncate overlap range for current interval
                max_possible_overlap = size(loads.load_curve, 2) - (start_time + exec_NT - 1)
                T_max_interval = min(T_max, max_possible_overlap)

                # Local reference: solve the same interval while ignoring the
                # inherited boundary state from the previous rolling window.
                # The first-period commitment is used as the local economic
                # benchmark for boundary-deviation features.
                x_ref_curr = nothing
                try
                    ref_units, ref_loads, ref_winds = update_adaptive_boundary_conditions(
                        1, NG, exec_NT, exec_NT + T_max_interval, start_time, units, loads, winds, nothing)
                    ref_res = each_period_scucmodel_modules(exec_NT + T_max_interval, NB, NG, ND, NC, ND2, ref_units, ref_loads, ref_winds,
                        lines, DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)
                    if ref_res !== nothing && haskey(ref_res, "x₀")
                        x_ref_curr = Float64.(ref_res["x₀"][:, 1] .> 0.5)
                    end
                catch e
                    println("  Warning: Local no-boundary reference solve failed at interval $k. Falling back to initial state.")
                end

                X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_0_curr, x_ref_curr)

                # Lookahead window calculation
                end_horizon = min(size(loads.load_curve, 2), start_time + exec_NT + T_max_interval - 1)
                total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
                total_wind_cap = sum(winds.p_max)

                net_load_lookahead = zeros(length(total_load_lookahead))
                for t ∈ eachindex(total_load_lookahead)
                    scen_curves = winds.scenarios_curve[:, min(size(loads.load_curve, 2), start_time + t - 1)]
                    avg_wind_factor = mean(scen_curves)
                    net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
                end

                avg_net_load = mean(net_load_lookahead)
                L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)
                sigma_load = std(total_load_lookahead)

                # Max wind ramp
                wind_ramps = [abs(winds.scenarios_curve[s, t + 1] - winds.scenarios_curve[s, t])
                              for s ∈ 1:winds.scenarios_nums, t ∈ start_time:(end_horizon - 1)]
                R_wind_max = isempty(wind_ramps) ? 0.0 : maximum(wind_ramps)

                # Compute baseline cost (T_max)
                res_max = baseline_states[k]
                committed_res_max = truncate_and_commit_results(res_max, exec_NT)
                committed_cost_max = compute_committed_cost(
                    committed_res_max, exec_NT, init_units, loads, winds, lines, DataCentras, config_param, k, hydros, scenarios_prob)
                C_max = sum(committed_cost_max)

                # Sweep overlap windows To
                println(@sprintf("  Interval %d: Sweeping overlap window lengths up to %d...", k, T_max_interval))
                T_o_star = T_max_interval

                for To ∈ 0:T_max_interval
                    total_NT_To = exec_NT + To

                    # Update boundary conditions for current To
                    step_units, step_loads, step_winds = update_adaptive_boundary_conditions(
                        k, NG, exec_NT, total_NT_To, start_time, units, loads, winds, k == 1 ? nothing : baseline_states[k - 1])

                    res_To = each_period_scucmodel_modules(total_NT_To, NB, NG, ND, NC, ND2, step_units, step_loads, step_winds, lines,
                        DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)

                    if res_To !== nothing
                        committed_res_To = truncate_and_commit_results(res_To, exec_NT)
                        committed_cost_To = compute_committed_cost(
                            committed_res_To, exec_NT, step_units, loads, winds, lines, DataCentras, config_param, k, hydros, scenarios_prob)
                        C_To = sum(committed_cost_To)
                        cost_loss = abs(C_To - C_max) / C_max
                        state_loss, switch_loss = commitment_boundary_deviation(units, committed_res_To["x₀"][:, exec_NT], committed_res_max["x₀"][:, exec_NT])
                        loss = cost_loss + 0.50 * state_loss + 0.25 * switch_loss

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
                push!(df_dataset, (U_norm, T_dwell_rem, L_norm, sigma_load, R_wind_max, X_delta_norm, X_switch_ratio, T_o_star))
            end
        end
    end

    # Save to CSV
    outdir = joinpath(ADAPTIVE_PCM_PROJECT_ROOT, "output", "details_schedule_results")
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
