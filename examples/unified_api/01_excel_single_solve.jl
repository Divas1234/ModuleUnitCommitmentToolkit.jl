"""
    01_excel_single_solve.jl

最小但完整的统一算法入口示例：

1. 从脚本位置推导项目根目录，不依赖调用者当前 pwd()；
2. 使用 Excel 数据入口；
3. 通过 algorithm 选择 benchmark；
4. 通过 calibration 设置本次运行的模型/算法参数；
5. 通过 output_dir 显式指定输出根目录；
6. 使用 UCSolveResult 的统一字段读取结果。

运行：

    julia --project=. examples/unified_api/01_excel_single_solve.jl
"""

using Pkg

# examples/unified_api/ -> examples/ -> 项目根目录。
# 这样无论用户从哪里启动 Julia，包环境和示例路径都保持稳定。
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

# 只使用一个场景是为了让示例适合作为首次运行检查。
# 正式实验可以把它提高到 3、10 或配置文件要求的场景数量。
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))

# 统一入口会把这些值临时写入 ENV，并在 solve_uc 返回后恢复原值。
# 这里关闭 BESS 和调频约束，使示例更适合没有这些扩展数据的 Excel 算例。
const CALIBRATION = (
    MODEL_CONSIDER_BESS = false,
    MODEL_CONSIDER_FREQUENCY_CONTROL = false,
    BENCHMARK_UC_USE_DRO = false,
)

# output_dir 可以是绝对路径，也可以是相对路径。
# 相对路径会由库按项目根目录解析，而不是按调用者的 pwd() 解析。
const OUTPUT_DIR = joinpath(PROJECT_ROOT, "output", "examples", "excel_benchmark")

println("[1/3] Creating a unified solve request...")
request = UCSolveRequest(
    algorithm = :benchmark,
    input = :excel,
    scenario_limit = SCENARIO_LIMIT,
    calibration = CALIBRATION,
    output_dir = OUTPUT_DIR,
    # :detailed 会在数据配置完成后输出边界/配置报告，并在求解结束后输出详细结果。
    verbosity = :detailed,
)

println("[2/3] Solving with the benchmark algorithm...")
# solve_uc(request) 会在内部：
# - 确认 algorithm 和 input；
# - 加载 benchmark、CCG、Benders 所需的实现模块；
# - 调用统一的 load_uc_data；
# - 在本次调用范围内应用 calibration；
# - 返回 UCSolveResult。
result = solve_uc(request)

println("[3/3] Reading the common result fields...")
println("  status      = ", result.status)
println("  output_dir  = ", result.output_dir)

# 不同算法的 details 字段不同；统一层允许通过 hasproperty 安全地读取可选字段。
if hasproperty(result, :history)
    println("[Algorithm details]")
    println("  history length = ", length(result.history))
end
