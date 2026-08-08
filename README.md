# ModuleUnitCommitmentToolkit PCM Branch

本分支保留面向生产成本模拟（PCM）的核心代码、输入数据、测试和归档结果，已移除与 PCM 主流程无关的 `debug/`、`dev/`、`docs/`、`examples/` 和 `gui/` 目录。

## 主要内容

- `src/`：基础数据读取、建模约束、目标函数和公共模块入口。
- `tools/pcm/`：PCM 与自适应交叠滚动时域模拟相关脚本。
- `data/data_118.xlsx`：IEEE-118 测试系统输入数据。
- `data/backup_loadcurve_before_extreme_ramp_20260808_1919/`：极端爬坡负荷重构前的普通 118 场景备份。
- `output/archive/pcm_118_normal_vs_extreme_20260808_194121/`：普通 IEEE-118 与极端爬坡场景的交叠窗组合实验归档。
- `test/`：基础兼容性测试。

## PCM 关键脚本

```text
tools/pcm/adaptive_pcm_mainfunc.jl
tools/pcm/adaptive_period_scuc_modules.jl
tools/pcm/evaluate_overlap_criteria_combinations.jl
tools/pcm/generate_realistic_loadcurve.jl
tools/pcm/archive_pcm_comparison.jl
tools/pcm/summarize_archived_criteria_results.jl
```

## 常用运行命令

运行交叠窗判据组合评估：

```bash
julia --project=pkg tools/pcm/evaluate_overlap_criteria_combinations.jl
```

生成极端爬坡负荷曲线：

```bash
julia --project=pkg tools/pcm/generate_realistic_loadcurve.jl
```

汇总归档中的判据组合结果：

```bash
julia --project=pkg tools/pcm/summarize_archived_criteria_results.jl
```

生成普通 118 与极端爬坡场景的详细图表和报告：

```bash
julia --project=pkg tools/pcm/archive_pcm_comparison.jl --batch-dir output/archive/pcm_118_normal_vs_extreme_20260808_194121
```

## 当前实验结论

归档报告位于：

```text
output/archive/pcm_118_normal_vs_extreme_20260808_194121/summaryanalysisreport.md
```

主要结论：

- 普通 IEEE-118 场景下，`NoOverlap` 成本偏差较小，交叠窗主要提高滚动优化稳健性。
- 极端爬坡场景下，`NoOverlap` 成本偏差显著放大，说明强爬坡事件会强化滚动边界短视问题。
- `RampOnly` 在极端爬坡场景中具有较高性价比，能用较小平均交叠窗消除大部分误差。
- `Steady+Ramp` 综合表现最好，适合作为强爬坡场景下的主推荐判据组合。
- `Steady+Unit+Ramp` 可作为保守参考组，但不一定是计算性能最优的默认方案。

## 测试

运行当前测试集：

```bash
julia --project=pkg test/runtests.jl
```

最近一次兼容性验证结果为 `291/291` 通过。

## 依赖

主要依赖包括 Julia、JuMP、Gurobi、CSV、DataFrames、XLSX、PowerSystems 和 PowerSystemCaseBuilder。优化计算需要本机可用的 Gurobi 安装和许可证。
