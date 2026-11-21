#!/usr/bin/env julia
"""
Minimal runnable example: Benders Decomposition UC solver.

Usage:
  julia --project=. tools/benders/example_run.jl [scenario_limit] [--fast]

Demonstrates invoking Benders decomposition through the unified
`ModuleUnitCommitmentToolkit` API (`BendersAlgorithm` / `solve_uc`).
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    fast_direct = "--fast" in args
    positional = filter(a -> !startswith(a, "--"), args)
    scenario_limit = isempty(positional) ? 2 : parse(Int, positional[1])

    println("=== Benders Decomposition UC Example (scenarios = $scenario_limit, fast_direct = $fast_direct) ===")

    result = solve_uc(
        BendersAlgorithm(fast_direct = fast_direct);
        input = :excel,
        scenario_limit = scenario_limit,
        verbosity = :summary,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (MODEL_MAX_ITERATIONS_NUM = 30, MODEL_CALCULATION_PRECISION = 0.01),
        #   input = :powersystems, case_name = "case14",
    )

    println("Completed: algorithm=$(result.algorithm), output_dir=$(result.output_dir)")
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
