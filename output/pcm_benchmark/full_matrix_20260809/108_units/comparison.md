# PCM 三方案统一计算结果与性能对比

- 输入：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap
- 滚动范围：1 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 25.857843083 | 2004.171875 | 1.70480562064e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 22.051101875 | 1734.65625 | 1.8255790597e6 | 1.172632697884173 | 7.084293810262099 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 36.107808416 | 2311.59375 | 1.7141375804527716e6 | 0.716128843520227 | 0.5473914269046309 | 0.0 | 10.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 24.505259916 | 2039.9375 | 1.59593969077e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 20.914592667 | 1707.03125 | 1.66135632775e6 | 1.1716823897156514 | 4.098941667929701 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 34.350219667 | 2207.953125 | 1.5986763264190545e6 | 0.713394562059876 | 0.17147487871136402 | 0.0 | 10.0 | 0.0 |
| extreme_ramp | standard | gurobi | 1 | 100.0 | 26.6651285 | 1964.09375 | 1.82269688839e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 1 | 100.0 | 28.289424583 | 2163.234375 | 1.82269688839e6 | 0.9425829225251867 | 0.0 | 1.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 44.744346333 | 2345.0 | 1.8451662334810244e6 | 0.5959440842324664 | 1.2327526992637727 | 0.0 | 12.0 | 1.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 9428.220611572266 | 0.0 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 4090.092575073242 | -56.618616135763375 |
| baseline | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 26193.788192749023 | 177.82324228390013 |
| smooth | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 9432.1142578125 | 0.0 |
| smooth | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 4065.739028930664 | -56.89472245776641 |
| smooth | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 26196.816772460938 | 177.74066403789 |
| extreme_ramp | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 9439.01577758789 | 0.0 |
| extreme_ramp | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 10051.262649536133 | 6.48634228795304 |
| extreme_ramp | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 27354.945861816406 | 189.8071844181923 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 1 | 1 | 108 | 31 | 71.3 | failed | network_disaggregation | diagnostic relaxation identified ramp; lines=Int64[], periods=[24, 13, 14, 19, 20, 21, 22], deviations=23 |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 3.7245562076568604 | OK |
| smooth | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 2.9449548721313477 | OK |
| extreme_ramp | 1 | 1 | 10 | 0 | true | 12 | ramp | 12 | 36 | 8.493529081344604 | OK |

## 解释口径

- `speedup_vs_standard > 1` 表示比 standard 更快。
- `cost_delta_pct` 为相对 standard 的总调度成本变化；缺少可靠成本文件时记为 `NA`。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

