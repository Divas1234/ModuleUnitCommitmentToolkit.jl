# PCM 代码目录

```text
tools/pcm/
├── standard/                 # 常规固定窗口 PCM / 单机 SCUC 主流程
│   ├── pcm_main.jl
│   └── period_scuc.jl
├── adaptive_overlap/         # 自适应交叠窗方法
│   ├── core/                 # 按工业职责拆分的交叠窗核心组件
│   ├── runners/              # 可执行仿真流程
│   ├── analysis/             # 性能比较和准则评估
│   ├── data_tools/           # 离线样本与负荷数据工具
│   ├── docs/                 # 方法说明
│   └── paths.jl              # 项目相对路径统一定义
├── clustered_pcm/            # 同质聚类、驻留解群与网络再调度
│   ├── clustered_pcm.jl
│   ├── adapter.jl
│   ├── master.jl
│   └── network_dispatch.jl
├── main.jl                   # 三种方法的唯一程序入口
└── period_scuc.jl            # 旧 include 使用的模型兼容入口
```

新增代码应放入对应方法目录，不再继续堆放到 `tools/pcm` 根目录。

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

## 三方案统一基准与结果对比

使用统一输入、负荷曲线、滚动区间和独立 Julia 进程，依次运行 standard、clustered_pcm 和 adaptive_overlap，并生成逐次计量、聚合统计、相对 standard 指标及 Markdown 报告：

```powershell
$env:PCM_BENCHMARK_RUNS='3'
$env:PCM_BENCHMARK_PROFILES='baseline,smooth,extreme_ramp'
$env:PCM_OVERLAP_MODE='ml_prediction'
$env:PCM_SOLVER='gurobi'
julia --project=pkg tools/pcm/benchmark_three_methods.jl
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
julia --project=pkg tools/pcm/benchmark_two_scales.jl
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
julia --project=pkg tools/pcm/adaptive_overlap/data_tools/offline_dataset_generator.jl
```

训练数据会按算例文件内容哈希、机组/网络规模、负荷模式、求解器、滚动窗口、训练模式和负荷/风电曲线指纹保存到 `output/pcm_training_cache/overlap_training_cache/<signature>/`。后续运行 adaptive_overlap 时，终端会打印 `Training cache: HIT` 并直接复用；算例、负荷模式或关键配置变化时打印 `MISS`，不会错误复用旧数据。需要强制重训时设置 `PCM_FORCE_TRAINING=1`。大规模算例可设置 `PCM_TRAINING_MODE=fast_max_overlap`，对当前 case 的四个扰动场景实际求解特征，并以当前最大交叠标注训练样本，避免逐一扫掠 0–12 h。

自适应在线决策默认在终端打印关键判据：边界状态、稳态特征、预测交叠、驻留约束、爬坡事件和最终 `max(...)` 决策。可设置 `PCM_OVERLAP_VERBOSE=0` 关闭。

`adaptive_overlap/core` 采用“入口 + 单一职责组件”的组织方式：

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
