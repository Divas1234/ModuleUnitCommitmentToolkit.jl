# # 动态仿真：IEEE 118节点系统的频率响应分析
#
# 本脚本旨在利用 Julia 对 IEEE 118 节点系统进行一次简化的动态仿真，
# 核心是观察在发生扰动（如发电机脱网）后，系统的频率如何变化。
#
# **重要说明**:
# 这是一个教学目的的简化模型。一个精确的动态仿真需要：
# 1. 更详细的设备模型（如励磁、调速器、PSS等）。
# 2. 求解完整的微分代数方程组（DAE），其中代数方程部分是电网的潮流方程。
#
# 为了简化，本脚本做出了以下假设：
# - 发电机采用经典的二阶摇摆方程模型。
# - 忽略了网络的代数方程，将发电机的电气功率 `Pe` 视为一个在扰动时变化的参数，
#   而不是根据网络状态实时计算。这使得我们可以用常微分方程（ODE）求解器代替更复杂的DAE求解器。
# - 动态参数（如转动惯量 `M` 和阻尼 `D`）为假设值。

# --- 1. 导入必要的 Julia 包 ---
# 如果您尚未安装这些包，请在 Julia REPL 中运行:
# using Pkg
# Pkg.add("PowerModels")
# Pkg.add("DifferentialEquations")
# Pkg.add("Plots")

using PowerModels
using DifferentialEquations
using Plots

println("Julia 包加载完毕。")

# --- 2. 加载电网数据 ---
# PowerModels.jl 可以解析多种数据格式，包括 MATPOWER (.m)。
# 我们将使用 `psatconverter` 文件夹下的 `case118.m` 文件。
file_path = "psatconverter/case118.m"

if !isfile(file_path)
    error("错误：找不到电网数据文件，请确认路径 '$(file_path)' 是否正确。")
end

network_data = PowerModels.parse_file(file_path)
println("IEEE 118 节点系统数据加载成功。")

# --- 3. 初始化动态模型参数 ---
# 获取发电机数量
num_gens = length(network_data["gen"])
println("找到 $(num_gens) 台发电机。")

# 假设所有发电机的动态参数。在实际研究中，这些参数需要从数据库中获取。
M = [10.0 for _ in 1:num_gens]  # 转动惯量 (s^2/rad)
D = [0.1 for _ in 1:num_gens]   # 阻尼系数 (pu/pu)

# 假设发电机的机械功率 `Pm` 等于其在扰动前的有功出力。
# 我们从数据文件中读取每个发电机的有功功率设定值 `pg`。
Pm = [gen["pg"] for (_, gen) in network_data["gen"]]

# 定义初始状态。假设系统在仿真开始时处于稳定状态。
# δ₀: 发电机转子初始相角 (rad)。为简化，设为0。
# ω₀: 发电机转子初始角速度偏差 (pu)。稳定时为0。
u₀ = vcat(zeros(num_gens), zeros(num_gens)) # [δ₁, ..., δₙ, ω₁, ..., ωₙ]

println("动态模型参数初始化完成，共 $(num_gens) 台发电机。")

# --- 4. 定义系统的动态行为（摇摆方程） ---
# swing_equation! 函数描述了系统的动态演化过程。
# du: 状态量的导数 [dδ/dt, dω/dt]
# u:  当前状态量 [δ, ω]
# p:  模型参数 [M, D, Pm]
# t:  当前时间 (s)
function swing_equation!(du, u, p, t)
    # 解构参数和状态变量
    M, D, Pm = p
    δ = u[1:num_gens]
    ω = u[(num_gens + 1):end]

    # --- 模拟扰动 ---
    # 假设扰动前，电磁功率 `Pe` 等于机械功率 `Pm`。
    Pe = copy(Pm)

    # **扰动定义**: 在 t = 1.0 秒时，1号发电机因故障脱网。
    # 我们通过将其电磁功率输出 `Pe` 设为 0 来模拟这一事件。
    if t >= 1.0
        Pe[1] = 0.0
        if t == 1.0
            println("t=1.0s: 扰动发生，1号发电机脱网。")
        end
    end

    # --- 计算状态导数 ---
    # 摇摆方程: M * dω/dt = Pm - Pe - D*ω
    dδ_dt = ω .* (2 * π * network_data["baseMVA"]) # 转换为合适的单位
    dω_dt = (1 ./ M) .* (Pm - Pe - D .* ω)

    # 更新导数向量
    du[1:num_gens] = dδ_dt
    return du[(num_gens + 1):end] = dω_dt
end

# --- 5. 运行仿真 ---
t_span = (0.0, 15.0)  # 定义仿真时间范围 (0 到 15 秒)
params = (M, D, Pm)   # 将模型参数打包

# 创建并求解 ODE 问题
# 我们将摇摆方程、初始状态、时间范围和参数传递给求解器。
prob = ODEProblem(swing_equation!, u₀, t_span, params)
println("正在求解微分方程，仿真时间为 $(t_span[2]) 秒...")
sol = solve(prob, Rodas5(), progress = true, progress_steps = 1) # Rodas5 是一个适合刚性问题的求解器
println("仿真完成。")

# --- 6. 结果可视化 ---
# 从仿真结果 `sol` 中提取时间和频率数据。
# 频率偏差 (pu) 等于转子角速度偏差 (pu)。
time_steps = sol.t
freq_deviation = sol[(num_gens + 1):end, :]' # 转置以匹配绘图库的格式

# 绘制所有发电机频率偏差的曲线图
plot(
    time_steps,
    freq_deviation,
    xlabel = "时间 (s)",
    ylabel = "频率偏差 (pu)",
    title = "IEEE 118 系统在1号发电机脱网后的频率响应",
    label = permutedims("Gen " .* string.(1:num_gens)), # 为每条线添加标签
    legend = :outertopright,
    linewidth = 1.5,
)

# 保存图像到文件
savefig("ieee118_frequency_response.png")
println("仿真结果图已保存为 'ieee118_frequency_response.png'。")
println("脚本执行完毕。")
