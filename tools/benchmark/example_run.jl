#!/usr/bin/env julia
"""
Minimal runnable example: Extensive-Form Benchmark UC solver.

Usage:
  julia --project=. tools/benchmark/example_run.jl [scenario_limit]

Demonstrates invoking the monolithic extensive-form UC solver through the
unified `ModuleUnitCommitmentToolkit` API (`BenchmarkUCAlgorithm` / `solve_uc`).
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    scenario_limit = length(args) >= 1 ? parse(Int, args[1]) : 2
    println("=== Extensive-Form Benchmark UC Example (scenarios = $scenario_limit) ===")

    result = solve_uc(
        BenchmarkUCAlgorithm();
        input = :excel,
        scenario_limit = scenario_limit,
        verbosity = :summary,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (MODEL_IS_NETWORK_CON = 1, MODEL_CONSIDER_BESS = 0),
        #   input = :powersystems, case_name = "case14",
    )

    println("Completed: algorithm=$(result.algorithm), output_dir=$(result.output_dir)")
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
