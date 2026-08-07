# ============================================================================
# Adaptive Overlapping Rolling-Horizon Production Cost Minimization (PCM) Script
#
# Features:
# 1. Unit Commitment Dimension: Slow-start vs Fast-start unit boundary passing
# 2. Power Balance & Ramping Dimension: Net-load ramping event adaptive envelope
# 3. Steady State: Boundary sensitivity decay factor matching
# ============================================================================

include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"))
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"))
include("adaptive_period_scuc_modules.jl")

# ============================================================================
# Step 1: Read input data from Excel file
# ============================================================================
println("\n" * "="^80)
println("Step 1: Reading input data from Excel file...")
println("="^80)

UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()

# ============================================================================
# Step 2: Format and process input data
# ============================================================================
println("\n" * "="^80)
println("Step 2: Formatting input data for optimization model...")
println("="^80)

config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)

# ============================================================================
# Step 3: Generate wind power scenarios
# ============================================================================
println("\n" * "="^80)
println("Step 3: Generating wind power scenarios...")
println("="^80)

winds, NW = genscenario(WindsFreqParam, 0)
scenarios_prob = 1.0 / winds.scenarios_nums

# ============================================================================
# Step 4: Configure adaptive sequential scheduling parameters
# ============================================================================
println("\n" * "="^80)
println("Step 4: Configuring adaptive rolling-horizon parameters...")
println("="^80)

exec_NT = 24                         # Execution window (hours committed per interval)
patch_scheduling_ids_numssets = 7    # Total number of scheduling intervals

# Boundary sensitivity decay factor & threshold parameters
alpha = 0.25                         # Sensitivity decay factor (alpha in (0, 1))
epsilon = 0.05                       # Boundary influence decay threshold
min_overlap = 2                      # Minimum overlap window size (hours)
max_overlap = 12                     # Maximum overlap window size (hours)
slow_unit_threshold = 4.0            # Dwell time threshold (hours) for slow-start units

# Classify unit speeds
slow_units, fast_units, T_unit_req = classify_generator_speed(units; slow_threshold = slow_unit_threshold)
T_steady_req = calculate_boundary_sensitivity_decay(alpha, epsilon)

println("  Execution window per interval: $exec_NT hours")
println("  Total scheduling intervals: $patch_scheduling_ids_numssets")
println("  Slow-start units detected: $(length(slow_units)) / $NG (dwell req: $(T_unit_req)h)")
println("  Fast-start units detected: $(length(fast_units)) / $NG")
println("  Boundary sensitivity decay factor (alpha): $alpha (steady-state req: $(T_steady_req)h)")
println("  Adaptive overlap window range: [$min_overlap, $max_overlap] hours")

# ============================================================================
# Step 5: Initialize cost tracking matrix
# ============================================================================
total_scheduled_cost = zeros(patch_scheduling_ids_numssets + 1, 7)

# ============================================================================
# Step 6: Sequential optimization loop with adaptive overlapping windows
# ============================================================================
println("\n" * "="^80)
println("Step 5: Running adaptive rolling-horizon unit commitment optimization...")
println("="^80)

pre_scheduling_results = nothing

for interval_scheduling_id in 1:patch_scheduling_ids_numssets
    global pre_scheduling_results

    start_time = (interval_scheduling_id - 1) * exec_NT + 1
    println("\n" * "-"^80)
    println("Processing interval $interval_scheduling_id of $patch_scheduling_ids_numssets (Start hour: $start_time)...")
    println("-"^80)

    # ------------------------------------------------------------------------
    # Step 6.1: Calculate adaptive overlap window length
    # ------------------------------------------------------------------------
    T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(
        loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap
    )
    total_NT = exec_NT + T_overlap

    println("  [Adaptive Overlap Controller]")
    println("    - Steady-state decay horizon : $(T_steady)h")
    println("    - Slow unit dwell horizon    : $(T_unit)h")
    println("    - Ramp event detected        : $(is_ramp) (ramp horizon: $(T_ramp)h)")
    println("    => Final Overlap Window (T_overlap): $(T_overlap)h | Total Horizon (total_NT): $(total_NT)h")

    # ------------------------------------------------------------------------
    # Step 6.2: Update boundary conditions for current interval
    # ------------------------------------------------------------------------
    println("  Updating boundary conditions based on prior committed window...")
    mini_units, mini_loads, mini_winds = update_adaptive_boundary_conditions(
        interval_scheduling_id, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_scheduling_results
    )

    # ------------------------------------------------------------------------
    # Step 6.3: Solve SCUC optimization model for total horizon (total_NT)
    # ------------------------------------------------------------------------
    println("  Solving SCUC optimization model (horizon = $total_NT hours)...")
    full_scheduling_results = each_period_scucmodel_modules(
        total_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines,
        DataCentras, config_param, stroges, scenarios_prob, NL, interval_scheduling_id, hydros, NH
    )

    if full_scheduling_results === nothing
        error("Optimization failed for interval $interval_scheduling_id. Stopping execution.")
    end

    # ------------------------------------------------------------------------
    # Step 6.4: Truncate and commit execution period (1:exec_NT)
    # ------------------------------------------------------------------------
    committed_results = truncate_and_commit_results(full_scheduling_results, exec_NT)

    # Calculate scheduling costs strictly for the committed execution window (1:exec_NT)
    committed_cost = compute_committed_cost(
        committed_results, exec_NT, mini_units, mini_loads, mini_winds, lines,
        DataCentras, config_param, interval_scheduling_id, hydros, scenarios_prob
    )
    total_scheduled_cost[interval_scheduling_id, :] = committed_cost
    println("  ✓ Interval $interval_scheduling_id optimization completed successfully (committed 24h cost computed).")

    # ------------------------------------------------------------------------
    # Step 6.5: Save detailed results for current interval
    # ------------------------------------------------------------------------
    println("  Saving committed detailed results for interval $interval_scheduling_id...")
    committed_winds = deepcopy(mini_winds)
    committed_winds.scenarios_curve = mini_winds.scenarios_curve[:, 1:exec_NT]
    save_powerbalance_scheduled_results(
        mini_units, committed_winds, config_param, committed_results, interval_scheduling_id
    )

    # Update state for next interval using full solution (state extracted at exec_NT)
    pre_scheduling_results = full_scheduling_results
    println("  ✓ Interval $interval_scheduling_id processing completed.")
end

# ============================================================================
# Step 7: Calculate and save aggregated scheduling costs
# ============================================================================
println("\n" * "="^80)
println("Step 6: Aggregating total scheduling costs...")
println("="^80)

total_scheduled_cost[end, :] = sum(total_scheduled_cost[1:(end - 1), :], dims = 1)

outdir = creat_outputfilepath(-1, 1)
outdir_adaptive = replace(outdir, "pcm_simulation_results" => "adaptive_pcm_simulation_results")
mkpath(outdir_adaptive)

write_result(outdir_adaptive, "total_scheduled_results.csv", round.(total_scheduled_cost; digits = 5))
println("  ✓ Total scheduling costs saved to: $(outdir_adaptive)total_scheduled_results.csv")

# ============================================================================
# Step 8: Summary and completion
# ============================================================================
println("\n" * "="^80)
println("✓ Adaptive Rolling-Horizon Production Cost Minimization Completed Successfully!")
println("="^80)
println("  Total intervals processed : $patch_scheduling_ids_numssets")
println("  Execution window per set  : $exec_NT hours")
println("  Decay factor (alpha)      : $alpha")
println("  Results saved to          : output/details_schedule_results/adaptive_pcm_simulation_results/")
println("="^80 * "\n")
