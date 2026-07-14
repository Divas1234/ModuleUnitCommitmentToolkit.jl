# 统一接口示例

本目录中的程序全部围绕包级统一入口编写：

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    scenario_limit = 1,
    calibration = (MODEL_CONSIDER_FREQUENCY_CONTROL = 0,),
    output_dir = "output/examples/benchmark",
)
```

调用方只需要设置两个指示参数：

| 参数 | 可选值 | 含义 |
|---|---|---|
| `algorithm` | `:benchmark`、`:benders`、`:ccg` | 选择内部算法模块 |
| `input` | `:excel`、`:powersystems`、`:powersystems_csv` | 选择统一数据入口 |

算法模块由 `solve_uc` 延迟加载，调用方不需要自己管理 `include` 顺序。推荐业务代码
使用 `solve_uc` 或显式构造 `UCSolveRequest`；只有需要访问 Benders 中间模型时，才使用
`tools/benders/setup.jl` 的低层接口。

## 示例文件

| 文件 | 内容 | 是否执行优化 |
|---|---|---:|
| `01_excel_single_solve.jl` | Excel 数据 + 单次统一求解 | 是 |
| `02_input_spec_and_data.jl` | 使用 `UCInputSpec` 加载并检查命名数据 | 否 |
| `03_three_algorithm_comparison.jl` | 同一数据入口依次调用三种算法 | 是 |
| `04_powersystems_native.jl` | PowerSystems 原生系统 + 数据中心参数 | 是 |
| `05_benders_named_setup.jl` | Benders 新命名字段和旧位置解构兼容层 | 是 |
| `06_powersystems_case_catalog.jl` | 6/30/118 总线及大算例目录、桥接和可选求解 | 默认否 |
| `07_ieee30_frequency_datacenter_uc.jl` | IEEE 30 节点 + 频率问题 + 数据中心挂载的完整 UC | 默认是 |

从仓库根目录执行：

```bash
julia --project=. examples/unified_api/01_excel_single_solve.jl
julia --project=. examples/unified_api/02_input_spec_and_data.jl
julia --project=. examples/unified_api/03_three_algorithm_comparison.jl
julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
UC_HORIZON=4 julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

选择不同 PowerSystems 算例时只需改变环境变量，数据入口保持不变：

```bash
UC_CASE=ieee30 julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
UC_CASE=ieee118 UC_RUN_SOLVE=1 UC_ALGORITHM=benchmark \
  julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
```

程序支持的稳定别名由 `powersystems_case_catalog()` 和
`list_powersystems_cases()` 返回。核心别名包括 `ieee6`、`ieee30` 和 `ieee118`；此外还
提供 `ieee14`、`ieee24`、`c_sys5_all_components`、`rts_gmlc`、`activsg2000` 和
`activsg10k`。118-bus 入口使用安装依赖内的 `PowerSystemsTestData/118-Bus` 数据资产，
外部精确 IEEE-118 文件仍可直接传入文件路径。

如果是在已经执行过 `using ModuleUnitCommitmentToolkit` 的 Julia REPL 中测试，更新源码后
请先退出并重新启动 Julia，再重新执行上述代码。`UCSolveRequest` 是带字段的公开结构体，
字段变更不能在同一个已加载模块中热替换；否则可能看到旧版本“不支持 `verbosity`”的错误。

PowerSystems 示例需要 `PowerSystemCaseBuilder` 的内置算例和可用的 Gurobi 环境：

```bash
julia --project=. examples/unified_api/04_powersystems_native.jl
```

### IEEE 30 节点频率-数据中心 UC

`07_ieee30_frequency_datacenter_uc.jl` 是一个更完整的业务侧示例：它固定读取 `:ieee30`
算例，打印 30 个母线、6 台常规机组、1 台风电、41 条线路和 21 个负荷的系统边界，为
常规机组配置 `H/D/K/F/T/R`，为按渗透率计算容量的风电配置 `Fcmode/Kw/Rw/Mw/Dw/Tw`，
并把一个 20 MW 数据中心挂载到 5 号母线。默认风电渗透率和故障扰动幅度均为 5%，可通过
`UC_WIND_PENETRATION` 与 `UC_FREQUENCY_CONTINGENCY_FRACTION` 调整。随后程序通过
`load_uc_data` 打印统一数据维度和有效 config，再用 `UCSolveRequest` 统一调用
`benchmark`、`benders` 或 `ccg`。

示例中的输入不再只依赖长文本日志：每张输入表都会先转换为 `DataFrame`，在终端以表格
形式打印，并在求解前写入显式输出根目录：

```text
output/examples/powersystems/ieee30/<algorithm>/<run_id>/
├── input/
│   ├── 01_buses.csv
│   ├── 02_thermal_generators.csv
│   ├── 03_wind_generators.csv
│   ├── 04_branches.csv
│   ├── 05_loads.csv
│   ├── 06_thermal_frequency_parameters.csv
│   ├── 07_wind_frequency_parameters.csv
│   ├── 08_data_centers.csv
│   ├── 09_model_dimensions.csv
│   ├── 10_effective_config.csv
│   ├── 11_unified_wind_parameters.csv
│   └── 12_wind_availability.csv
└── benchmark_uc/<run_id>/scheduling/   # 或 benders/、ccg/
```

其中 `02_thermal_generators.csv` 特别同时保留 PowerSystems 原始 `source_p_max_pu`、
机组 `rating_pu` 和桥接后的 `uc_p_max_pu`，便于检查零上限回退逻辑；`10_effective_config.csv`
是 `load_uc_data` 实际得到的模型配置，不是仅由调用方声明的配置草稿。

建议先用 4 小时窗口验证接口和模型链路：

```bash
UC_HORIZON=4 UC_ALGORITHM=benchmark \
  julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

只检查 PowerSystems 桥接、频率参数和数据中心数据，不启动优化：

```bash
UC_HORIZON=4 UC_RUN_SOLVE=0 \
  julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

该命令虽然跳过优化，但仍会完成全部输入 DataFrame 的终端展示和 CSV 快照写入；命令结束
后直接打开最新的 `output/examples/powersystems/ieee30/benchmark/<run_id>/input/` 即可核对。

`PowerSystems` 原生功率字段已经是 `SYSTEM_BASE` 标幺值；示例中的数据中心参数仍按 MW
填写，由统一桥接层转换为模型内部标幺值。5% 事故容量和 5% 风电渗透率是便于教学
smoke test 且能产生多机组开停机组合的标定值，正式研究应依据实际 N-1 事故和新能源
规划比例重新设定这两个参数。

## 1. `solve_uc` 的两种调用形式

### 直接关键字调用

适合脚本和简单服务调用。所有输入参数在一个地方声明：

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 5,
    ),
)
```

### 显式请求对象

适合需要记录请求、批量执行或在应用层传递参数的场景：

```julia
request = UCSolveRequest(
    algorithm = :benders,
    input = :excel,
    scenario_limit = 3,
    calibration = Dict(
        "BENDERS_MAX_ITERATIONS" => 5,
        "BENDERS_PARALLEL_SUBPROBLEMS" => 0,
    ),
    output_dir = "/tmp/module-uc/benders",
)

result = solve_uc(request)
```

`UCSolveRequest` 会在构造时校验算法和数据入口。算法名称支持字符串及常用别名，例如
`"extensive-form"` 会规范化为 `:benchmark`。

## 2. 输出模式与结果展示

`solve_uc` 的默认输出模式是 `verbosity=:detailed`。数据配置完成后会先输出系统边界参数、
有效 `config` 字段和 runtime 配置；求解完成后再输出分层优化结果：

```text
[Request]
  algorithm       : benchmark
  input           : excel
[Status]
  status          : OPTIMAL
  upper_bound     : ...
  lower_bound     : ...
  gap             : ...
[Progress]
  iterations      : -
[Artifacts]
  output_dir      : /path/to/output
```

四种模式的用途如下：

| `verbosity` | 用途 | 终端行为 |
|---|---|---|
| `:detailed` | 交互式运行，默认值 | 完整边界/配置报告和详细优化报告 |
| `:summary` | 快速反馈 | 只打印统一分层摘要，隐藏内部日志 |
| `:verbose` | 算法调试 | 保留底层算法的完整日志 |
| `:silent` | 批处理、服务层或自定义报告 | 不自动打印，调用方自行处理返回值 |

批处理通常使用 `:silent`，需要标准格式时再显式调用 `print_uc_result`：

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 1,
    verbosity = :silent,
)

print_uc_result(result; detail = true)
```

`verbosity` 只控制输出，不改变 `UCSolveResult`。算法专属字段仍通过
`result.details` 或 `hasproperty(result, :field_name)` 访问。

调用 `print_uc_result(result; detail=true)` 时，结果各层会以 DataFrame 形式展示，并写入
`result.output_dir/result/`：请求、状态、进度、输入维度、有效配置、模型求解信息、迭代历史、
成本分解和算法诊断分别保存为编号 CSV，便于直接使用 DataFrames/CSV 做后处理。

## 3. 结果对象

三种算法都会返回 `UCSolveResult`。结果对象有三个统一字段：

```julia
result.algorithm   # :benchmark、:benders 或 :ccg
result.input       # :excel、:powersystems 或 :powersystems_csv
result.output_dir  # 本次运行实际使用的输出根目录
```

算法自己的命名结果字段会通过结果对象直接访问：

```julia
result.status
result.upper_bound
result.lower_bound
result.gap
result.history
```

也可以通过 `result.details` 获取完整的底层 `NamedTuple`：

```julia
println(keys(result.details))
println(result[:upper_bound])
```

不同算法的附加字段略有不同：benchmark 和 CCG 通常包含 `model`、`data`、`cost_summary`；
Benders 通常包含 `history`、`iterations` 和 `incumbent`。业务层应优先依赖统一字段，
访问算法专属字段前应使用 `hasproperty(result, :field_name)` 检查。

## 4. 标定参数的作用域

`calibration` 可以是 `NamedTuple` 或字典。键名对应 TOML/ENV 参数，布尔值会自动转换为
`0/1`。这些覆盖值只在当前 `solve_uc` 调用期间生效，不会污染后续调用：

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 10,
        CCG_PARALLEL_RECOURSE = false,
    ),
)
```

常用参数：

| 算法 | 参数 | 用途 |
|---|---|---|
| 公共模型 | `MODEL_CONSIDER_BESS` | 是否启用储能约束 |
| 公共模型 | `MODEL_CONSIDER_FREQUENCY_CONTROL` | 是否启用调频约束 |
| 公共模型 | `MODEL_CONSIDER_DATA_CENTER` | 是否启用数据中心约束 |
| benchmark | `BENCHMARK_UC_USE_DRO` | 是否使用 DRO 场景概率 |
| Benders | `BENDERS_MAX_ITERATIONS` | 最大分解迭代次数 |
| Benders | `BENDERS_PARALLEL_SUBPROBLEMS` | 是否并行求解子问题 |
| CCG | `CCG_INITIAL_SCENARIOS` | 初始场景数 |
| CCG | `CCG_SCENARIOS_PER_ITERATION` | 每轮增加的场景数 |
| CCG | `CCG_MAX_ITERATIONS` | 最大迭代次数 |
| CCG | `CCG_GAP_TOL` | 收敛间隙阈值 |

完整参数以 [`config/runtime_config.toml`](../../config/runtime_config.toml) 和
[`docs/runtime_configuration.md`](../../docs/runtime_configuration.md) 为准。

## 5. 输出目录

默认输出根目录为项目根目录下的 `output/`，不会因为调用方从其他目录启动而改变。可以
通过环境变量设置全局输出目录：

```bash
MODULE_UC_OUTPUT_DIR=/tmp/module-uc-output \
  julia --project=. examples/unified_api/01_excel_single_solve.jl
```

也可以只对当前请求设置：

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    output_dir = "/tmp/module-uc-output/benchmark",
)
```

`result.output_dir` 是调用方获取输出位置的唯一推荐方式，不要在业务代码中拼接算法
内部目录名。`MODULE_UC_RUN_ID` 可以固定算法运行 ID，便于 CI 或批量实验复现：

```bash
MODULE_UC_RUN_ID=demo_001 julia --project=. examples/unified_api/01_excel_single_solve.jl
```

## 6. PowerSystems 三种数据形式

### 已有 `System`

```julia
data = load_uc_data(
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
)
```

### 内置算例名称

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems,
    case_name = "c_sys5_all_components",
    case_category = PSITestSystems,
    scenario_limit = 3,
)
```

### PowerSystems + 项目扩展 CSV

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :powersystems_csv,
    sys = sys,
    case_dir = "/path/to/case_dir",
    scenario_limit = 3,
)
```

`input=:powersystems_csv` 必须同时提供 `sys` 和 `case_dir`；`input=:powersystems` 则需要
提供 `sys` 或 `case_name`，二者不能同时提供。

## 7. Benders 位置元组迁移

新代码使用命名字段：

```julia
setup = main(; scenario_limit = 1)

master_model = setup.master_model
sub_model = setup.sub_model
batch_subproblems = setup.batch_subproblems
NG = setup.NG
NT = setup.NT
```

`main` 返回的 `BendersSetup` 仍然支持旧的 20 项迭代解构，但只用于迁移旧程序：

```julia
# 兼容旧代码；不要在新代码中继续扩展这种位置接口。
legacy_values = collect(setup)
@assert length(legacy_values) == 20
```

新业务逻辑应直接使用 `solve_uc(algorithm=:benders, ...)`；只有调试 cut、主问题或子问题
模型时，才需要访问 `BendersSetup`。
