"""
    03_three_algorithm_comparison.jl

Use the same Excel data entry point and select, in sequence:

* benchmark: the extensive-form reference model;
* benders: Benders decomposition;
* ccg: Column-and-Constraint Generation.

The algorithm parameter selects the internal module without directly including algorithm scripts.
Each algorithm defaults to one scenario and limited iterations for smoke/demo runs.

Run:

    julia --project=. examples/unified_api/03_three_algorithm_comparison.jl
"""
##
using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const OUTPUT_ROOT = joinpath(PROJECT_ROOT, "output", "examples", "three_algorithms")

# Each algorithm receives only its own calibration values.
# Shared model parameters can be placed in every NamedTuple to keep formulations aligned.
const CALIBRATIONS = Dict(
    :benchmark => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENCHMARK_UC_USE_DRO = false,
    ),
    :benders => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENDERS_MAX_ITERATIONS = 1,
        BENDERS_PARALLEL_SUBPROBLEMS = false,
    ),
    :ccg => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 1,
        CCG_PARALLEL_RECOURSE = false,
    ),
)

function print_summary(algorithm, result)
    println("\n--- $(algorithm) ---")
    print_uc_result(result)
end

results = Dict{Symbol,Any}()

for algorithm in (:benchmark, :benders, :ccg)
    println("Running $(algorithm) through the common solve_uc entry...")

    # Use a separate output directory for each request to avoid overwriting schedules.
    # Suppress internal logs here and print a unified result; use :verbose for debugging.
    request = UCSolveRequest(
        algorithm = algorithm,
        input = :excel,
        scenario_limit = SCENARIO_LIMIT,
        calibration = CALIBRATIONS[algorithm],
        output_dir = joinpath(OUTPUT_ROOT, String(algorithm)),
        verbosity = :silent,
    )
    result = solve_uc(request)
    results[algorithm] = result
    print_summary(algorithm, result)
end

println("\nComparison table:")
println(rpad("algorithm", 14), rpad("status", 22), "upper_bound")
for algorithm in (:benchmark, :benders, :ccg)
    result = results[algorithm]
    println(rpad(String(result.algorithm), 14), rpad(String(result.status), 22), result.upper_bound)
end

# Note: upper_bound values are comparable only when model flags, data, and convergence
# conditions are aligned. This example prints the results without asserting equality.
