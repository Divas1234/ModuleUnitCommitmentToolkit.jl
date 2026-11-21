#!/usr/bin/env julia
"""
Runnable example: Benders Decomposition UC solver with configurable terminal diagnostics.

Usage:
  julia --project=. tools/benders/example_run.jl [scenario_limit] [--fast] [OPTIONS]
  julia --project=. tools/benders/example_run.jl 2 --all-details
  julia --project=. tools/benders/example_run.jl --help
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    opts = parse_example_run_args(args; default_scenarios = 2)
    if opts.help
        print_example_run_usage("tools/benders/example_run.jl"; supports_fast = true)
        return nothing
    end

    return run_uc_example_workflow(
        BendersAlgorithm(fast_direct = opts.fast_direct),
        opts;
        algo_name = opts.fast_direct ? "benders_fast" : "benders",
        input = :excel,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (MODEL_MAX_ITERATIONS_NUM = 30, MODEL_CALCULATION_PRECISION = 0.01),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
