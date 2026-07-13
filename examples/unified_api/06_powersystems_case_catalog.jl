"""
    06_powersystems_case_catalog.jl

统一 PowerSystems 算例入口示例。

这个程序演示四件事：

1. 打印工具包维护的稳定算例目录；
2. 使用 `:ieee6`、`:ieee30`、`:ieee118` 别名构造原生 PowerSystems.System；
3. 通过统一 `load_uc_data` 入口验证不同规模算例已经转换为相同的数据类型；
4. 可选地用一个算法求解当前选择的算例。

默认只做“构造 + 数据桥接”，避免运行示例时误启动大规模优化。设置
`UC_RUN_SOLVE=1` 后才会调用 `solve_uc`。

环境变量：

- `UC_CASE=ieee6|ieee30|ieee118`，默认 `ieee6`；
- `UC_ALGORITHM=benchmark|benders|ccg`，默认 `benchmark`；
- `UC_RUN_SOLVE=0|1`，默认 `0`；
- `UC_SCENARIO_LIMIT`，默认 `1`；
- `UC_HORIZON`，默认 `24`。
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems

const CASE_ALIAS = Symbol(get(ENV, "UC_CASE", "ieee6"))
const ALGORITHM = Symbol(get(ENV, "UC_ALGORITHM", "benchmark"))
const RUN_SOLVE = lowercase(get(ENV, "UC_RUN_SOLVE", "1")) in ("1", "true", "yes")
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const HORIZON = parse(Int, get(ENV, "UC_HORIZON", "24"))

println("Available curated PowerSystems cases:")
for case in list_powersystems_cases()
    println("  ", rpad(case.alias, 22), " -> ", case.case_name, " | ", case.description)
end

case = getproperty(powersystems_case_catalog(), CASE_ALIAS)
println("\nSelected case: ", case.alias, " (", case.description, ")")
sys = build_system_from_powersystems(CASE_ALIAS)

println("System dimensions:")
println("  buses      = ", length(collect(get_components(ACBus, sys))))
println("  generators = ", length(collect(get_components(ThermalStandard, sys))))
println("  branches   = ", length(collect(get_components(ACBranch, sys))))
println("  loads      = ", length(collect(get_components(PowerLoad, sys))))

data = load_uc_data(input = :powersystems, case_name = CASE_ALIAS, scenario_limit = SCENARIO_LIMIT, horizon = HORIZON)
println("Unified data dimensions: NB=$(data.NB), NG=$(data.NG), NL=$(data.NL), ND=$(data.ND), NT=$(data.NT)")

if RUN_SOLVE
    result = solve_uc(
        algorithm = ALGORITHM,
        input = :powersystems,
        case_name = CASE_ALIAS,
        scenario_limit = SCENARIO_LIMIT,
        horizon = HORIZON,
        calibration = (
            MODEL_CONSIDER_BESS = false,
            MODEL_CONSIDER_FREQUENCY_CONTROL = false,
            MODEL_CONSIDER_DATA_CENTER = false,
            CCG_INITIAL_SCENARIOS = 1,
            CCG_SCENARIOS_PER_ITERATION = 1,
            CCG_MAX_ITERATIONS = 1,
            BENDERS_MAX_ITERATIONS = 1,
            BENDERS_PARALLEL_SUBPROBLEMS = false,
        ),
        output_dir = joinpath(PROJECT_ROOT, "output", "examples", "powersystems", case.alias, String(ALGORITHM)),
        verbosity = :summary,
    )
    print_uc_result(result; detail = true)
else
    println("Set UC_RUN_SOLVE=1 to run ", ALGORITHM, " on ", CASE_ALIAS, ".")
end
