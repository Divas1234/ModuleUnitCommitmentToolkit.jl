"""
    03_three_algorithm_comparison.jl

使用完全相同的 Excel 数据入口，依次选择：

* benchmark：extensive-form 基准模型；
* benders：Benders 分解；
* ccg：Column-and-Constraint Generation。

程序通过 algorithm 指示参数切换内部模块，不直接 include 三个算法脚本。
为了适合 smoke/demo 运行，每种算法默认只处理一个场景并限制迭代次数。

运行：

    julia --project=. examples/unified_api/03_three_algorithm_comparison.jl
"""
##
using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const OUTPUT_ROOT = joinpath(PROJECT_ROOT, "output", "examples", "three_algorithms")

# 每个算法的 calibration 只传给自己的内部模块。
# 公共模型参数可以放入每一个 NamedTuple 中，保持三种算法的 formulation 一致。
const CALIBRATIONS = Dict(
    :benchmark => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENCHMARK_UC_USE_DRO = false,
    ),
    :benders => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENDERS_MAX_ITERATIONS = 1,
        BENDERS_PARALLEL_SUBPROBLEMS = false,
    ),
    :ccg => (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 1,
        CCG_PARALLEL_RECOURSE = false,
    ),
)

function print_summary(algorithm, result)
    println("\n--- $(algorithm) ---")
    print_uc_result(result)
end

results = Dict{Symbol,Any}()

for algorithm in (:benchmark, :benders, :ccg)
    println("Running $(algorithm) through the common solve_uc entry...")

    # 每次请求使用独立的输出目录，避免多个算法覆盖调度文件。
    # 这里先收起算法内部日志，再按统一格式输出结果；需要排查算法过程时改为 :verbose。
    request = UCSolveRequest(
        algorithm = algorithm,
        input = :excel,
        scenario_limit = SCENARIO_LIMIT,
        calibration = CALIBRATIONS[algorithm],
        output_dir = joinpath(OUTPUT_ROOT, String(algorithm)),
        verbosity = :silent,
    )
    result = solve_uc(request)
    results[algorithm] = result
    print_summary(algorithm, result)
end

println("\nComparison table:")
println(rpad("algorithm", 14), rpad("status", 22), "upper_bound")
for algorithm in (:benchmark, :benders, :ccg)
    result = results[algorithm]
    println(rpad(String(result.algorithm), 14), rpad(String(result.status), 22), result.upper_bound)
end

# 注意：不同算法的 upper_bound 只有在模型开关、数据和收敛条件一致时才适合比较。
# 本示例只打印结果，不强行断言三者数值相等。
