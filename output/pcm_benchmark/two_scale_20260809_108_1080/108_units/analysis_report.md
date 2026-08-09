# PCM 108_units 规模算例分析报告

- 规模标签：`108_units`（数据文件中的物理机组规模）
- 输入文件：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm.xlsx`
- 网络母线：118；本报告中的 108/1080 指物理机组数量，不是母线数量。
- 负荷模式：baseline
- PCM 方法：standard, clustered_pcm
- 重复次数：1；滚动范围：1 × 24 h；网络约束：0

> 下方内容由统一 benchmark 运行结果生成；原始计量、中间过程和日志保存在同一目录。

## 核心结论

- standard 基准：总成本 1.7048e+06，耗时 34.69 s，峰值 RSS 1668.83 MB，物理机组 108 台。
- clustered_pcm：总成本 1.8256e+06（相对 standard +7.084%），耗时 36.45 s（相对 +5.08%），峰值 RSS 1509.56 MB（相对 -9.54%），整数变量缩减 71.30%。
  - 聚类过程：本次聚类区间全部通过后验校核；等效机组 31 台，状态缩减 71.3%。

## 结果解读

本次 108/1080 规模指物理机组数量；两套输入的网络母线均为 118。成本、耗时和内存均来自独立 Julia 进程，聚类回退次数与中间校核结果保留在 `cluster_intermediate.csv` 和对应 `run.log` 中。

# PCM 三方案统一计算结果与性能对比

- 输入：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm.xlsx`
- 场景：baseline
- 方法：standard, clustered_pcm
- 滚动范围：1 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 34.691686667 | 1668.828125 | 1.70480562064e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 36.452995666 | 1509.5625 | 1.8255790597e6 | 0.9516827364439958 | 7.084293810262099 | 0.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 9428.180755615234 | 0.0 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 4090.1371002197266 | -56.61796049270986 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |

## 解释口径

- `speedup_vs_standard > 1` 表示比 standard 更快。
- `cost_delta_pct` 为相对 standard 的总调度成本变化；缺少可靠成本文件时记为 `NA`。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

