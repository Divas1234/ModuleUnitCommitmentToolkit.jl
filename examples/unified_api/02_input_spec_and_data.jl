"""
    02_input_spec_and_data.jl

演示统一数据入口的两种写法：

1. 先构造 UCInputSpec，再传给 load_uc_data；
2. 直接使用 load_uc_data(; ...) 的关键字形式。

本示例不启动优化器，只检查数据对象和关键维度，适合数据入口快速反馈。
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "2"))

# UCInputSpec 是一个稳定的输入契约。
# 它把数据源、场景数量、PowerSystems 对象、数据中心和调频参数集中在同一对象中，
# 适合在应用层先校验、记录，再传递给求解函数。
spec = UCInputSpec(
    input = :excel,
    scenario_limit = SCENARIO_LIMIT,
    horizon = 24,
)

println("Input specification:")
println("  source         = ", spec.source)
println("  scenario_limit = ", spec.scenario_limit)
println("  horizon        = ", spec.horizon)
println("  case_name      = ", spec.case_name)

# load_uc_data(spec) 返回 NamedTuple，而不是位置元组。
# 因此可以用 data.NG、data.NS 这样的字段访问，不需要记住字段顺序。
data_from_spec = redirect_stdout(devnull) do
    load_uc_data(spec)
end

println("Data loaded through UCInputSpec:")
println("  buses             = ", data_from_spec.NB)
println("  generators        = ", data_from_spec.NG)
println("  lines             = ", data_from_spec.NL)
println("  load nodes        = ", data_from_spec.ND)
println("  wind generators   = ", data_from_spec.NW)
println("  scenarios         = ", data_from_spec.NS)
println("  horizon           = ", data_from_spec.NT)
println("  scenario prob.    = ", data_from_spec.full_scenario_probability)

# 直接关键字调用适合一次性读取。
# 这里使用相同参数，结果结构应与 data_from_spec 对齐。
data_direct = redirect_stdout(devnull) do
    load_uc_data(input = :excel, scenario_limit = SCENARIO_LIMIT, horizon = 24)
end

@assert data_direct.NS == data_from_spec.NS
@assert data_direct.NT == data_from_spec.NT
println("Direct keyword data entry matches UCInputSpec data entry.")

