# Quick Wasserstein DRO CCG example.
#
# Run from the repository root:
#   julia examples/ccg/run_wasserstein_dro_ccg.jl

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
cd(PROJECT_ROOT)

ENV["CCG_SCENARIO_LIMIT"] = get(ENV, "CCG_SCENARIO_LIMIT", "6")
ENV["CCG_INITIAL_SCENARIOS"] = get(ENV, "CCG_INITIAL_SCENARIOS", "2")
ENV["CCG_SCENARIOS_PER_ITERATION"] = get(ENV, "CCG_SCENARIOS_PER_ITERATION", "1")
ENV["CCG_MAX_ITERATIONS"] = get(ENV, "CCG_MAX_ITERATIONS", "3")
ENV["CCG_DRO_ENABLED"] = get(ENV, "CCG_DRO_ENABLED", "1")
ENV["CCG_DRO_RADIUS"] = get(ENV, "CCG_DRO_RADIUS", "0.05")
ENV["CCG_PARALLEL_RECOURSE"] = get(ENV, "CCG_PARALLEL_RECOURSE", "0")

println("Running Wasserstein DRO CCG example")
println("  scenarios:          ", ENV["CCG_SCENARIO_LIMIT"])
println("  initial scenarios:  ", ENV["CCG_INITIAL_SCENARIOS"])
println("  max iterations:     ", ENV["CCG_MAX_ITERATIONS"])
println("  DRO radius:         ", ENV["CCG_DRO_RADIUS"])

include(joinpath(PROJECT_ROOT, "tools", "ccg", "driver.jl"))
