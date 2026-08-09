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
