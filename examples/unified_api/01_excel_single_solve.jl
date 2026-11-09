"""
    01_excel_single_solve.jl

Minimal but complete example of the unified algorithm entry point:

1. Derive the project root from the script location without relying on the caller's pwd().
2. Use the Excel data entry point.
3. Select the benchmark algorithm.
4. Configure model and algorithm parameters with calibration.
5. Set the output root explicitly with output_dir.
6. Read results through the common UCSolveResult fields.

Run:

    julia --project=. examples/unified_api/01_excel_single_solve.jl
"""

using Pkg

# examples/unified_api/ -> examples/ -> project root.
# This keeps the package environment and example paths stable from any working directory.
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

# Use one scenario so the example remains suitable as an initial smoke test.
# Increase it to 3, 10, or the configured scenario count for formal experiments.
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))

# The unified entry point temporarily applies these values to ENV and restores them after solve_uc.
# Disable BESS and frequency constraints for Excel cases without those extensions.
const CALIBRATION = (
    MODEL_CONSIDER_BESS = false,
    MODEL_CONSIDER_FREQUENCY_CONTROL = false,
    BENCHMARK_UC_USE_DRO = false,
)

# output_dir may be absolute or relative.
# Relative paths are resolved by the library from the project root, not the caller's pwd().
const OUTPUT_DIR = joinpath(PROJECT_ROOT, "output", "examples", "excel_benchmark")

println("[1/3] Creating a unified solve request...")
request = UCSolveRequest(
    algorithm = :benchmark,
    input = :excel,
    scenario_limit = SCENARIO_LIMIT,
    calibration = CALIBRATION,
    output_dir = OUTPUT_DIR,
    # :detailed prints boundary/configuration reports and detailed results after solving.
    verbosity = :detailed,
)

println("[2/3] Solving with the benchmark algorithm...")
# solve_uc(request) internally:
# - validates algorithm and input;
# - loads the benchmark, CCG, and Benders implementation modules;
# - calls the unified load_uc_data entry point;
# - applies calibration for the duration of this call;
# - returns a UCSolveResult.
result = solve_uc(request)

println("[3/3] Reading the common result fields...")
println("  status      = ", result.status)
println("  output_dir  = ", result.output_dir)

# Algorithm details differ; the unified layer allows optional fields to be read safely with hasproperty.
if hasproperty(result, :history)
    println("[Algorithm details]")
    println("  history length = ", length(result.history))
end
