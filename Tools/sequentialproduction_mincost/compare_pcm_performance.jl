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
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)
winds, NW = genscenario(WindsFreqParam, 0)
scenarios_prob = 1.0 / winds.scenarios_nums

exec_NT = 24
N_sets = 7

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
steady_state_mode = "ml_prediction"

adapt_costs_matrix = zeros(N_sets + 1, 7)

# Calibrate accuracy loss mapping model on-the-fly
trained_models = TrainedLossModels(steady_state_mode == "ml_prediction" ? "decay" : steady_state_mode)
if steady_state_mode != "decay" && steady_state_mode != "ml_prediction"
    trained_models = sample_and_train_loss_models(loads, winds, units, lines, DataCentras, config_param, stroges, scenarios_prob, hydros, exec_NT, min_overlap, max_overlap, NB, NG, ND, NC, ND2, NL, NH)
end

pre_results_adapt = nothing
overlap_history = Int64[]

t_start_adapt = time()

for k ∈ 1:N_sets
    global pre_results_adapt
    start_time = (k - 1) * exec_NT + 1

    T_overlap, is_ramp, T_steady, T_unit, T_ramp = compute_adaptive_overlap_window(loads, winds, units, start_time, exec_NT, alpha, epsilon, min_overlap, max_overlap, pre_results_adapt, k, steady_state_mode, trained_models)
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
    println(io, "TotalCost_USD,$std_total_cost,$adapt_total_cost,$(adapt_total_cost - std_total_cost)")
    println(io, "StartupShutdownCost_USD,$std_su,$adapt_su,$(adapt_su - std_su)")
    println(io, "FuelCost_USD,$std_fuel,$adapt_fuel,$(adapt_fuel - std_fuel)")
    println(io, "WindCurtailment_MWh,$std_wind_curtail,$adapt_wind_curtail,$(adapt_wind_curtail - std_wind_curtail)")
    println(io, "LoadShedding_MWh,$std_load_shed,$adapt_load_shed,$(adapt_load_shed - std_load_shed)")
    println(io, "AvgOverlapWindow_hours,0.0,$(mean(overlap_history)),$(mean(overlap_history))")
end

println("\n✓ Performance comparison saved to: $csv_file")
println("="^80 * "\n")
