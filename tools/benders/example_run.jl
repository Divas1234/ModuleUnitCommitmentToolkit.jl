#!/usr/bin/env julia
"""
Runnable example: Benders Decomposition UC solver with explicit diagnostic parameters.

Usage:
  julia --project=. tools/benders/example_run.jl [scenario_limit] [--fast] [OPTIONS]
  julia --project=. tools/benders/example_run.jl 2 --all-details
  julia --project=. tools/benders/example_run.jl --help
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

function main(
    args = ARGS;
    scenario_limit::Int = 2,
    fast_direct::Bool = false,
    show_constraints::Bool = false,     # [1] 哪条约束进来了
    show_integrity::Bool = false,       # [2] 建模后整体完整性测试结果
    show_solver_log::Bool = false,      # [3] 开始计算/优化时间戳与实时求解日志
    show_results::Bool = true,          # [4] 优化后关键结果与分项成本
    show_artifacts::Bool = true,        # [5] 保存时机与目标文件夹/文件清单
    save_log::Bool = true,              # [6] 是否写入具体日志文件
    log_file::Union{Nothing, String} = nothing,
    verbosity::Symbol = :summary,       # :summary | :detailed | :verbose
)
    opts = if isempty(args)
        UCExampleOptions(
            scenario_limit = scenario_limit,
            fast_direct = fast_direct,
            verbosity = show_solver_log ? :verbose : verbosity,
            show_constraints = show_constraints,
            show_integrity = show_integrity,
            show_solver_log = show_solver_log,
            show_results = show_results,
            show_artifacts = show_artifacts,
            save_log = save_log,
            log_file = log_file,
        )
    else
        parse_example_run_args(args; default_scenarios = scenario_limit)
    end

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
