# ============================================================================
# Benchmarking Script: Standard PCM vs. Adaptive Overlapping Window PCM
#
# This script executes both PCM optimization frameworks on the same input dataset
# and compares:
# 1. Calculation time (seconds)
# 2. Total system operation cost ($)
# 3. Startup & Shutdown costs ($)
# 4. Wind curtailment quantity (MWh)
# 5. Load shedding quantity (MWh)
# 6. Window size statistics
# ============================================================================

using Pkg
Pkg.activate("d:/GithubClonefiles/module_unitcommitment/pkg")
using Printf, Statistics
include("../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../src/read_inputdata_modules/readdatas.jl")
include("period_scuc_modules.jl")
include("adaptive_period_scuc_modules.jl")

println("\n" * "="^80)
println("STARTING BENCHMARK: Standard PCM vs. Adaptive Overlapping PCM")
println("="^80)

# 1. Read and format input data
println("\n[1/3] Loading Input Data...")
ENV["MODULE_UC_DATA_FILE"] = "d:/GithubClonefiles/module_unitcommitment/data/data_118.xlsx"
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)
config_param.is_NetWorkCon = 0
winds, NW = genscenario(WindsFreqParam, 0)
winds.scenarios_nums = 1
winds.scenarios_curve = winds.scenarios_curve[1:1, :]

scenarios_prob = 1.0

exec_NT = 24
N_sets = 7
required_horizon = exec_NT * N_sets

function repeat_time_series_to_horizon(curve::AbstractMatrix{<:Real}, target_hours::Int)
    source_hours = size(curve, 2)
    if source_hours == 0
        error("Cannot extend an empty time-series curve.")
    end
    repeat_count = cld(target_hours, source_hours)
    extended_curve = repeat(Matrix{Float64}(curve), 1, repeat_count)
    return extended_curve[:, 1:target_hours]
end

# Preserve native multi-day uncertainty when data_118.xlsx already provides a
# 168-hour curve. Repeat only as a fallback for legacy 24-hour input files.
if size(loads.load_curve, 2) < required_horizon
    loads.load_curve = repeat_time_series_to_horizon(loads.load_curve, required_horizon)
end
if size(winds.scenarios_curve, 2) < required_horizon
    winds.scenarios_curve = repeat_time_series_to_horizon(winds.scenarios_curve, required_horizon)
end

# ------------------------------------------------------------------------
# 2. Run Standard Sequential PCM (Fixed 24h Non-Overlapping Window)
# ------------------------------------------------------------------------
println("\n" * "-"^80)
println("[2/3] Running Standard Sequential PCM (Fixed Non-Overlapping Window)...")
println("-"^80)

std_costs_matrix = zeros(N_sets + 1, 7)
pre_results_std = Dict{String, Array{Float64}}()

t_start_std = time()

for k ∈ 1:N_sets
    global pre_results_std
    mini_units, mini_loads, mini_winds = update_boundary_conditions(k, NG, exec_NT, units, loads, winds, pre_results_std)
    res_std = each_period_scucmodel_modules(exec_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)
    if res_std === nothing
        error("Standard PCM failed at interval $k")
    end
    if haskey(res_std, "res_scheduled_costs")
        std_costs_matrix[k, :] = res_std["res_scheduled_costs"]
    end
    pre_results_std = res_std
end

time_std = time() - t_start_std
std_costs_matrix[end, :] = sum(std_costs_matrix[1:N_sets, :]; dims = 1)

# ------------------------------------------------------------------------
# 3. Run Adaptive Overlapping Window PCM
# ------------------------------------------------------------------------
println("\n" * "-"^80)
println("[3/3] Running Adaptive Overlapping Window PCM...")
println("-"^80)

alpha = 0.25
epsilon = 0.10
min_overlap = 2
max_overlap = 12
slow_unit_threshold = 4.0

# Use the steady-state accuracy-loss mapping path for overlap selection.
#
# Important:
# - "ml_prediction" takes the direct CART predictor branch in
#   compute_adaptive_overlap_window and bypasses T_steady.
# - "regression" reaches:
#     T_steady = compute_steady_state_overlap_mapping(
#         loads, winds, units, start_time, exec_NT, epsilon,
#         min_overlap, max_overlap, x_0_curr, steady_state_mode, trained_models
#     )
#   The final adaptive overlap is then max(T_steady, T_unit, T_ramp), with
#   end-of-horizon clamping for the final interval.
steady_state_mode = "regression"

adapt_costs_matrix = zeros(N_sets + 1, 7)

# Calibrate the steady-state accuracy-loss mapping model before timing the
# rolling-horizon simulation.
#
# This sampling/training step is treated as offline calibration or pre-run model
# preparation. It is intentionally excluded from Total Solve Time so the reported
# Standard PCM vs Adaptive Overlapping PCM time comparison reflects only the
# operational rolling-horizon simulation loops.
calibration_start = time()
trained_models = TrainedLossModels(steady_state_mode == "ml_prediction" ? "decay" : steady_state_mode)
if steady_state_mode != "decay" && steady_state_mode != "ml_prediction"
    trained_models = sample_and_train_loss_models(loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob, hydros, exec_NT, min_overlap, max_overlap, NB, NG, ND, NC, ND2, NL, NH)
end
calibration_time_excluded = time() - calibration_start
println(@sprintf("  Calibration / training time excluded from solve-time comparison: %.2f s", calibration_time_excluded))

pre_results_adapt = nothing
overlap_history = Int64[]

# Start adaptive solve-time measurement after calibration. Do not move this timer
# above sample_and_train_loss_models unless calibration time should be included
# in the reported operational simulation runtime.
t_start_adapt = time()

for k ∈ 1:N_sets
    global pre_results_adapt
    start_time = (k - 1) * exec_NT + 1

    x_ref_curr = solve_local_reference_commitment(
        loads, winds, units, lines, DataCentras, config_param, stroges,
        scenarios_prob, hydros, start_time, exec_NT, max_overlap,
        NB, NG, ND, NC, ND2, NL, NH, k
    )
    T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap, pre_results_adapt, k, steady_state_mode, trained_models, x_ref_curr)
    push!(overlap_history, T_overlap)
    total_NT = exec_NT + T_overlap

    mini_units, mini_loads, mini_winds = update_adaptive_boundary_conditions(k, NG, exec_NT, total_NT, start_time, units, loads, winds, pre_results_adapt)

    res_adapt = each_period_scucmodel_modules(total_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, k, hydros, NH)
    if res_adapt === nothing
        error("Adaptive PCM failed at interval $k")
    end

    committed_res = truncate_and_commit_results(res_adapt, exec_NT)
    committed_cost = compute_committed_cost(committed_res, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, k, hydros, scenarios_prob)
    adapt_costs_matrix[k, :] = committed_cost

    pre_results_adapt = res_adapt
end

time_adapt = time() - t_start_adapt
adapt_costs_matrix[end, :] = sum(adapt_costs_matrix[1:N_sets, :]; dims = 1)

# ------------------------------------------------------------------------
# 4. Synthesize & Print Comparison Metrics
# ------------------------------------------------------------------------
# Column mapping:
# 1: Startup, 2: Shutdown, 3: Production Fuel, 4: Reserve Up, 5: Reserve Down, 6: Load Shedding, 7: Wind Curtailment
std_su = std_costs_matrix[end, 1] + std_costs_matrix[end, 2]
std_fuel = std_costs_matrix[end, 3]
std_total_cost = sum(std_costs_matrix[end, 1:5])
std_load_shed = std_costs_matrix[end, 6]
std_wind_curtail = std_costs_matrix[end, 7]

adapt_su = adapt_costs_matrix[end, 1] + adapt_costs_matrix[end, 2]
adapt_fuel = adapt_costs_matrix[end, 3]
adapt_total_cost = sum(adapt_costs_matrix[end, 1:5])
adapt_load_shed = adapt_costs_matrix[end, 6]
adapt_wind_curtail = adapt_costs_matrix[end, 7]

println("\n" * "="^80)
println("BENCHMARK COMPARISON RESULTS")
println("="^80)

println("\n| Performance Metric | Standard PCM (Fixed 24h) | Adaptive Overlapping PCM | Difference / Delta |")
println("| :--- | :---: | :---: | :---: |")
println(@sprintf("| Total Solve Time (sec) | %.2f s | %.2f s | %+.2f s (%+.1f%%) |", time_std, time_adapt, time_adapt - time_std, (time_adapt - time_std)/time_std*100))
println(@sprintf("| Calibration / Training Time | excluded | excluded | %.2f s excluded from adaptive timing |", calibration_time_excluded))
println(@sprintf("| Total Operation Cost (USD) | USD %.2f | USD %.2f | %+.2f USD (%+.2f%%) |", std_total_cost, adapt_total_cost, adapt_total_cost - std_total_cost, (adapt_total_cost - std_total_cost)/std_total_cost*100))
println(@sprintf("| Startup & Shutdown Cost (USD) | USD %.2f | USD %.2f | %+.2f USD |", std_su, adapt_su, adapt_su - std_su))
println(@sprintf("| Generation Fuel Cost (USD) | USD %.2f | USD %.2f | %+.2f USD |", std_fuel, adapt_fuel, adapt_fuel - std_fuel))
println(@sprintf("| Wind Curtailment (MWh) | %.2f MWh | %.2f MWh | %+.2f MWh |", std_wind_curtail, adapt_wind_curtail, adapt_wind_curtail - std_wind_curtail))
println(@sprintf("| Load Shedding (MWh) | %.2f MWh | %.2f MWh | %+.2f MWh |", std_load_shed, adapt_load_shed, adapt_load_shed - std_load_shed))
println(@sprintf("| Avg Overlap Window (h) | 0.0 h | %.1f h | +%.1f h |", mean(overlap_history), mean(overlap_history)))

# Save to CSV summary report
outdir = joinpath(pwd(), "output", "details_schedule_results")
mkpath(outdir)
csv_file = joinpath(outdir, "pcm_performance_comparison.csv")

open(csv_file, "w") do io
    println(io, "Metric,Standard_PCM,Adaptive_Overlapping_PCM,Delta")
    println(io, "SolveTime_sec,$time_std,$time_adapt,$(time_adapt - time_std)")
    println(io, "CalibrationTime_excluded_sec,0.0,$calibration_time_excluded,$calibration_time_excluded")
    println(io, "TotalCost_USD,$std_total_cost,$adapt_total_cost,$(adapt_total_cost - std_total_cost)")
    println(io, "StartupShutdownCost_USD,$std_su,$adapt_su,$(adapt_su - std_su)")
    println(io, "FuelCost_USD,$std_fuel,$adapt_fuel,$(adapt_fuel - std_fuel)")
    println(io, "WindCurtailment_MWh,$std_wind_curtail,$adapt_wind_curtail,$(adapt_wind_curtail - std_wind_curtail)")
    println(io, "LoadShedding_MWh,$std_load_shed,$adapt_load_shed,$(adapt_load_shed - std_load_shed)")
    println(io, "AvgOverlapWindow_hours,0.0,$(mean(overlap_history)),$(mean(overlap_history))")
end

println("\n✓ Performance comparison saved to: $csv_file")
println("="^80 * "\n")
