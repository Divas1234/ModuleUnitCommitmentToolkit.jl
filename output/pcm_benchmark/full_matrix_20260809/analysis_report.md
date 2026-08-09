# 三套 PCM 方法双规模综合分析报告

- 算例规模：108 / 1080 台物理机组；两套输入均为 118 母线。
- 负荷模式：baseline, smooth, extreme_ramp
- PCM 方法：standard, clustered_pcm, adaptive_overlap
- 求解器：`gurobi`；重复次数：1；滚动区间：1 × 24 h；网络约束：0
- 自适应交叠窗：统一使用 `ml_prediction`；训练模式：`PCM_TRAINING_MODE=fast_max_overlap`。

> 本报告由 `tools/pcm/benchmark_two_scales.jl` 生成。每个规模的完整计量、中间过程和日志分别保存在 `108_units/` 与 `1080_units/`。

## 综合结果

| 规模 | 负荷模式 | 方法 | 成本 | 耗时(s) | 峰值RSS(MB) | 成本变化 | 时间变化 | 平均交叠(h) | 聚类回退 | 整数变量缩减 | 成功率 |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 108_units | baseline | standard | 1.7048e+06 | 25.86 | 2004.17 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 108_units | baseline | clustered_pcm | 1.8256e+06 | 22.05 | 1734.66 | +7.084% | -14.72% | 0.0 | 0 | 71.30% | 100.0% |
| 108_units | baseline | adaptive_overlap | 1.7141e+06 | 36.11 | 2311.59 | +0.547% | +39.64% | 10.0 | 0 | 0.00% | 100.0% |
| 108_units | smooth | standard | 1.5959e+06 | 24.51 | 2039.94 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 108_units | smooth | clustered_pcm | 1.6614e+06 | 20.91 | 1707.03 | +4.099% | -14.65% | 0.0 | 0 | 71.30% | 100.0% |
| 108_units | smooth | adaptive_overlap | 1.5987e+06 | 34.35 | 2207.95 | +0.171% | +40.17% | 10.0 | 0 | 0.00% | 100.0% |
| 108_units | extreme_ramp | standard | 1.8227e+06 | 26.67 | 1964.09 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 108_units | extreme_ramp | clustered_pcm | 1.8227e+06 | 28.29 | 2163.23 | +0.000% | +6.09% | 0.0 | 1 | 71.30% | 100.0% |
| 108_units | extreme_ramp | adaptive_overlap | 1.8452e+06 | 44.74 | 2345.00 | +1.233% | +67.80% | 12.0 | 0 | 0.00% | 100.0% |
| 1080_units | baseline | standard | 3.6533e+07 | 103.51 | 3714.16 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 1080_units | baseline | clustered_pcm | 3.8632e+07 | 21.28 | 1811.30 | +5.744% | -79.45% | 0.0 | 0 | 97.13% | 100.0% |
| 1080_units | baseline | adaptive_overlap | 3.6470e+07 | 431.31 | 3930.67 | -0.171% | +316.67% | 10.0 | 0 | 0.00% | 100.0% |
| 1080_units | smooth | standard | 3.5746e+07 | 78.03 | 3438.30 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 1080_units | smooth | clustered_pcm | 3.5701e+07 | 21.28 | 1793.95 | -0.125% | -72.73% | 0.0 | 0 | 97.13% | 100.0% |
| 1080_units | smooth | adaptive_overlap | 3.5723e+07 | 241.84 | 4014.36 | -0.064% | +209.94% | 10.0 | 0 | 0.00% | 100.0% |
| 1080_units | extreme_ramp | standard | 3.7511e+07 | 205.59 | 3997.14 | +0.000% | +0.00% | 0.0 | 0 | 0.00% | 100.0% |
| 1080_units | extreme_ramp | clustered_pcm | 3.7511e+07 | 212.92 | 4117.05 | +0.000% | +3.57% | 0.0 | 1 | 97.13% | 100.0% |
| 1080_units | extreme_ramp | adaptive_overlap | 3.7548e+07 | 683.47 | 3987.08 | +0.101% | +232.44% | 10.0 | 0 | 0.00% | 100.0% |

## 关键判断

1. 成本统计采用各方法最终提交的执行区间；adaptive 的交叠预测区间只用于扩展优化视野，不会把交叠小时再次计入总调度成本。
2. `fast_max_overlap` 为大规模训练加速模式：每个 case/profile 使用 4 个当前 case 扰动样本，标签取该区间允许的最大交叠。它保留了 ML 缓存命中链路，但不等同于完整 0–12 h 成本扫描；若需要严格标定，应切回 `PCM_TRAINING_MODE=sweep` 单独训练。
3. clustered PCM 的主问题只保留聚类机组开停、停机和数量一致性约束，单机解群可行性在主问题完成后校核；因此回退次数是聚类精度的重要判据。
4. 每个规模目录中的 `adaptive_intermediate.csv` 保留稳态判据、驻留约束、爬坡事件、最终交叠长度和实际求解时域；`cluster_intermediate.csv` 保留聚类与解群校核过程。

## 输出结构

- `108_units/analysis_report.md`、`1080_units/analysis_report.md`：分规模报告。
- 各规模目录的 `metrics.csv`、`summary.csv`、`comparison.csv`：原始计量、聚合指标和相对 standard 对比。
- `output/pcm_training_cache/overlap_training_cache/`：按 case 内容哈希、规模、负荷模式和训练配置隔离的可复用训练数据。
