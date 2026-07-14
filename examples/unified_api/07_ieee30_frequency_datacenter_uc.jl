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

输入核对：

- 所有输入边界和桥接后的有效配置都会先转换为 `DataFrame`；
- DataFrame 会在终端以表格形式打印，并在求解开始前写入本次运行目录的 `input/` 子目录；
- 输入快照和算法结果分目录保存，便于复现实验和逐项核对。

运行方式：

```bash
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

可选环境变量：

- `UC_ALGORITHM=benchmark|benders|ccg`，默认 `benchmark`；
- `UC_HORIZON=4`，适合快速 smoke test；默认 `24`；
- `UC_SCENARIO_LIMIT=1`，默认 `1`；
- `UC_RUN_SOLVE=0`，只做系统构造和数据桥接，不启动优化；
- `UC_FREQUENCY_CONTINGENCY_FRACTION=0.05`，调频故障扰动占参考容量的比例；
- `UC_WIND_PENETRATION=0.05`，风电装机容量占常规机组 rating 的比例；

说明：

- PowerSystems 原生组件已经处于系统基准标幺体系；
- 本示例把按 5% 渗透率计算的风电以 `RenewableDispatch` 接入 5 号母线，并通过同一个
  `frequency_parameters` 字典配置风电 `Fcmode/Kw/Rw/Mw/Dw/Tw`；
- `data_centers` 中的功率参数使用 MW，桥接层负责转换为内部标幺值；
- 频率控制和数据中心约束通过 `calibration` 显式打开；
- 示例使用 `verbosity=:silent`，先由程序自己打印输入边界，再统一打印 `UCSolveResult`，
  避免底层算法日志打断业务层报告。
"""

using Pkg
using Dates

# 无论从仓库根目录还是从 examples 目录启动，都把项目根目录作为活动环境。
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems
using DataFrames
using CSV

"""把环境变量转换成正整数，并在入口处尽早给出清晰错误。"""
function positive_int_env(name::AbstractString, default::Int)
    value = tryparse(Int, get(ENV, name, string(default)))
    value === nothing || value > 0 || throw(ArgumentError("$name must be a positive integer"))
    return value
end

"""把环境变量转换成指定范围内的比例参数。"""
function bounded_float_env(name::AbstractString, default::Float64, lower::Float64, upper::Float64)
    value = tryparse(Float64, get(ENV, name, string(default)))
    value === nothing && throw(ArgumentError("$name must be a floating-point number"))
    lower <= value <= upper || throw(ArgumentError("$name must be in [$lower, $upper]"))
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

"""将输入表格同时打印到终端并保存为本次运行的 CSV 快照。"""
function show_and_write_dataframe(df::DataFrame, name::AbstractString, input_dir::AbstractString)
    csv_path = joinpath(input_dir, string(name, ".csv"))
    CSV.write(csv_path, df)
    println("\n[", name, "]")
    show(stdout, MIME("text/plain"), df; allrows = true, allcols = true)
    println()
    println("saved_csv       : ", csv_path)
    return csv_path
end

const CASE_NAME = :ieee30
const ALGORITHM = Symbol(lowercase(get(ENV, "UC_ALGORITHM", "benchmark")))
const HORIZON = positive_int_env("UC_HORIZON", 24)
const SCENARIO_LIMIT = positive_int_env("UC_SCENARIO_LIMIT", 1)
const RUN_SOLVE = bool_env("UC_RUN_SOLVE", true)
const FREQUENCY_CONTINGENCY_FRACTION = bounded_float_env(
    "UC_FREQUENCY_CONTINGENCY_FRACTION", 0.05, 0.0, 1.0,
)
const WIND_PENETRATION = bounded_float_env("UC_WIND_PENETRATION", 0.05, 0.0, 1.0)
const OUTPUT_BASE_DIR = joinpath(
    PROJECT_ROOT, "output", "examples", "powersystems", "ieee30", String(ALGORITHM),
)
const RUN_ID = Dates.format(now(), "yyyymmdd_HHMMSS")
const RUN_OUTPUT_DIR = joinpath(OUTPUT_BASE_DIR, RUN_ID)
const INPUT_OUTPUT_DIR = joinpath(RUN_OUTPUT_DIR, "input")
mkpath(INPUT_OUTPUT_DIR)

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
println("frequency fault  : ", FREQUENCY_CONTINGENCY_FRACTION, " of reference capacity")
println("wind penetration : ", WIND_PENETRATION, " of thermal ratings")
println("input snapshot   : ", INPUT_OUTPUT_DIR)

# 这里不直接调用 PowerSystemCaseBuilder.build_system，而是使用工具包统一入口。
# 统一入口负责解析算例别名、屏蔽底层 rating 诊断日志，并返回原生 System 对象。
sys = build_system_from_powersystems(CASE_NAME)
system_base = Float64(get_base_power(sys))

buses = sort(collect(get_components(ACBus, sys)), by = get_number)
thermal_generators = sort(collect(get_components(ThermalStandard, sys)), by = get_name)
thermal_capacity_pu = sum(Float64(get_rating(generator)) for generator in thermal_generators)
wind_rating_pu = thermal_capacity_pu * WIND_PENETRATION
wind_initial_pu = wind_rating_pu * 0.40

# 在原生 PowerSystems 系统上追加一个可弃风的风电机组。
# `RenewableDispatch` 表示该机组允许在 UC 中被削减。这个 MATPOWER 系统的原生
# 组件读取结果已经是 SYSTEM_BASE pu，因此新增组件也使用 pu。风电装机容量由
# `UC_WIND_PENETRATION` 按常规机组总 rating 计算，初始出力取装机容量的 40%。
const WIND_NAME = "IEEE30 Wind Farm"
const WIND_BUS = 5
wind_bus = only(filter(bus -> get_number(bus) == WIND_BUS, collect(get_components(ACBus, sys))))
wind_generator = RenewableDispatch(;
    name = WIND_NAME,
    available = true,
    bus = wind_bus,
    active_power = wind_initial_pu,
    reactive_power = 0.0,
    rating = wind_rating_pu,
    prime_mover_type = PrimeMovers.WT,
    reactive_power_limits = nothing,
    power_factor = 1.0,
    operation_cost = RenewableGenerationCost(nothing),
    base_power = system_base,
)
add_component!(sys, wind_generator)

wind_generators = sort(collect(get_components(RenewableGen, sys)), by = get_name)
branches = sort(collect(get_components(ACBranch, sys)), by = get_name)
power_loads = sort(collect(get_components(PowerLoad, sys)), by = get_name)

print_section("2. PowerSystems 系统边界")
println("system base power: ", system_base, " MVA")
println("buses            : ", length(buses))
println("thermal units    : ", length(thermal_generators))
println("thermal capacity : ", thermal_capacity_pu, " pu / ", thermal_capacity_pu * system_base, " MW")
println("wind units       : ", length(wind_generators))
println("AC branches      : ", length(branches))
println("power loads      : ", length(power_loads))

bus_df = DataFrame(
    number = [get_number(bus) for bus in buses],
    name = [get_name(bus) for bus in buses],
    type = [string(get_bustype(bus)) for bus in buses],
    base_voltage_kV = [Float64(get_base_voltage(bus)) for bus in buses],
)
show_and_write_dataframe(bus_df, "01_buses", INPUT_OUTPUT_DIR)

# 同时保存 PowerSystems 的原始 pmax 和桥接层最终采用的 UC pmax。
# 若原生 active_power_limits.max 为零，UC pmax 会回退到正的 generator rating；
# 这两个字段并列展示，方便核对“数据源值”和“模型有效值”是否一致。
thermal_boundary_df = DataFrame(
    name = String[],
    bus = Int[],
    p_min_pu = Float64[],
    source_p_max_pu = Float64[],
    uc_p_max_pu = Float64[],
    rating_pu = Float64[],
    initial_pu = Float64[],
)
for generator in thermal_generators
    limits = get_active_power_limits(generator)
    source_p_max = Float64(limits.max)
    rating_pu = max(Float64(get_rating(generator)), 0.0)
    uc_p_max = source_p_max > 0.0 ? source_p_max : rating_pu
    push!(thermal_boundary_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        Float64(limits.min),
        source_p_max,
        uc_p_max,
        rating_pu,
        Float64(getproperty(generator, :active_power)),
    ))
end
show_and_write_dataframe(thermal_boundary_df, "02_thermal_generators", INPUT_OUTPUT_DIR)

wind_boundary_df = DataFrame(
    name = [get_name(generator) for generator in wind_generators],
    bus = [get_number(get_bus(generator)) for generator in wind_generators],
    active_power_pu = [Float64(getproperty(generator, :active_power)) for generator in wind_generators],
    rating_pu = [Float64(get_rating(generator)) for generator in wind_generators],
    rating_MW = [Float64(get_rating(generator)) * system_base for generator in wind_generators],
    penetration = fill(WIND_PENETRATION, length(wind_generators)),
)
show_and_write_dataframe(wind_boundary_df, "03_wind_generators", INPUT_OUTPUT_DIR)

branch_df = DataFrame(
    name = String[],
    from_bus = Int[],
    to_bus = Int[],
    x_pu = Float64[],
    rating_pu = Float64[],
    rating_MW = Float64[],
)
for branch in branches
    arc = get_arc(branch)
    rating_pu = Float64(get_rating(branch))
    push!(branch_df, (
        get_name(branch),
        get_number(get_from(arc)),
        get_number(get_to(arc)),
        Float64(get_x(branch)),
        rating_pu,
        rating_pu * system_base,
    ))
end
show_and_write_dataframe(branch_df, "04_branches", INPUT_OUTPUT_DIR)

load_df = DataFrame(
    name = [get_name(power_load) for power_load in power_loads],
    bus = [get_number(get_bus(power_load)) for power_load in power_loads],
    max_active_power_pu = [Float64(get_max_active_power(power_load)) for power_load in power_loads],
    max_active_power_MW = [Float64(get_max_active_power(power_load)) * system_base for power_load in power_loads],
)
show_and_write_dataframe(load_df, "05_loads", INPUT_OUTPUT_DIR)

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

thermal_frequency_df = DataFrame(
    name = String[],
    bus = Int[],
    H_s = Float64[],
    D = Float64[],
    K = Float64[],
    F = Float64[],
    T_s = Float64[],
    R = Float64[],
)
for generator in thermal_generators
    parameter = frequency_parameters[get_name(generator)]
    push!(thermal_frequency_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        parameter.H,
        parameter.D,
        parameter.K,
        parameter.F,
        parameter.T,
        parameter.R,
    ))
end
show_and_write_dataframe(thermal_frequency_df, "06_thermal_frequency_parameters", INPUT_OUTPUT_DIR)

wind_frequency_df = DataFrame(
    name = String[],
    bus = Int[],
    Fcmode = Float64[],
    Kw = Float64[],
    Rw = Float64[],
    Mw = Float64[],
    Dw = Float64[],
    Tw_s = Float64[],
)
for generator in wind_generators
    parameter = frequency_parameters[get_name(generator)]
    push!(wind_frequency_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        parameter.Fcmode,
        parameter.Kw,
        parameter.Rw,
        parameter.Mw,
        parameter.Dw,
        parameter.Tw,
    ))
end
show_and_write_dataframe(wind_frequency_df, "07_wind_frequency_parameters", INPUT_OUTPUT_DIR)

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
data_center_df = DataFrame(
    center_id = collect(1:length(data_centers)),
    bus = [center.bus for center in data_centers],
    p_min_MW = [center.p_min for center in data_centers],
    p_max_MW = [center.p_max for center in data_centers],
    idle_power_MW = [center.idle_power for center in data_centers],
    server_energy = [center.server_energy for center in data_centers],
    lambda = [center.lambda for center in data_centers],
    mu = [center.mu for center in data_centers],
    workload_mean = [sum(center.workload) / length(center.workload) for center in data_centers],
    workload_min = [minimum(center.workload) for center in data_centers],
    workload_max = [maximum(center.workload) for center in data_centers],
)
show_and_write_dataframe(data_center_df, "08_data_centers", INPUT_OUTPUT_DIR)

# calibration 会被统一接口临时转换为环境变量，只对本次 solve 生效。
# 两个关键开关必须显式为 true，否则数据虽已挂载，模型仍会跳过对应约束。
const CALIBRATION = (
    MODEL_CONSIDER_FREQUENCY_CONTROL = true,
    MODEL_CONSIDER_DATA_CENTER = true,
    MODEL_CONSIDER_BESS = false,
    # 演示用事故容量由入口环境变量控制；正式研究请按实际 N-1 事故设置。
    FREQUENCY_CONTINGENCY_FRACTION = FREQUENCY_CONTINGENCY_FRACTION,
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
    output_dir = RUN_OUTPUT_DIR,
    # 先静默求解，再由本示例统一打印分层输入和结果，避免底层日志穿插其中。
    verbosity = :silent,
)

data = withenv(calibration_env_pairs(CALIBRATION)...) do
    load_uc_data(request.input)
end

print_section("5. 统一 UC 数据和有效配置")
dimensions_df = DataFrame(
    parameter = [
        "system_base_MVA", "NB", "NG", "NL", "ND", "NT", "ND2", "NW", "NS",
        "thermal_capacity_pu", "wind_penetration", "frequency_contingency_fraction",
    ],
    value = Any[
        system_base, data.NB, data.NG, data.NL, data.ND, data.NT, data.ND2, data.NW, data.NS,
        thermal_capacity_pu, WIND_PENETRATION, FREQUENCY_CONTINGENCY_FRACTION,
    ],
)
show_and_write_dataframe(dimensions_df, "09_model_dimensions", INPUT_OUTPUT_DIR)

config_fields = fieldnames(typeof(data.config_param))
config_df = DataFrame(
    parameter = [string(field) for field in config_fields],
    value = Any[getfield(data.config_param, field) for field in config_fields],
)
show_and_write_dataframe(config_df, "10_effective_config", INPUT_OUTPUT_DIR)

wind_capacity_df = DataFrame(
    wind_id = collect(1:length(data.winds.p_max)),
    p_max_pu = Float64.(data.winds.p_max),
    p_max_MW = Float64.(data.winds.p_max .* system_base),
    Fcmode = Float64.(data.winds.Fcmode),
    Kw = Float64.(data.winds.Kw),
    Rw = Float64.(data.winds.Rw),
    Mw = Float64.(data.winds.Mw),
    Dw = Float64.(data.winds.Dw),
    Tw_s = Float64.(data.winds.Tw),
)
show_and_write_dataframe(wind_capacity_df, "11_unified_wind_parameters", INPUT_OUTPUT_DIR)

wind_scenario_values = vec(permutedims(data.winds.scenarios_curve))
wind_availability_df = DataFrame(
    scenario = repeat(1:data.NS, inner = data.NT),
    time = repeat(1:data.NT, data.NS),
    availability = Float64.(wind_scenario_values),
)
show_and_write_dataframe(wind_availability_df, "12_wind_availability", INPUT_OUTPUT_DIR)

println("\ninput snapshots saved before solve: ", INPUT_OUTPUT_DIR)

if RUN_SOLVE
    print_section("6. 开始统一 UC 求解")
    println("algorithm: ", request.algorithm)
    println("output_dir: ", request.output_dir)
    println("frequency control: enabled")
    println("data center model: enabled")

    # 求解器内部会根据 request.algorithm 自动路由到 benchmark、Benders 或 CCG。
    # 调用方不需要再手动 include 或拼接算法专用的位置元组。
    # 将同一个 run_id 传给求解器内部的调度导出逻辑，使 input/ 快照和
    # benchmark_uc/<run_id>/scheduling/ 使用同一时间标识，便于整组归档。
    result = withenv("MODULE_UC_RUN_ID" => RUN_ID) do
        solve_uc(request)
    end

    # detail=true 会输出状态、上下界、gap、模型规模、迭代历史、成本分解和诊断信息。
    print_uc_result(result; detail = true)
else
    println("\nUC_RUN_SOLVE=0: 已完成算例构造和数据桥接，未启动优化。")
end
