# PCM 代码目录

```text
tools/pcm/
├── standard_pcm/             # 常规固定窗口 PCM / 单机 SCUC
│   ├── main.jl
│   └── period_scuc.jl
├── clustered_overlap_pcm/    # 单机/聚类自适应交叠窗统一实现
│   ├── core/                 # 按工业职责拆分的交叠窗核心组件
│   ├── runners/              # 可执行仿真流程
│   ├── analysis/             # 性能比较和准则评估
│   ├── data_tools/           # 离线样本与负荷数据工具
│   ├── STEADY_STATE_OVERLAP.md # 稳态交叠窗说明
│   └── paths.jl              # 项目相对路径统一定义
├── clustered_pcm/            # 同质聚类、驻留解群与网络再调度
│   ├── clustered_pcm.jl
│   ├── adapter.jl
│   ├── clustered_solver.jl
│   └── network_dispatch.jl
├── integrated_pcm/           # 完整时域 UC 参考入口
├── benchmark/                # 批量实验编排、单进程计量、双规模对比
├── config/                   # 运行配置与负荷模式
├── results/                  # 统一结果清单导出
├── rolling_pcm_driver.jl     # 固定窗 PCM 公共滚动流程
├── main.jl                   # 单次仿真的唯一入口
└── run_pcm_suite.jl          # 多方案批量实验入口
```

新增代码应放入对应方法目录，不再继续堆放到 `tools/pcm` 根目录。

固定窗方法采用策略注入：`standard_pcm/main.jl` 注入物理单机窗求解器，
`clustered_pcm/main.jl` 注入聚类主问题与物理解群求解器；两者共同调用
`rolling_pcm_driver.jl` 管理数据、滚动边界、结果累计与落盘，方法入口之间不再互相包含。

## 性能模式与并行

- `PCM_PERFORMANCE_MODE=fast|balanced`：PCM 默认使用 `fast`；一体化 UC 参考基准保持严格默认配置。
- `PCM_SOLVER_THREADS=4`：限制每个 Gurobi 模型的内部线程数。
- `PCM_BENCHMARK_MAX_PARALLEL=2`：并行运行相互独立的方法、负荷场景或重复实验。
- `PCM_MIP_GAP`、`PCM_CLUSTER_OUTPUT_BINS`：可覆盖性能模式提供的求解精度和聚类分箱默认值。
- `PCM_OVERLAP_REFERENCE_MODE=load_following|economic_solve`：fast 使用轻量参考，balanced 使用逐窗物理参考 UC。
- `PCM_CLUSTER_REFERENCE_REPAIR=true|false`：是否因成本差超限额外执行物理单机重求；物理解群可行性校核始终保留。

118 系统建议使用“2 个独立进程 × 每模型 2–4 个 Gurobi 线程”。滚动窗口存在状态依赖，不能并行求解；
并行仅用于相互独立的实验和模型内部求解，避免破坏前后窗边界条件。

## 常规固定窗口 PCM

```powershell
$env:PCM_METHOD='standard'
julia --project=. tools/pcm/main.jl
```

## 聚类 PCM

```powershell
$env:PCM_METHOD='clustered_pcm'
julia --project=. tools/pcm/main.jl
```

## 自适应交叠窗

```powershell
$env:PCM_METHOD='adaptive_overlap'
julia --project=. tools/pcm/main.jl
```

## 多方案统一基准与结果对比

使用统一输入、负荷曲线、滚动区间和独立 Julia 进程，依次运行 standard、clustered_pcm 和 adaptive_overlap，并生成逐次计量、聚合统计、相对 standard 指标及 Markdown 报告：

```powershell
$env:PCM_BENCHMARK_RUNS='3'
$env:PCM_BENCHMARK_PROFILES='baseline,smooth,extreme_ramp'
$env:PCM_OVERLAP_MODE='ml_prediction'
$env:PCM_SOLVER='gurobi'
julia --project=pkg tools/pcm/run_pcm_suite.jl
```

输出目录默认为 `output/pcm_benchmark/three_method_<timestamp>/`，主要文件为：

- `metrics.csv`：每个场景、方法和重复实验的原始计量；
- `summary.csv`：按场景和方法聚合的中位耗时、内存、成本、回退和交叠窗指标；
- `comparison.csv`：相对 standard 的速度、成本、内存和整数变量缩减率；
- `cluster_intermediate.csv`：聚类 PCM 每个滚动区间的聚类规模、降维率、解群校核结果和回退诊断；
- `adaptive_intermediate.csv`：自适应交叠窗每个滚动区间的稳态/驻留/爬坡判断、最终交叠长度和实际求解时域；
- `comparison.md`：可直接阅读的对比报告。

### 108 / 1080 物理机组规模对比

对比两套输入规模时，使用独立子目录运行，避免不同规模的 `output/details_schedule_results` 相互覆盖：

```powershell
$env:PCM_SOLVER='gurobi'
$env:PCM_BENCHMARK_PROFILES='baseline,smooth,extreme_ramp'
$env:PCM_BENCHMARK_METHODS='standard,clustered_pcm,adaptive_overlap'
$env:PCM_BENCHMARK_RUNS='1'
$env:PCM_INTERVALS='1'
$env:PCM_WINDOW_HOURS='24'
julia --project=pkg tools/pcm/benchmark/scale_runner.jl
```

未设置上述两个环境变量时，双规模脚本默认运行三种负荷模式和三套 PCM 方法；每个规模单独写入子目录。

脚本默认使用 `data_118_clustered_pcm.xlsx`（108 台物理机组）和 `data_118_clustered_pcm_10x.xlsx`（1080 台物理机组），分别写入 `output/pcm_benchmark/two_scale_<timestamp>/108_units/` 和 `1080_units/`。每个子目录包含 `metrics.csv`、`summary.csv`、`comparison.csv`、`cluster_intermediate.csv`、逐方法日志、`comparison.md` 和 `analysis_report.md`。这里的 108/1080 指物理机组数量，两套输入的网络母线均为 118。

可通过 `PCM_THREE_METHOD_OUTPUT` 指定输出目录，`PCM_INPUT_XLSX` 指定输入文件，`PCM_INTERVALS` 和 `PCM_WINDOW_HOURS` 指定滚动范围。脚本默认使用 `pkg` 环境；如需切换 Julia 环境，可设置 `PCM_JULIA_PROJECT`。

`PCM_SOLVER` 支持 `gurobi`、`glpk` 和 `auto`，默认是 `gurobi`。指定 `gurobi` 时，如果 Gurobi 包或许可证不可用，程序会明确报错，不会静默退回 GLPK。

### 自适应交叠窗训练数据缓存

首次针对某个算例、负荷模式和窗口配置生成训练数据：

```powershell
$env:MODULE_UC_DATA_FILE='data/data_118_clustered_pcm.xlsx'
$env:PCM_LOAD_PROFILE='smooth'
$env:PCM_SOLVER='gurobi'
julia --project=pkg tools/pcm/clustered_overlap_pcm/data_tools/offline_dataset_generator.jl
```

训练数据会按算例文件内容哈希、机组/网络规模、负荷模式、求解器、滚动窗口、训练模式和负荷/风电曲线指纹保存到 `output/pcm_training_cache/overlap_training_cache/<signature>/`。后续运行 adaptive_overlap 时，终端会打印 `Training cache: HIT` 并直接复用；算例、负荷模式或关键配置变化时打印 `MISS`，不会错误复用旧数据。需要强制重训时设置 `PCM_FORCE_TRAINING=1`。大规模算例可设置 `PCM_TRAINING_MODE=fast_max_overlap`，对当前 case 的四个扰动场景实际求解特征，并以当前最大交叠标注训练样本，避免逐一扫掠 0–12 h。

自适应在线决策默认在终端打印关键判据：边界状态、稳态特征、预测交叠、驻留约束、爬坡事件和最终 `max(...)` 决策。可设置 `PCM_OVERLAP_VERBOSE=0` 关闭。

`clustered_overlap_pcm/core` 采用“入口 + 单一职责组件”的组织方式：

- `pcm_overlap_core.jl`：唯一实际装载入口；使用 IDE 可索引的显式依赖顺序加载核心功能。
- `pcm_dependencies.jl`：数据结构与标准 PCM 求解器的静态依赖契约，支持 core 独立加载和 IDE 跳转。
- `generator_operating_features.jl`：机组快慢特征、边界衰减和净负荷爬坡识别。
- `accuracy_loss_models.jl`：精度损失模型、预测函数及轻量神经网络训练。
- `boundary_reference_policy.jl`：滚动边界偏差度量与局部参考组合策略。
- `accuracy_model_calibration.jl`：离线样本生成和精度模型标定。
- `overlap_window_policy.jl`：稳态映射与自适应交叠窗决策。
- `rolling_state_commit.jl`：窗口间状态传递、执行结果提交与成本统计。
- `overlap_predictor.jl`：数据驱动交叠时长预测器。
- `adaptive_period_scuc.jl`：两行历史兼容层，旧 include 路径和对外函数保持不变。
