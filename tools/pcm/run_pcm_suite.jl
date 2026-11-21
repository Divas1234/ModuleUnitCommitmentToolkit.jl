#!/usr/bin/env julia
# PCM 四方案统一入口：配置、运行、结果拼接和清单导出均由此文件完成。

include("config/suite_config.jl")
include("benchmark/suite_runner.jl")
include(joinpath("results", "export_result_catalog.jl"))

using .PCMSuiteConfig
using .PCMThreeMethodBenchmark
using .PCMResultCatalog

function main()
    config = PCMSuiteConfig.load_config()
    PCMSuiteConfig.print_config(config)
    config.resume && (ENV["PCM_BENCHMARK_RESUME"] = "true")
    ENV["PCM_OVERLAP_MODE"] = "ml_prediction"
    # 底层基准模块用该变量区分“显式批次目录”和“自动单负荷命名”。
    # 多负荷套件必须传递显式目录，否则会被单负荷命名保护正确拒绝。
    ENV["PCM_THREE_METHOD_OUTPUT"] = config.output_root
    result_root = PCMThreeMethodBenchmark.main(;
        project_root=config.project_root,
        julia_project=config.julia_project,
        input_file=config.input_file,
        output_root=config.output_root,
        profiles=config.profiles,
        methods=config.methods,
        runs=config.runs,
        intervals=config.intervals,
        window_hours=config.window_hours,
        network_constraints=config.network_constraints,
        random_seed=config.random_seed,
        overlap_mode="ml_prediction",
        solver=PCMThreeMethodBenchmark.normalize_solver(config.solver),
    )
    config.export_results && PCMResultCatalog.export_suite_catalog(result_root; execution_hours=config.window_hours)
    println("\nPCM suite finished: $result_root")
    result_root
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
