"""
    05_benders_named_setup.jl

Benders 有两种层次的调用方式：

* 业务层：优先使用 solve_uc(algorithm=:benders, ...)；
* 算法调试层：使用 main() 获得 BendersSetup，并访问命名字段。

本程序展示第二种方式，重点是说明如何逐步淘汰旧的 20 项位置元组。
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

# 低层 Benders 示例需要 main 和 multiple_bender_decomposition_scuc。
# 生产业务代码不应依赖这些 include，而应使用 solve_uc。
include(joinpath(PROJECT_ROOT, "tools", "benders", "setup.jl"))

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const MAX_ITERATIONS = get(ENV, "BENDERS_MAX_ITERATIONS", "5")

# main 返回 BendersSetup，不再返回匿名位置元组。
setup = main(
    input = :excel,
    scenario_limit = SCENARIO_LIMIT,
)

# 推荐：通过字段名读取结构，字段顺序改变时不会静默错位。
master_model = setup.master_model
sub_model = setup.sub_model
master_struct = setup.master_struct
batch_subproblems = setup.batch_subproblems
winds = setup.winds
config_param = setup.config_param
NG = setup.NG
NT = setup.NT
ND = setup.ND
NL = setup.NL

println("Benders setup dimensions:")
println("  NB = ", setup.NB, ", NG = ", setup.NG, ", NL = ", setup.NL)
println("  ND = ", setup.ND, ", NS = ", setup.NS, ", NT = ", setup.NT)
println("  NC = ", setup.NC, ", ND2 = ", setup.ND2)

# 只有在维护旧程序时才使用兼容迭代器。
# 它仍暴露历史的 20 项顺序，但不包括新增的 setup.data 字段。
legacy_values = collect(setup)
@assert length(legacy_values) == 20
println("legacy compatibility values = ", length(legacy_values))

# 低层 Benders 求解仍然需要按算法函数签名传入模型和维度；
# 新的命名对象解决的是 setup 数据的可读性和兼容迁移问题。
result = withenv(
    "BENDERS_MAX_ITERATIONS" => MAX_ITERATIONS,
    "BENDERS_PARALLEL_SUBPROBLEMS" => "0",
) do
    multiple_bender_decomposition_scuc(
        master_model,
        sub_model,
        master_struct,
        batch_subproblems,
        winds,
        config_param,
        NG,
        NT,
        length(winds.index),
        ND,
        NL,
    )
end

println("status      = ", result.status)
println("upper_bound = ", result.upper_bound)
println("lower_bound = ", result.lower_bound)
println("gap         = ", result.gap)
