# ============================================================================
# PowerSystems.jl 算例桥接与数据中心挂载使用示例
#
# 本脚本展示了如何：
# 1. 引入必要环境配置和优化求解模块
# 2. 从 PowerSystems.jl (Sienna 平台) 直接载入原生算例 (例如 c_sys5 5节点系统)
# 3. 在算例网架上动态挂载灵活数据中心 (Data Center) 负荷
# 4. 自动匹配和注入发电机的配套动态频率响应参数 (Hg, Dg 等)
# 5. 自动检测有名值/标幺值系统，对有功功率和线路参数进行合理转换与缩放
# 6. 生成风电随机场景，并调用 Gurobi 求解随机单位承诺 (SUC) 优化模型
# ============================================================================

# ============================================================================
# 步骤 1: 载入项目环境与所有依赖模块
# ============================================================================
println("正在加载项目依赖和模块...")

# 引入全局环境配置文件，将自动激活 ./pkg 运行环境并校验 Gurobi/JuMP/Plots 等包
include("../src/environment_config.jl")

# 引入风电/新能源场景模拟模块 (Weibull 分布场景生成)
include("../src/renewableresource_modules/stochasticsimulation.jl")

# 引入数据读取与桥接模块 (包含我们新增的 powersystems_bridge.jl 接口)
include("../src/read_inputdata_modules/readdatas.jl")

# 引入随机单位承诺 (SUC) 主优化模型
include("../src/unitcommitment_model_modules/SUCuccommitmentmodel.jl")

using PowerSystems
using PowerSystemCaseBuilder

# ============================================================================
# 步骤 2: 调用 PowerSystems.jl 原生接口加载电网数据
# ============================================================================
# case_name 可以是 PowerSystemCaseBuilder 支持的测试系统名称 (如 "c_sys5", "c_sys14" 等)
# 或者是本地的 MATPOWER (.m) 格式的网架文件路径。
case_name = "c_sys5" 
println("\n>>> [Sienna] 载入原生测试算例: $case_name")
sys = build_system_from_powersystems(case_name)

# ============================================================================
# 步骤 3: 确定数据中心 (Data Center) 的挂载位置与有功限额
# ============================================================================
# 在此处指定挂载数据中心的电网总线上。对于 c_sys5 系统，节点编号为 1 至 5。
# 例如：我们在 Bus 3 上挂载容量为 50 MW 的数据中心，在 Bus 4 上挂载容量为 30 MW 的数据中心。
# 由于 c_sys5 算例内部已转换为标幺值 (System Base = 100 MVA)，
# 50 MW 对应 0.5 p.u.，30 MW 对应 0.3 p.u.。
dc_buses = [3, 4]      # 挂载数据中心的节点 index
dc_pmax = [0.5, 0.3]   # 数据中心最大用电容量 (p.u.)

# ============================================================================
# 步骤 4: 配套频率参数的获取与覆盖
# ============================================================================
# 发电机配套的频率响应参数 (惯性常数 Hg, 阻尼系数 Dg, 调速器增益 Kg 等)
# 默认情况下，我们可以读取项目自带 excel (data/data.xlsx) 中存储的模板频率参数作为覆盖源。
println("\n>>> 正在加载配套频率控制参数模板...")
excel_units_freq, _, _, _, _, _, _, _, _, _, _ = readxlssheet()

# ============================================================================
# 步骤 5: 执行 Sienna 算例向 UC 模型的桥接转换
# ============================================================================
# extract_uc_data_from_powersystems 会做以下几件关键事情：
# 1. 扫描电网中的所有发电机、传输线、静态负荷、储能和水电组件。
# 2. 自动检测系统是采用标幺值 (p.u.) 还是有名值 (MW)。若是有名值，自动除以 100 转换。
# 3. 将电网物理连接关系映射为紧凑的 contiguous 拓扑矩阵。
# 4. 将频率模板参数按顺序注入至常规发电机中。
# 5. 在指定的节点上挂载数据中心，自动填充 idle 功耗、调节裕度、以及任务曲线等默认数据。
println("\n>>> 正在执行算例映射与转换...")
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH, DataCentras, hydros, WindsFreqParam_extracted, bus_to_idx = 
    extract_uc_data_from_powersystems(
        sys,
        data_center_buses = dc_buses,
        data_center_pmax = dc_pmax,
        frequency_params_override = excel_units_freq
    )

# 确保在优化配置中开启数据中心约束和频率控制约束的计算
config_param.is_ConsiderDataCentra = 1
config_param.is_ConsiderFrequencyControl = 1

# 打印提取出来的系统信息进行校验
println("\n------------------------------------------------")
println("算例提取校验数据：")
println(" - 电网总线数 (NB): $NB")
println(" - 常规发电机数 (NG): $NG")
println(" - 传输线路数 (NL): $NL")
println(" - 基础负荷数 (ND): $ND")
println(" - 挂载数据中心数 (ND2): $ND2")
println(" - 储能电池组数 (NC): $NC")
println(" - 水电站单元数 (NH): $NH")
println(" - 调度时段总长 (NT): $NT 小时")
println("------------------------------------------------")

# ============================================================================
# 步骤 6: 生成风电随机场景并求解 Stochastic Unit Commitment (SUC)
# ============================================================================
println("\n>>> 正在生成风电出力场景曲线...")
# 传入提取出来的风机频率及容量参数，采用随机 Weibull 扰动模式 (flag=1) 生成场景
winds, NW = generate_wind_scenarios_from_system(sys, WindsFreqParam_extracted, 1, NT, bus_to_idx = bus_to_idx)

# 计算每个随机场景的等概概率 (1/N)
scenarios_prob = 1.0 / winds.scenarios_nums

println("\n>>> 正在构建 JuMP 模型并调用 Gurobi 求解随机单位承诺...")
# 调用 SUC 核心求解函数，内部包含：
# - 最小上下限时间约束，网络安全潮流约束，频率 Nadir 约束，储能与数据中心调节约束。
results = SUC_scucmodel(
    NT, NB, NG, ND, NC, ND2,
    units, loads, winds, lines, DataCentras, config_param, stroges,
    scenarios_prob, NL, hydros, NH
)

# ============================================================================
# 步骤 7: 校验求解状态并导出调度结果
# ============================================================================
if results !== nothing
    println("\n>>> 求解成功！Gurobi 已输出最优调度方案。")
    
    # 保存包含系统功率平衡平衡、发电机出力、数据中心负荷调节在内的明细结果
    save_powerbalance_scheduled_results(units, winds, config_param, results)
    
    println(">>> 调度明细结果已输出至 `output/details_schedule_results/` 目录下。")
    println("======================================================================")
else
    println("\n>>> [错误] 求解失败，模型可能是无解的 (Infeasible)，请检查数据输入。")
    exit(1)
end
