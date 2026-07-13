"""
    04_powersystems_native.jl

演示统一入口接收原生 PowerSystems.System：

1. 由 PowerSystemCaseBuilder 构造内置系统；
2. 通过 data_centers 传入数据中心参数；
3. 通过 frequency_parameters 传入机组调频参数；
4. 只切换 algorithm，就可以复用同一套 PowerSystems 数据入口。

这个示例默认运行 CCG。可设置 UC_ALGORITHM=benchmark 或 benders 运行其他算法。
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems
using PowerSystemCaseBuilder

const ALGORITHM = Symbol(get(ENV, "UC_ALGORITHM", "ccg"))
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))

# 构造一个 PowerSystems 原生 System。
# 如果已有 sys 对象，则可以跳过这一步，直接把 sys 传给 solve_uc。
const CASE_NAME = "c_sys5_all_components"
println("Building PowerSystems case: ", CASE_NAME)
sys = build_system_from_powersystems(CASE_NAME; case_category = PSITestSystems)

# 调频参数以机组名称为 key。
# R 对不参与调频的机组也建议给出非零值，以避免频率拟合时出现除零问题。
frequency_parameters = Dict(
    "Solitude" => (H = 7.0, D = 0.061, K = 0.9, F = 0.15, T = 8.0, R = 0.06),
    "Park City" => (H = 5.5, D = 0.121, K = 0.95, F = 0.35, T = 7.0, R = 0.06),
    "Alta" => (H = 3.5, D = 0.181, K = 0.98, F = 0.25, T = 9.0, R = 0.06),
    "Brighton" => (H = 5.0, D = 0.0, K = 0.0, F = 0.0, T = 0.0, R = 1.0),
    "Sundance" => (H = 5.0, D = 0.0, K = 0.0, F = 0.0, T = 0.0, R = 1.0),
)

# data_centers 中的功率单位是 MW；桥接层会按系统 base power 转换为内部标幺值。
data_centers = [
    (
        bus = 3,
        p_max = 0.5,
        p_min = 0.0,
        idle_power = 0.0,
        server_energy = 0.0,
        lambda = 0.0,
        mu = 1.0,
        workload = fill(0.0, 24),
    ),
]

result = solve_uc(
    algorithm = ALGORITHM,
    input = :powersystems,
    sys = sys,
    scenario_limit = SCENARIO_LIMIT,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        MODEL_CONSIDER_DATA_CENTER = true,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 1,
        BENDERS_MAX_ITERATIONS = 1,
        BENDERS_PARALLEL_SUBPROBLEMS = false,
    ),
    output_dir = joinpath(PROJECT_ROOT, "output", "examples", "powersystems", String(ALGORITHM)),
    verbosity = :silent,
)

print_uc_result(result)
