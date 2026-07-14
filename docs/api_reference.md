# 对外接口与调用参考

本文档以当前源码为准，区分“包级公共接口”和“工具脚本接口”。所有命令默认从项目根目录执行。

可直接运行的完整示例位于 [`examples/unified_api/README.md`](../examples/unified_api/README.md)。

## 1. 接口边界

### 包级接口

```julia
using ModuleUnitCommitmentToolkit
```

推荐通过下列函数完成数据加载、数据转换和基础 UC 求解：

| 接口 | 用途 | 主要返回值 |
|---|---|---|
| `load_uc_data(; ...)` | 统一加载 Excel、PowerSystems 原生系统或 CSV 扩展算例 | 带命名字段的数据对象 |
| `build_system_from_powersystems(name; case_category=...)` | 从 `PowerSystemCaseBuilder` 构造 `System` | `PowerSystems.System` |
| `load_native_powersystems_case(name; ...)` | 构造原生算例并直接转换为 UC 数据 | 与 `load_uc_data` 相同的数据对象 |
| `extract_uc_data_from_powersystems(sys; ...)` | 将已有 `System` 转换为底层 UC 结构 | 传统位置元组，适合桥接/调试 |
| `generate_frequency_parameters(sys; overrides=...)` | 为常规机组生成调频参数 | `Dict{String, NamedTuple}` |
| `generate_wind_scenarios_from_system(sys, params, mode, horizon; ...)` | 从原生系统生成风电场景 | `(winds, NW)` |
| `SUC_scucmodel(...)` | 直接构造并求解底层 SUC/SCUC 模型 | `Dict`，求解失败时可能为 `nothing` |
| `load_runtime_config!(; ...)` | 将 TOML 配置加载到 `ENV` | `(config_path, applied, skipped)` |

### 统一算法入口

新代码统一调用：

```julia
result = solve_uc(
    algorithm = :benchmark,       # :benchmark、:benders 或 :ccg
    input = :excel,               # :excel、:powersystems 或 :powersystems_csv
    scenario_limit = 3,
    calibration = (
        MODEL_CONSIDER_DATA_CENTER = 0,
        CCG_MAX_ITERATIONS = 10,
    ),
)
```

`solve_uc` 内部负责加载对应算法模块、选择数据入口、设置标定参数并返回结果。
`algorithm` 支持字符串别名；`calibration` 可以是 `NamedTuple` 或字典，键名对应
TOML/ENV 参数，布尔值会转换为 `1/0`，且只在本次调用期间生效。

常用标定项如下；完整参数仍以 [`runtime_configuration.md`](runtime_configuration.md)
和 `config/runtime_config.toml` 为准：

| 范围 | 参数示例 | 作用 |
|---|---|---|
| 公共模型 | `MODEL_CONSIDER_DATA_CENTER`、`MODEL_CONSIDER_FREQUENCY_CONTROL`、`MODEL_CONSIDER_BESS` | 开关数据中心、调频和储能约束 |
| benchmark | `BENCHMARK_UC_USE_DRO` | 控制 benchmark 是否使用 DRO 场景概率 |
| Benders | `BENDERS_MAX_ITERATIONS`、`BENDERS_PARALLEL_SUBPROBLEMS` | 最大迭代次数和子问题并行开关 |
| CCG | `CCG_INITIAL_SCENARIOS`、`CCG_SCENARIOS_PER_ITERATION`、`CCG_MAX_ITERATIONS`、`CCG_GAP_TOL` | 初始场景、每轮增量、最大迭代和收敛阈值 |

PowerSystems 调用只需要切换 `input`，其余参数保持同一套入口：

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
)
```

三种算法都返回带有 `algorithm`、`input` 和 `output_dir` 字段的命名结果对象，并保留
各自的 `status`、边界值、`gap`、`history` 和模型/输出字段。`tools/` 下的实现模块会
在第一次 `solve_uc` 调用时惰性加载。

### 输出模式

统一入口默认使用 `verbosity=:detailed`。数据加载完成后，终端会先输出完整系统边界参数、
有效模型 `config` 和 runtime 配置；求解完成后再输出目标值、上下界、gap、模型规模、
迭代历史、成本分解、算法诊断和输出文件位置。

四种模式如下：

| 模式 | 用途 | 终端行为 |
|---|---|---|
| `:detailed` | 默认交互和实验运行 | 边界/配置完整报告 + 详细优化结果 |
| `:summary` | 快速反馈 | 只输出 Request、Status、Progress、Artifacts 摘要 |
| `:verbose` | 底层算法排查 | 保留算法原始日志，并输出求解过程 |
| `:silent` | 批处理、服务层 | 不自动打印，由调用方自行渲染 |

批处理可以使用 `verbosity=:silent`，再显式调用 `print_uc_result(result; detail=true)`：

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    verbosity = :silent,
)

print_uc_result(result; detail = true)
```

`print_uc_result` 的每个分层部分都会在终端渲染为 `DataFrame`，并同步写入
`result.output_dir/result/`。文件包括 `01_request.csv`、`02_status.csv`、`03_progress.csv`、
`04_input_data.csv`、`05_effective_config.csv`、`06_model_solver.csv`、
`07_iteration_history.csv`、`08_cost_breakdown.csv` 和算法可用时生成的
`09_algorithm_diagnostics.csv`。因此终端结果与可供后处理的 CSV 使用同一套字段。

四种模式不会改变 `UCSolveResult` 的内容，只控制终端输出。算法专属的原始日志仍由
`:verbose` 保留，统一结果字段始终通过 `result.status`、`result.upper_bound` 等命名属性
访问。

## 2. 统一数据加载

### 2.1 Excel 默认模式

```julia
data = load_uc_data(; scenario_limit = 3)
```

该模式读取项目内 `data/data.xlsx`，并使用 `config/runtime_config.toml` 经环境变量
映射后的模型开关。

### 2.2 已有 PowerSystems.System

```julia
using PowerSystems

data = load_uc_data(
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
    horizon = 24,
    frequency_parameters = frequency_params,
    data_centers = data_centers,
)
```

`sys` 和 `case_name` 不能同时提供；当传入 `sys` 且 `case_dir == ""` 时，使用原生
PowerSystems 桥接逻辑，不需要扩展 CSV 文件。

### 2.3 PowerSystemCaseBuilder 算例

```julia
data = load_uc_data(
    input = :powersystems,
    case_name = "c_sys5_all_components",
    case_category = PSITestSystems,
    scenario_limit = 3,
    horizon = 24,
)
```

也可以直接调用 `load_native_powersystems_case`。常用的 `case_category` 包括
`MatpowerTestSystems`、`PSITestSystems` 和 `PSYTestSystems`，具体名称以当前
`PowerSystemCaseBuilder` 版本为准。

推荐优先使用工具包提供的稳定算例别名。算例目录可通过以下接口查看：

```julia
catalog = powersystems_case_catalog()
println(catalog.ieee6.case_name)
println(catalog.ieee118.description)

for case in list_powersystems_cases()
    println(case.alias, " => ", case.case_name)
end
```

可直接使用的核心别名包括 `:ieee6`、`:ieee14`、`:ieee24`、`:ieee30`、`:ieee118`、
`:c_sys5_all_components`、`:rts_gmlc`、`:activsg2000` 和 `:activsg10k`。其中前四个
MATPOWER 算例由 `MatpowerTestSystems` 提供；`:ieee118` 由安装版本中的
`PowerSystemsTestData/118-Bus` 数据资产构造，统一桥接为 118 总线、热机组、AC 支路和
区域负荷。对于本地已有的其它 `.m`、`.raw` 或 PowerSystems 可读文件，仍然可以直接把
文件路径作为 `case_name` 传入。

统一入口会屏蔽 `PowerSystemCaseBuilder` 在读取 MATPOWER 原始数据时产生的底层额定值
范围提示和反序列化信息，避免这些实现细节与系统边界、配置和优化结果混在一起。该处理
只影响日志显示，不会修改算例数据；构造失败、参数错误等异常仍会直接抛出。如果需要查看
底层原始诊断，请直接调用 `PowerSystemCaseBuilder.build_system(...)`，而业务代码建议继续
使用 `build_system_from_powersystems(...)`。

统一入口示例：

```julia
data = load_uc_data(
    input = :powersystems,
    case_name = :ieee30,       # 也可以写成 "ieee30" 或 "case30"
    scenario_limit = 1,
    horizon = 24,
)

result = solve_uc(
    algorithm = :benchmark,    # 改成 :benders 或 :ccg 即可复用同一数据入口
    input = :powersystems,
    case_name = :ieee118,
    scenario_limit = 1,
    output_dir = "output/powersystems/ieee118/benchmark",
    verbosity = :summary,
)
```

118-bus 等大算例建议先使用 `scenario_limit = 1` 做输入桥接和模型可行性检查，再逐步
提高场景数；算法比较时应为每个算法显式设置独立的 `output_dir`。

### 2.4 PowerSystems + 项目扩展 CSV

当需要使用项目自定义的启停、频率、储能、风电和数据中心参数时，传入：

```julia
data = load_uc_data(
    input = :powersystems_csv,
    sys = sys,
    case_dir = "/path/to/case_dir",
    scenario_limit = 5,
)
```

`case_dir` 模式至少需要 `thermal_uc.csv`；启用对应模型组件时还需要
`frequency_parameters.csv`、`storage_uc.csv`、`renewable_profiles.csv`、
`data_centers.csv` 和 `data_center_workloads.csv`。字段和必需条件详见
`src/input_data/powersystems_reader.jl` 的函数文档及参数校验错误信息。

## 3. 输入对象约定

### 调频参数

`frequency_parameters` 可以是按机组名称索引的字典，也可以是兼容旧代码的矩阵。
推荐使用字典：

```julia
frequency_parameters = Dict(
    "Gen-1" => (H = 6.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05),
)
```

字段含义为惯性 `H`、阻尼 `D`、调速器增益 `K`、汽轮机比例 `F`、时间常数 `T`
和调差率 `R`。不参与一次调频的机组仍应使用非零 `R`（通常为 `1.0`），避免
频率拟合中的除零问题。大型系统可先调用 `generate_frequency_parameters`，再用
`overrides` 覆盖关键机组。

同一个字典也可以配置 PowerSystems 中的风电机组。风电记录按组件名称索引，使用
`Fcmode`、`Kw`、`Rw`、`Mw`、`Dw`、`Tw` 六个字段：`Fcmode >= 0.5` 开启虚拟惯量/阻尼
模式，`Kw/Rw` 表示一次调频增益和下垂，`Mw/Dw/Tw` 表示等效惯量、阻尼和响应时间常数。
因此热机组和风电可以合并后一次传给 `UCSolveRequest`：

```julia
frequency_parameters = merge(
    generate_frequency_parameters(sys),
    Dict("Wind Farm 1" => (Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0)),
)
```

完整的 IEEE 30 节点、风电、频率控制和数据中心 UC 示例见
[`examples/unified_api/07_ieee30_frequency_datacenter_uc.jl`](../examples/unified_api/07_ieee30_frequency_datacenter_uc.jl)。

### 数据中心

每个数据中心至少提供 `bus` 和 `p_max`，可选字段为 `p_min`、`idle_power`、
`server_energy`、`lambda`、`mu`、`workload` 和 `voltage_regulation`：

```julia
data_centers = [(
    bus = 3,
    p_max = 0.5,
    p_min = 0.0,
    idle_power = 0.0,
    server_energy = 0.0,
    lambda = 0.0,
    mu = 1.0,
    workload = fill(0.0, 24),
)]
```

原生 `PowerSystems.System` 中的功率组件已经处于 `SYSTEM_BASE` 标幺体系，桥接时会直接
沿用这些系统基准值，避免再次除以 `base_power`。只有接口额外接收的数据中心参数仍按
MW 输入，并在进入模型时转换为标幺值。`horizon` 必须为正整数，工作负载短于
`horizon` 时会用最后一个值补齐。

### `load_uc_data` 返回对象

返回对象是带命名字段的 `NamedTuple`，稳定字段为：

```text
config_param, units, lines, loads, winds, psses, DataCentras,
NB, NG, NL, ND, NT, NC, ND2, NW, NS, full_scenario_probability
```

模型结构中的功率通常为标幺值；PowerSystems 组件使用其已有的系统基准值，数据中心等
外部 MW 参数只在对应扩展入口处转换。
`NS` 为场景数，`NW` 为风电机组数，`full_scenario_probability` 为等概率场景的
`1 / NS`。

## 4. 三种算法兼容接口

业务代码应优先使用上一节的 `solve_uc`；本节函数保留给算法调试、旧脚本和需要访问
中间模型对象的场景。它们仍然复用统一的 `load_uc_data`，但需要调用方自行 `include`
工具文件，不应作为新的业务层入口。

### 4.1 Extensive-form benchmark

```julia
include("tools/benchmark/benchmark_uc.jl")

result = solve_benchmark_uc(; scenario_limit = 3)
```

PowerSystems 原生系统可使用：

```julia
result = solve_benchmark_uc_powersystems(
    sys;
    scenario_limit = 3,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
)
```

也支持 `solve_benchmark_uc_powersystems("case_name"; case_category=...)`。
结果的主要字段为 `status`、`model`、`data`、`upper_bound`、`lower_bound`、
`gap`、`active_scenarios`、`history` 和 `cost_summary`。

### 4.2 C&CG

```julia
include("tools/ccg/ccg_solver.jl")

result = solve_ccg_unit_commitment(
    input = :powersystems,
    scenario_limit = 3,
    sys = sys,
    horizon = 24,
)
```

该函数只接受关键字参数，不接受 `load_uc_data` 返回对象作为位置参数；初始场景数
由 `CCG_INITIAL_SCENARIOS` 控制。结果字段包括 `status`、`model`、`evaluation`、
`data`、`history`、`active_scenarios`、`upper_bound`、`lower_bound`、`gap` 和
`cost_summary`。

### 4.3 Benders

```julia
include("tools/benders/setup.jl")

setup = main(; scenario_limit = 3)

result = multiple_bender_decomposition_scuc(
    setup.master_model,
    setup.sub_model,
    setup.master_struct,
    setup.batch_subproblems,
    setup.winds,
    setup.config_param,
    setup.NG,
    setup.NT,
    length(setup.winds.index),
    setup.ND,
    setup.NL,
)
```

`main` 返回命名的 `BendersSetup`。旧代码仍可通过兼容迭代器按原 20 项顺序解构，但新代码
应使用字段访问。该兼容迭代器只读且不包含新增的 `setup.data` 字段，便于后续移除位置接口。
若只需要输入数据，优先使用 `load_uc_data` 的命名字段。Benders 结果的主要字段为 `status`、`history`、
`upper_bound`、`lower_bound`、`gap`、`iterations` 和 `incumbent`。

## 5. 命令行入口

| 命令 | 作用 |
|---|---|
| `julia --project=. tools/benchmark/run_algorithm_comparison.jl` | 批量比较 benchmark、Benders 和 C&CG |
| `julia --project=. tools/benders/driver.jl` | 运行 Benders |
| `julia --project=. tools/ccg/driver.jl` | 运行 C&CG |
| `julia --project=. examples/unified_api/04_powersystems_native.jl` | 运行统一 PowerSystems 示例 |
| `julia --project=. examples/powersystems_algorithms_demo.jl` | 运行低层 PowerSystems 三算法调试示例 |
| `julia --project=. test/runtests.jl` | 运行轻量测试 |
| `./gui/start.sh` | 启动本地 dashboard |

单次命令可通过环境变量覆盖 TOML 默认值，例如：

```bash
CCG_SCENARIO_LIMIT=5 CCG_MAX_ITERATIONS=20 \
  julia --project=. tools/ccg/driver.jl
```

完整配置说明见 [`runtime_configuration.md`](runtime_configuration.md)。

## 6. 输出与路径

算法输出默认位于项目根目录的 `output/`，不再依赖调用者当前工作目录；可以用绝对路径的
`MODULE_UC_OUTPUT_DIR` 或统一入口的 `output_dir` 指定基础输出目录。相对路径会按项目根目录
解析，用 `MODULE_UC_RUN_ID` 指定运行 ID。benchmark
和 CCG 的调度文件通常位于 `<output_dir>/<algorithm>/<run_id>/scheduling/`；当前
Benders 统一入口返回内存中的求解结果，暂不自动导出同样的调度文件。

benchmark 比较结果通常位于：

```text
output/comparison/<run_id>/summary.csv
output/comparison/<run_id>/benchmark_report.md
output/<algorithm>/<run_id>/scheduling/
```

直接调用底层函数时，也建议使用 `MODULE_UC_OUTPUT_DIR` 或显式 `output_dir`，以便在
Notebook、服务进程和 CI 中分别管理结果。
