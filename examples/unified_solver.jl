"""Unified benchmark/Benders/CCG entry-point example.

Run from the repository root, for example:

    UC_ALGORITHM=ccg UC_INPUT=excel julia --project=. examples/unified_solver.jl
"""

using Pkg

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

algorithm = Symbol(get(ENV, "UC_ALGORITHM", "benchmark"))
input = Symbol(get(ENV, "UC_INPUT", "excel"))
scenario_limit = parse(Int64, get(ENV, "UC_SCENARIO_LIMIT", "2"))

# Put one-off calibration values here, or pass them from an application layer.
calibration = (
    MODEL_CONSIDER_DATA_CENTER = 0,
    MODEL_CONSIDER_FREQUENCY_CONTROL = 0,
)

result = solve_uc(
    algorithm = algorithm,
    input = input,
    scenario_limit = scenario_limit,
    calibration = calibration,
    # The example prints only the unified summary; use :verbose to inspect internal logs.
    verbosity = :silent,
)

print_uc_result(result)
