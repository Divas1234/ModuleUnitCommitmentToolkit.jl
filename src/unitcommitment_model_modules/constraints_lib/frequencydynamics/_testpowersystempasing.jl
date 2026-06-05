include("_automatic_workflow.jl")

using PowerSystems
using PowerSystemCaseBuilder
const PSY = PowerSystems

# 1. 构造一个包含动态数据的 14 节点测试系统 (IEEE 14-bus)
# 该系统包含 Generator, Shaft (惯性), 和 TurbineGovernor (调差)
sys = build_system(PSIDSystems, "PSID_14bus_system")

println("--- 提取系统调频数据 (Frequency Response Parameters) ---")

# 获取所有动态发电机
dynamic_generators = get_components(DynamicGenerator, sys)

for gen in dynamic_generators
    name = get_name(gen)

    # --- 1. 惯性 (Inertia H) ---
    # 对应您代码中的 initial_inertia
    shaft = get_shaft(gen)
    H = get_H(shaft)
    D = get_D(shaft) # 阻尼系数 (Damping)

    # --- 2. 调速器与调差率 (Governor & Droop R) ---
    # 对应您代码中的 droop = 1 / 0.030
    tg = get_prime_mover(gen)

    # 不同的调速器模型（如 HydroTurbineGov, Gasturbine）字段名略有不同
    # 通常 R 代表调差率
    R = hasfield(typeof(tg), :R) ? get_R(tg) : "N/A"

    # --- 3. 时间常数 (Time Constant) ---
    # 对应您代码中的 time_content，通常指 T1 或 Tg
    T_g = hasfield(typeof(tg), :T1) ? get_T1(tg) : "N/A"

    println("机组名称: $name")
    println("  >> 惯性 H: $(round(H, digits=2)) s")
    println("  >> 阻尼 D: $(round(D, digits=2))")
    println("  >> 调差率 R: $R")
    println("  >> 时间常数 Tg: $T_g")
    println("-"^40)
end

using PowerSimulationsDynamics
const PSID = PowerSimulationsDynamics

# 1. 定义扰动 (例如在 1.0s 时切除一台发电机)
perturbation = GeneratorTrip(1.0, "generator_name")

# 2. 构建仿真
sim = Simulation!(
    ResidualModel,
    sys,
    pwd(),
    (0.0, 10.0), # 仿真时间 10 秒
    perturbation
)

# 3. 执行并绘制频率曲线
execute!(sim, IDA())
results = read_results(sim)
# plot(results, "freq")