# ============================================================================
# Sequential Production Cost Minimization (PCM) Main Function
#
# This script implements a sequential unit commitment optimization approach
# that divides the planning horizon into multiple intervals and solves each
# interval sequentially, using the results from previous intervals to update
# boundary conditions for subsequent intervals.
#
# The approach is useful for:
# - Long-term planning horizons that are computationally challenging
# - Rolling horizon optimization
# - Multi-period optimization with state transitions
#
# Workflow:
# 1. Load input data and generate wind scenarios
# 2. Divide the planning horizon into multiple scheduling intervals
# 3. For each interval:
#    a. Update boundary conditions based on previous interval results
#    b. Solve the unit commitment optimization problem
#    c. Save interval-specific results
# 4. Aggregate and save total scheduling costs
#
# Usage: julia pcm_mainfunc.jl
# Output: Results saved to output/details_schedule_results/pcm_simulation_results/
# ============================================================================

# ============================================================================
# Step 1: Include required modules
# ============================================================================
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"))
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"))
include("period_scuc_modules.jl")

# ============================================================================
# Step 2: Read input data from Excel file
# ============================================================================
println("\n" * "="^80)
println("Step 1: Reading input data from Excel file...")
println("="^80)

UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()

# ============================================================================
# Step 3: Format and process input data
# ============================================================================
println("\n" * "="^80)
println("Step 2: Formatting input data for optimization model...")
println("="^80)

config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve)

# ============================================================================
# Step 4: Generate wind power scenarios
# ============================================================================
println("\n" * "="^80)
println("Step 3: Generating wind power scenarios...")
println("="^80)

winds, NW = genscenario(WindsFreqParam, 0)

# ============================================================================
# Step 5: Configure sequential scheduling parameters
# ============================================================================
println("\n" * "="^80)
println("Step 4: Configuring sequential scheduling parameters...")
println("="^80)

# Define scenario probability (assuming equal probability for all scenarios)
scenarios_prob = 1.0 / winds.scenarios_nums

# Sequential scheduling configuration
mini_NT = 24                    # Number of time periods per scheduling interval
patch_scheduling_ids_numssets = 7  # Number of sequential scheduling intervals

println("  Scheduling intervals: $patch_scheduling_ids_numssets")
println("  Time periods per interval: $mini_NT")
println("  Total planning horizon: $(patch_scheduling_ids_numssets * mini_NT) periods")

# ============================================================================
# Step 6: Initialize cost tracking matrix
# ============================================================================
# Cost matrix structure:
#   Column 1: Units startup cost
#   Column 2: Units shutdown cost
#   Column 3: Units operation cost
#   Column 4: Total cost
#   Columns 5-7: Additional cost components (if any)
total_scheduled_cost = zeros(patch_scheduling_ids_numssets + 1, 7)

# ============================================================================
# Step 7: Sequential optimization loop
# ============================================================================
println("\n" * "="^80)
println("Step 5: Running sequential unit commitment optimization...")
println("="^80)

# Initialize previous scheduling results (empty for first interval)
pre_scheduling_results = Dict{String, Array{Float64}}()

for interval_scheduling_id ∈ 1:patch_scheduling_ids_numssets
	global pre_scheduling_results
	println("\n" * "-"^80)
	println(
		"Processing scheduling interval $interval_scheduling_id of $patch_scheduling_ids_numssets...",
	)
	println("-"^80)

	# ------------------------------------------------------------------------
	# Step 7.1: Update boundary conditions for current interval
	# ------------------------------------------------------------------------
	println("  Updating boundary conditions based on previous interval results...")
	mini_units, mini_loads, mini_winds = update_boundary_conditions(
		interval_scheduling_id, NG, mini_NT, units, loads, winds, pre_scheduling_results
	)

	# ------------------------------------------------------------------------
	# Step 7.2: Solve unit commitment optimization for current interval
	# ------------------------------------------------------------------------
	println(
		"  Solving unit commitment optimization for interval $interval_scheduling_id...",
	)
	poster_scheduling_results = each_period_scucmodel_modules(
		mini_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, interval_scheduling_id, hydros, NH)

	# Check if optimization was successful
	if poster_scheduling_results === nothing
		error(
			"Optimization failed for interval $interval_scheduling_id. Stopping execution.",
		)
	end

	# ------------------------------------------------------------------------
	# Step 7.3: Extract and store scheduling costs
	# ------------------------------------------------------------------------
	if haskey(poster_scheduling_results, "res_scheduled_costs")
		total_scheduled_cost[interval_scheduling_id, :] = poster_scheduling_results["res_scheduled_costs"]
		println("  ✓ Interval $interval_scheduling_id optimization completed successfully")
	else
		println("  ⚠ Warning: No cost data found for interval $interval_scheduling_id")
	end

	# ------------------------------------------------------------------------
	# Step 7.4: Save detailed results for current interval
	# ------------------------------------------------------------------------
	println("  Saving detailed results for interval $interval_scheduling_id...")
	save_powerbalance_scheduled_results(
		mini_units, mini_winds, config_param, poster_scheduling_results, interval_scheduling_id)

	# ------------------------------------------------------------------------
	# Step 7.5: Update previous scheduling results for next interval
	# ------------------------------------------------------------------------
	pre_scheduling_results = poster_scheduling_results
	println("  ✓ Interval $interval_scheduling_id processing completed")
end

# ============================================================================
# Step 8: Calculate and save total scheduling costs
# ============================================================================
println("\n" * "="^80)
println("Step 6: Aggregating total scheduling costs...")
println("="^80)

# Calculate total costs across all intervals
total_scheduled_cost[end, :] = sum(total_scheduled_cost[1:(end - 1), :]; dims = 1)

# Save total scheduling results
outdir = creat_outputfilepath(-1, 1)
write_result(
	outdir,
	"total_scheduled_results.csv",
	round.(total_scheduled_cost; digits = 5)
)

println("  ✓ Total scheduling costs saved to: $outdir/total_scheduled_results.csv")

# ============================================================================
# Step 9: Summary and completion
# ============================================================================
println("\n" * "="^80)
println("✓ Sequential Production Cost Minimization completed successfully!")
println("="^80)
println("  Total intervals processed: $patch_scheduling_ids_numssets")
println("  Results saved to: output/details_schedule_results/pcm_simulation_results/")
println("="^80 * "\n")
