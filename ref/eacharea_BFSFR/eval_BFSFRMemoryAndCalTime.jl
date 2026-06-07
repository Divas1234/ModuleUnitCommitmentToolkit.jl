# BF-SFR Performance Analysis and Benchmarking
# Evaluates Bootstrap Particle Filter based System Frequency Response model

include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl")

using Plots, BenchmarkTools, Statistics, DataFrames

# Configuration
const CONFIG = (
	whitenoise = 1e-3,
	fcr_threshold = 100,
	num_particles = 100,
	sim_time = 60,
	rand_seed = 1234,
	noise_type = 1,
	converter_flag = 1,
	sub_flag = 0,
	figpath = mkpath(joinpath(pwd(), "out", "benchmark")),
)

# Run baseline simulation
println("="^70)
println("Running baseline simulation...")
println("Particles=$(CONFIG.num_particles), Time=$(CONFIG.sim_time)s, Noise=$(CONFIG.noise_type)")
println("="^70)

δf_posterior, δf_actual, δf_sampleddata = simulate(
	generate_data, particle_filter,
	CONFIG.num_particles, CONFIG.sim_time, CONFIG.noise_type,
	CONFIG.converter_flag, CONFIG.sub_flag, CONFIG.rand_seed,
	CONFIG.whitenoise, CONFIG.fcr_threshold,
)

# Visualization
println("\nGenerating plots...")

error = δf_posterior - δf_actual
p1 = plot(δf_posterior; label = "BF-SFR", xlabel = "Time (s)", ylabel = "Frequency Deviation (Hz)",
	linewidth = 2, title = "Posterior vs Actual", legend = :topright,)
plot!(p1, δf_actual; label = "Actual", linestyle = :dash, linewidth = 2)

p2 = plot(abs.(error); label = "Absolute Error", xlabel = "Time (s)", ylabel = "Error (Hz)",
	linewidth = 2, title = "Estimation Error", color = :red,)

p_combined = plot(p1, p2; layout = (2, 1), size = (800, 600))

savefig(p1, joinpath(CONFIG.figpath, "comparison.svg"))
savefig(p2, joinpath(CONFIG.figpath, "error.svg"))
savefig(p_combined, joinpath(CONFIG.figpath, "combined.svg"))

println("✓ Plots saved to: $(CONFIG.figpath)")

# ====================================================================
# Part 4: Performance Benchmarking
# ====================================================================

println("\n" * "="^70)
println("Running performance benchmarks...")
println("="^70)

# Benchmark 1: Baseline simulation performance
println("\n[1/3] Benchmarking baseline simulation ($(CONFIG.num_particles) particles)...")
benchmark_baseline = @benchmark simulate(
	generate_data,
	particle_filter,
	$CONFIG.num_particles,
	$CONFIG.sim_time,
	$CONFIG.noise_type,
	$CONFIG.converter_flag,
	$CONFIG.sub_flag,
	$CONFIG.rand_seed,
	$CONFIG.whitenoise,
	$CONFIG.fcr_threshold,
)

println("\nBaseline Simulation Benchmark Results:")
println("  Median time: ", median(benchmark_baseline.times) / 1e6, " ms")
println("  Mean time:   ", mean(benchmark_baseline.times) / 1e6, " ms")
println("  Min time:    ", minimum(benchmark_baseline.times) / 1e6, " ms")
println("  Max time:    ", maximum(benchmark_baseline.times) / 1e6, " ms")

# Benchmark 2: Scaling with particle count
println("\n[2/3] Benchmarking particle count scaling...")
particle_counts = [50, 100, 200, 400];
scaling_times = Float64[]
figpath = CONFIG.figpath

for n_particles in particle_counts
	print("  Testing $(n_particles) particles... ")
	bench = @benchmark simulate(
		generate_data,
		particle_filter,
		$n_particles,
		$CONFIG.sim_time,
		$CONFIG.noise_type,
		$CONFIG.converter_flag,
		$CONFIG.sub_flag,
		$CONFIG.rand_seed,
		$CONFIG.whitenoise,
		$CONFIG.fcr_threshold,
	) samples=5 evals=1

	median_time = median(bench.times) / 1e6
	push!(scaling_times, median_time)
	println("$(round(median_time, digits=2)) ms")
end

# Plot scaling results
p_scaling = plot(
	particle_counts,
	scaling_times;
	xlabel = "Number of Particles",
	ylabel = "Execution Time (ms)",
	title = "BF-SFR Computational Scaling",
	marker = :circle,
	markersize = 8,
	linewidth = 2,
	legend = false,
	grid = true,
)
savefig(p_scaling, joinpath(figpath, "scaling_analysis.svg"))

# Benchmark 3: Memory allocation analysis
println("\n[3/3] Memory allocation analysis...")
println("\nMemory Allocation Statistics:")
println("  Allocations: ", benchmark_baseline.allocs)
println("  Memory used: ", benchmark_baseline.memory / 1e6, " MB")

# ====================================================================
# Part 5: Summary Statistics
# ====================================================================

println("\n" * "="^70)
println("Performance Analysis Summary")
println("="^70)

# Accuracy metrics
mse = mean((δf_posterior - δf_actual) .^ 2)
rmse = sqrt(mse)
mae = mean(abs.(δf_posterior - δf_actual))
max_error = maximum(abs.(δf_posterior - δf_actual))

println("\nAccuracy Metrics:")
println("  RMSE:       ", round(rmse; digits = 6), " Hz")
println("  MAE:        ", round(mae; digits = 6), " Hz")
println("  Max Error:  ", round(max_error; digits = 6), " Hz")

println("\nComputational Performance:")
println("  Median execution time: ", round(median(benchmark_baseline.times) / 1e6; digits = 2), " ms")
println("  Memory per simulation: ", round(benchmark_baseline.memory / 1e6; digits = 2), " MB")

println("\nScaling Performance:")
for (i, n) in enumerate(particle_counts)
	println("  $(n) particles: $(round(scaling_times[i], digits=2)) ms")
end

println("\n" * "="^70)
println("Benchmark completed successfully!")
println("Results saved to: $figpath")
println("="^70)
