# PCM 三方案统一计算结果与性能对比

- 输入：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm_10x.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap
- 滚动范围：1 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 103.512786166 | 3714.15625 | 3.653297589684e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 21.275012042 | 1811.296875 | 3.863150768137e7 | 4.86546310580932 | 5.744212545005167 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 431.306943667 | 3930.671875 | 3.6470472147768445e7 | 0.23999795896149384 | -0.17108857829717383 | 0.0 | 10.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 78.028476458 | 3438.296875 | 3.574592197009e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 21.276845334 | 1793.953125 | 3.570112254738e7 | 3.6672953735914953 | -0.12532736670629596 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 241.838346791 | 4014.359375 | 3.572318662050705e7 | 0.32264724553973767 | -0.06360263865058391 | 0.0 | 10.0 | 0.0 |
| extreme_ramp | standard | gurobi | 1 | 100.0 | 205.592958042 | 3997.140625 | 3.751062061174e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 1 | 100.0 | 212.923157458 | 4117.046875 | 3.751062061174e7 | 0.965573498423036 | 0.0 | 1.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 683.469768208 | 3987.078125 | 3.754848134496672e7 | 0.3008076839756166 | 0.10093336929453134 | 0.0 | 10.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 416301.8070983887 | 0.0 |
| baseline | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 4585.038757324219 | -98.898626266054 |
| baseline | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 1.6387708136291504e6 | 293.64969973379044 |
| smooth | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 416309.818649292 | 0.0 |
| smooth | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 4586.390197753906 | -98.89832283739203 |
| smooth | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 1.6399713907470703e6 | 293.9305097506279 |
| extreme_ramp | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 416313.1272277832 | 0.0 |
| extreme_ramp | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 416773.26304626465 | 0.11052637747588356 |
| extreme_ramp | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 1.6389986250305176e6 | 293.69371702126256 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 1 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 1 | 1 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 194.15586805343628 | OK |
| smooth | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 96.21670508384705 | OK |
| extreme_ramp | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 301.6498739719391 | OK |

## 解释口径

- `speedup_vs_standard > 1` 表示比 standard 更快。
- `cost_delta_pct` 为相对 standard 的总调度成本变化；缺少可靠成本文件时记为 `NA`。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

