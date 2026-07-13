"""
    07_ieee30_frequency_datacenter_uc.jl

完整的 PowerSystems 30 节点 UC 示例。

本示例把一个真实的业务调用拆成七个阶段：

1. 通过统一入口选择 `:ieee30` 算例；
2. 读取并打印系统边界，包括母线、机组、线路和负荷；
3. 为所有常规机组生成调频参数，并展示 H/D/K/F/T/R；
4. 在指定母线上挂载一个风电机组和一个数据中心柔性负荷；
5. 为风电配置虚拟惯量、阻尼和一次调频参数；
6. 用统一 `load_uc_data` 入口检查标幺化后的模型数据和有效 config；
7. 用 `UCSolveRequest` 调用统一 UC 入口，并输出分层求解结果。

运行方式：

```bash
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

可选环境变量：

- `UC_ALGORITHM=benchmark|benders|ccg`，默认 `benchmark`；
- `UC_HORIZON=4`，适合快速 smoke test；默认 `24`；
- `UC_SCENARIO_LIMIT=1`，默认 `1`；
- `UC_RUN_SOLVE=0`，只做系统构造和数据桥接，不启动优化；

说明：

- PowerSystems 原生组件已经处于系统基准标幺体系；
- 本示例把 20 MW 风电以 `RenewableDispatch` 接入 5 号母线，并通过同一个
  `frequency_parameters` 字典配置风电 `Fcmode/Kw/Rw/Mw/Dw/Tw`；
- `data_centers` 中的功率参数使用 MW，桥接层负责转换为内部标幺值；
- 频率控制和数据中心约束通过 `calibration` 显式打开；
- 示例使用 `verbosity=:silent`，先由程序自己打印输入边界，再统一打印 `UCSolveResult`，
  避免底层算法日志打断业务层报告。
"""

using Pkg

# 无论从仓库根目录还是从 examples 目录启动，都把项目根目录作为活动环境。
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems

"""把环境变量转换成正整数，并在入口处尽早给出清晰错误。"""
function positive_int_env(name::AbstractString, default::Int)
    value = tryparse(Int, get(ENV, name, string(default)))
    value === nothing || value > 0 || throw(ArgumentError("$name must be a positive integer"))
    return value
end

"""把环境变量转换成布尔值，便于控制是否运行优化。"""
function bool_env(name::AbstractString, default::Bool)
    value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    value in ("1", "true", "yes", "y", "on") && return true
    value in ("0", "false", "no", "n", "off") && return false
    throw(ArgumentError("$name must be one of 0/1/true/false"))
end

"""打印统一的分层标题，让输入报告和优化结果容易区分。"""
function print_section(title::AbstractString)
    separator = repeat("=", 100)
    println("\n", separator)
    println("[", title, "]")
    println(separator)
end

const CASE_NAME = :ieee30
const ALGORITHM = Symbol(lowercase(get(ENV, "UC_ALGORITHM", "benchmark")))
const HORIZON = positive_int_env("UC_HORIZON", 24)
const SCENARIO_LIMIT = positive_int_env("UC_SCENARIO_LIMIT", 1)
const RUN_SOLVE = bool_env("UC_RUN_SOLVE", true)

ALGORITHM in (:benchmark, :benders, :ccg) ||
    throw(ArgumentError("UC_ALGORITHM must be benchmark, benders, or ccg"))

print_section("1. 选择算例和统一入口")
case_entry = getproperty(powersystems_case_catalog(), CASE_NAME)
println("case alias       : ", CASE_NAME)
println("canonical case   : ", case_entry.case_name)
println("description      : ", case_entry.description)
println("algorithm        : ", ALGORITHM)
println("horizon          : ", HORIZON, " hours")
println("scenario_limit   : ", SCENARIO_LIMIT)

# 这里不直接调用 PowerSystemCaseBuilder.build_system，而是使用工具包统一入口。
# 统一入口负责解析算例别名、屏蔽底层 rating 诊断日志，并返回原生 System 对象。
sys = build_system_from_powersystems(CASE_NAME)
system_base = Float64(get_base_power(sys))

# 在原生 PowerSystems 系统上追加一个可弃风的风电机组。
# `RenewableDispatch` 表示该机组允许在 UC 中被削减。这个 MATPOWER 系统的原生
# 组件读取结果已经是 SYSTEM_BASE pu，因此新增组件也显式使用 20/100=0.20 pu
# 和 8/100=0.08 pu，避免把 20 MW 误当成 20 pu。
const WIND_NAME = "IEEE30 Wind Farm"
const WIND_BUS = 5
wind_bus = only(filter(bus -> get_number(bus) == WIND_BUS, collect(get_components(ACBus, sys))))
wind_generator = RenewableDispatch(;
    name = WIND_NAME,
    available = true,
    bus = wind_bus,
    active_power = 0.08,
    reactive_power = 0.0,
    rating = 0.20,
    prime_mover_type = PrimeMovers.WT,
    reactive_power_limits = nothing,
    power_factor = 1.0,
    operation_cost = RenewableGenerationCost(nothing),
    base_power = system_base,
)
add_component!(sys, wind_generator)

buses = sort(collect(get_components(ACBus, sys)), by = get_number)
thermal_generators = sort(collect(get_components(ThermalStandard, sys)), by = get_name)
wind_generators = sort(collect(get_components(RenewableGen, sys)), by = get_name)
branches = sort(collect(get_components(ACBranch, sys)), by = get_name)
power_loads = sort(collect(get_components(PowerLoad, sys)), by = get_name)

print_section("2. PowerSystems 系统边界")
println("system base power: ", system_base, " MVA")
println("buses            : ", length(buses))
println("thermal units    : ", length(thermal_generators))
println("wind units       : ", length(wind_generators))
println("AC branches      : ", length(branches))
println("power loads      : ", length(power_loads))

println("\n[母线边界]")
println("  number | name                 | type       | base_voltage_kV")
for bus in buses
    println(
        "  ",
        lpad(get_number(bus), 6), " | ",
        rpad(get_name(bus), 20), " | ",
        rpad(string(get_bustype(bus)), 10), " | ",
        get_base_voltage(bus),
    )
end

println("\n[常规机组边界；功率字段为 SYSTEM_BASE 标幺值]")
println("  name                 | bus | p_min_pu | p_max_pu | initial_pu")
for generator in thermal_generators
    limits = get_active_power_limits(generator)
    println(
        "  ",
        rpad(get_name(generator), 20), " | ",
        lpad(get_number(get_bus(generator)), 3), " | ",
        lpad(round(limits.min; digits = 4), 8), " | ",
        lpad(round(limits.max; digits = 4), 8), " | ",
        round(Float64(getproperty(generator, :active_power)); digits = 4),
    )
end

println("\n[风电边界；rating 同时显示 pu 和 MW]")
println("  name                 | bus | active_pu | rating_pu | rating_MW")
for generator in wind_generators
    rating_pu = Float64(get_rating(generator))
    println(
        "  ", rpad(get_name(generator), 20), " | ",
        lpad(get_number(get_bus(generator)), 3), " | ",
        lpad(round(Float64(getproperty(generator, :active_power)); digits = 5), 9), " | ",
        lpad(round(rating_pu; digits = 5), 9), " | ",
        round(rating_pu * system_base; digits = 3),
    )
end

println("\n[线路边界；rating 同时显示 pu 和 MW]")
println("  name                         | from -> to | x_pu  | rating_pu | rating_MW")
for branch in branches
    arc = get_arc(branch)
    rating_pu = Float64(get_rating(branch))
    println(
        "  ",
        rpad(get_name(branch), 28), " | ",
        lpad(get_number(get_from(arc)), 3), " -> ", lpad(get_number(get_to(arc)), 3), " | ",
        lpad(round(Float64(get_x(branch)); digits = 5), 5), " | ",
        lpad(round(rating_pu; digits = 4), 9), " | ",
        round(rating_pu * system_base; digits = 3),
    )
end

println("\n[负荷边界]")
println("  name                 | bus | max_active_power_pu")
for power_load in power_loads
    println(
        "  ",
        rpad(get_name(power_load), 20), " | ",
        lpad(get_number(get_bus(power_load)), 3), " | ",
        round(Float64(get_max_active_power(power_load)); digits = 5),
    )
end

print_section("3. 频率参数配置")

# 先生成完整参数字典，再用同一组物理上可解释的参数覆盖本算例中的所有常规机组。
# 这样示例不会依赖 MATPOWER 文件是否带有完整 fuel 字段，也避免 K/R 为零造成无调速响应。
frequency_overrides = Dict{String, NamedTuple}(
    get_name(generator) => (H = 5.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05)
    for generator in thermal_generators
)
thermal_frequency_parameters = generate_frequency_parameters(sys; overrides = frequency_overrides)

# 风电采用独立于热机组的六个字段：
# Fcmode=1 开启虚拟惯量/阻尼模式；Kw/Rw 是一次调频增益/下垂；
# Mw/Dw/Tw 分别表示等效惯量、阻尼和响应时间常数。
wind_frequency_parameters = Dict{String, NamedTuple}(
    WIND_NAME => (Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0),
)
frequency_parameters = merge(thermal_frequency_parameters, wind_frequency_parameters)

println("frequency fields: H(s), D, K, F, T(s), R")
println("  name                 | H     | D     | K     | F     | T     | R")
for generator in thermal_generators
    parameter = frequency_parameters[get_name(generator)]
    println(
        "  ", rpad(get_name(generator), 20), " | ",
        join(round.((parameter.H, parameter.D, parameter.K, parameter.F, parameter.T, parameter.R); digits = 4), " | "),
    )
end

println("\n[风电调频参数；Fcmode/Kw/Rw/Mw/Dw/Tw]")
println("  name                 | Fcmode | Kw    | Rw    | Mw    | Dw    | Tw")
for generator in wind_generators
    parameter = frequency_parameters[get_name(generator)]
    println(
        "  ", rpad(get_name(generator), 20), " | ",
        join(round.((parameter.Fcmode, parameter.Kw, parameter.Rw, parameter.Mw, parameter.Dw, parameter.Tw); digits = 4), " | "),
    )
end

print_section("4. 数据中心挂载")

# 数据中心的 bus 使用 PowerSystems 的原始母线编号，而不是内部连续索引。
# p_max、p_min、idle_power、server_energy 的功率量按 MW 填写；桥接层会转换为 pu。
# workload 是相对工作量，模型内部会按数据中心响应模型进行归一化。
const DATA_CENTER_BUS = 5
data_centers = [(
    bus = DATA_CENTER_BUS,
    p_max = 20.0,
    p_min = 0.0,
    idle_power = 1.0,
    server_energy = 0.05,
    lambda = 1.0,
    mu = 1.0,
    workload = fill(0.10, HORIZON),
)]

println("data center count : ", length(data_centers))
for (index, center) in enumerate(data_centers)
    println("  center[$index]")
    println("    bus             : ", center.bus)
    println("    p_min / p_max   : ", center.p_min, " / ", center.p_max, " MW")
    println("    idle_power      : ", center.idle_power, " MW")
    println("    server_energy   : ", center.server_energy)
    println("    lambda / mu     : ", center.lambda, " / ", center.mu)
    println("    workload length : ", length(center.workload))
end

# calibration 会被统一接口临时转换为环境变量，只对本次 solve 生效。
# 两个关键开关必须显式为 true，否则数据虽已挂载，模型仍会跳过对应约束。
const CALIBRATION = (
    MODEL_CONSIDER_FREQUENCY_CONTROL = true,
    MODEL_CONSIDER_DATA_CENTER = true,
    MODEL_CONSIDER_BESS = false,
    # 演示用事故容量按最大机组容量的 5% 标定；正式研究请按实际 N-1 事故设置。
    FREQUENCY_CONTINGENCY_FRACTION = 0.05,
    MODEL_MAX_ITERATIONS_NUM = 5,
    CCG_INITIAL_SCENARIOS = 1,
    CCG_SCENARIOS_PER_ITERATION = 1,
    CCG_MAX_ITERATIONS = 3,
    BENDERS_MAX_ITERATIONS = 3,
    BENDERS_PARALLEL_SUBPROBLEMS = false,
)

# 为了在求解前打印“有效 config”，这里使用和 solve_uc 相同的 calibration
# 临时加载一份数据。这样看到的 config 与实际优化使用的 config 完全一致。
function calibration_env_pairs(calibration)
    return [
        uppercase(string(key)) => (value isa Bool ? (value ? "1" : "0") : string(value))
        for (key, value) in pairs(calibration)
    ]
end

request = UCSolveRequest(
    algorithm = ALGORITHM,
    input = :powersystems,
    sys = sys,
    scenario_limit = SCENARIO_LIMIT,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = HORIZON,
    calibration = CALIBRATION,
    output_dir = joinpath(PROJECT_ROOT, "output", "examples", "powersystems", "ieee30", String(ALGORITHM)),
    # 先静默求解，再由本示例统一打印分层输入和结果，避免底层日志穿插其中。
    verbosity = :silent,
)

data = withenv(calibration_env_pairs(CALIBRATION)...) do
    load_uc_data(request.input)
end

print_section("5. 统一 UC 数据和有效配置")
println("NB / NG / NL / ND / NT : ", data.NB, " / ", data.NG, " / ", data.NL, " / ", data.ND, " / ", data.NT)
println("ND2 / NW / NS          : ", data.ND2, " / ", data.NW, " / ", data.NS)
println("full scenario prob.    : ", data.full_scenario_probability)
println("data-center p_max      : ", data.DataCentras.p_max, " pu")
println("data-center workload   : ", data.DataCentras.computational_power_tasks)
println("wind capacity          : ", data.winds.p_max, " pu")
println("wind availability      : ", data.winds.scenarios_curve)
println("wind Fcmode/Kw/Rw      : ", data.winds.Fcmode, " / ", data.winds.Kw, " / ", data.winds.Rw)
println("wind Mw/Dw/Tw           : ", data.winds.Mw, " / ", data.winds.Dw, " / ", data.winds.Tw)

println("\n[Effective model config]")
for field in fieldnames(typeof(data.config_param))
    println("  ", rpad(string(field), 34), " = ", getfield(data.config_param, field))
end

if RUN_SOLVE
    print_section("6. 开始统一 UC 求解")
    println("algorithm: ", request.algorithm)
    println("output_dir: ", request.output_dir)
    println("frequency control: enabled")
    println("data center model: enabled")

    # 求解器内部会根据 request.algorithm 自动路由到 benchmark、Benders 或 CCG。
    # 调用方不需要再手动 include 或拼接算法专用的位置元组。
    result = solve_uc(request)

    # detail=true 会输出状态、上下界、gap、模型规模、迭代历史、成本分解和诊断信息。
    print_uc_result(result; detail = true)
else
    println("\nUC_RUN_SOLVE=0: 已完成算例构造和数据桥接，未启动优化。")
end
