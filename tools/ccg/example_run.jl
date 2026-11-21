#!/usr/bin/env julia
"""
Minimal runnable example: Column-and-Constraint Generation (CCG / DRO-CCG) UC solver.

Usage:
  julia --project=. tools/ccg/example_run.jl [scenario_limit]

Demonstrates invoking the Wasserstein DRO Column-and-Constraint Generation
algorithm through the unified `ModuleUnitCommitmentToolkit` API (`CCGAlgorithm` / `solve_uc`).
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    scenario_limit = length(args) >= 1 ? parse(Int, args[1]) : 2
    println("=== Column-and-Constraint Generation (CCG) UC Example (scenarios = $scenario_limit) ===")

    result = solve_uc(
        CCGAlgorithm();
        input = :excel,
        scenario_limit = scenario_limit,
        verbosity = :summary,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (CCG_MAX_ITER = 20, DRO_EPSILON = 0.05),
        #   input = :powersystems, case_name = "case14",
    )

    println("Completed: algorithm=$(result.algorithm), output_dir=$(result.output_dir)")
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
