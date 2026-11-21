#!/usr/bin/env julia
"""
Runnable example: Benders Decomposition UC solver.

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
    opts = resolve_uc_example_options(
        args;
        scenario_limit, fast_direct, show_constraints, show_integrity, show_solver_log,
        show_results, show_artifacts, save_log, log_file, verbosity,
    )
    opts.help && return print_example_run_usage("tools/benders/example_run.jl"; supports_fast = true)
    return run_uc_example_workflow(
        BendersAlgorithm(fast_direct = opts.fast_direct),
        opts;
        algo_name = opts.fast_direct ? "benders_fast" : "benders",
        input = :excel,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
