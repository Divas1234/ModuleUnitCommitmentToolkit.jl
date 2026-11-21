#!/usr/bin/env julia
"""
Runnable example: Extensive-Form Benchmark UC solver with configurable terminal diagnostics.

Usage:
  julia --project=. tools/benchmark/example_run.jl [scenario_limit] [OPTIONS]
  julia --project=. tools/benchmark/example_run.jl 2 --all-details
  julia --project=. tools/benchmark/example_run.jl --help
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(args = ARGS)
    opts = parse_example_run_args(args; default_scenarios = 2)
    if opts.help
        print_example_run_usage("tools/benchmark/example_run.jl")
        return nothing
    end

    return run_uc_example_workflow(
        BenchmarkUCAlgorithm(),
        opts;
        algo_name = "benchmark",
        input = :excel,
        # Optional overrides:
        #   optimizer = HiGHS.Optimizer,
        #   calibration = (MODEL_IS_NETWORK_CON = 1, MODEL_CONSIDER_BESS = 0),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
