#!/usr/bin/env julia
"""
Runnable example: Column-and-Constraint Generation (CCG / DRO-CCG) UC solver
with configurable terminal diagnostics.

Usage:
  julia --project=. tools/ccg/example_run.jl [scenario_limit] [OPTIONS]
  julia --project=. tools/ccg/example_run.jl 2 --all-details
  julia --project=. tools/ccg/example_run.jl --help
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    opts = parse_example_run_args(args; default_scenarios = 2)
    if opts.help
        print_example_run_usage("tools/ccg/example_run.jl")
        return nothing
    end

    return run_uc_example_workflow(
        CCGAlgorithm(),
        opts;
        algo_name = "ccg",
        input = :excel,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (CCG_MAX_ITER = 20, DRO_EPSILON = 0.05),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
