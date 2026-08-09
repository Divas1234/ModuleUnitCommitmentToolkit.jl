# PCM 三方案统一计算结果与性能对比

- 输入：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm_10x.xlsx`
- 场景：baseline
- 方法：standard, clustered_pcm
- 滚动范围：1 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 170.820907833 | 2298.9375 | 3.653297589684e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 33.480671042 | 1679.78125 | 3.863150768137e7 | 5.102075392058685 | 5.744212545005167 | 0.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 416302.9282531738 | 0.0 |
| baseline | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 4585.139938354492 | -98.89860492752382 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |

## 解释口径

- `speedup_vs_standard > 1` 表示比 standard 更快。
- `cost_delta_pct` 为相对 standard 的总调度成本变化；缺少可靠成本文件时记为 `NA`。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

