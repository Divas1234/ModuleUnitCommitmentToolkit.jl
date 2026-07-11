# PowerSystems.jl 算例集成与数据中心挂载使用指南

本指南详细介绍了如何使用本项目中新增的 `PowerSystems.jl` 算例桥接接口。该接口支持直接加载 native 算例，配套注入频率参数，并在指定节点上动态挂载灵活数据中心（Data Center）负荷进行 Stochastic Unit Commitment (SUC) 求解。

---

## 核心接口说明

### 1. 载入算例：`build_system_from_powersystems`
- **签名**：`build_system_from_powersystems(case_name::String) -> System`
- **作用**：
  - 支持直接指定 NREL/Sienna 算例名（如 `"c_sys5"`、`"c_sys14"` 等），包管理器会自动从云端拉取并缓存对应的数据集。
  - 支持传入本地磁盘上的 `.m`（MATPOWER）格式或 `.raw`（PSS/E）格式的数据文件路径。
- **示例**：
  ```julia
  sys = build_system_from_powersystems("c_sys5")
  ```

### 2. 映射转换与负荷挂载：`extract_uc_data_from_powersystems`
- **签名**：
  ```julia
  extract_uc_data_from_powersystems(
      sys::System;
      data_center_buses::Vector{Int} = Int[],
      data_center_pmax::Vector{Float64} = Float64[],
      frequency_params_override = nothing
  )
  ```
- **参数说明**：
  - `sys`: 上一步载入的 `PowerSystems.System` 实体。
  - `data_center_buses`: 发电网架中拟挂载数据中心的节点编号列表（如 `[3, 4]`）。
  - `data_center_pmax`: 对应总线上数据中心的最大容量额度。
  - `frequency_params_override`: 从 Excel 读取的发电机频率参数矩阵。若省略，将采用典型的发电机动态响应默认值。
- **核心机制**：
  - **有名值/标幺值自适应缩放**：自动检查 Sienna 网架最大的发电机有功限额。若低于 `50.0`，判定系统已完成标幺化（p.u.，如 `c_sys5` 为 100 MVA Base 标幺值），直接提取；否则自动除以 `100.0` 进行归一化。
  - **拓扑节点重整**：将 Sienna 的 `Bus` 对象和编号重整映射为 `1` 到 `NB` 的连续自然数索引，以满足后续潮流和 Gsdf 分布系数矩阵的维度一致性。
  - **频率响应参数注入**：在常规发电机中注入惯性常数（`Hg`）与阻尼系数（`Dg`）等控制参数，满足 Nadir 约束的要求。

---

## 使用示例运行说明

项目提供了一个完整的明细注释脚本样例：
[docs/powersystems_example.jl](file:///Users/yuanyiping/Documents/GitHub/02%20Ongoing/module_unitcommitment/docs/powersystems_example.jl)

### 运行方式
在项目目录下启动 Julia REPL，激活对应的 `pkg` 环境并执行此样例：
```bash
julia --project=pkg docs/powersystems_example.jl
```

### 预期输出
程序将输出如下步骤：
1. **第一步**：加载 Julia 环境及编译所有涉及的 JuMP 与 Gurobi 等优化依赖。
2. **第二步**：从 `CaseData` 缓存中提取 Sienna 的原生 `c_sys5` 电网。
3. **第三步**：将节点映射为 `1:5` 的索引，并在 Bus 3 和 Bus 4 上挂载数据中心负荷。
4. **第四步**：注入对应的发电机动态频率响应参数（Hg=8.0 等）。
5. **第五步**：构建单位承诺 MILP 模型，展示 13 类电网和电源约束的生成进度。
6. **第六步**：调用 Gurobi 商业求解器，在几毫秒内解出最优发电机开关、有功出力、备用容量及数据中心任务负荷分配曲线。
7. **第七步**：将明细调度 CSV 表保存至 `output/details_schedule_results/`。
