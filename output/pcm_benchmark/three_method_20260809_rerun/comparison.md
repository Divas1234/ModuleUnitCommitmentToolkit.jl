# PCM 三方案统一计算结果与性能对比

- 输入：`/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment/data/data_118_clustered_pcm.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap
- 滚动范围：3 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 31.170865375 | 2192.84375 | 5.25377266728e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 33.544613083 | 2094.5 | 5.36600976162e6 | 0.9292360981440866 | 2.136314253545879 | 2.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 48.601376875 | 2279.296875 | 5.271709797588455e6 | 0.6413576606105154 | 0.3414142834950784 | 0.0 | 10.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 28.134501459 | 2051.078125 | 5.02939890262e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 29.951233084 | 1946.546875 | 5.07077223375e6 | 0.9393436784420572 | 0.8226297402746718 | 2.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 46.872341709 | 2213.8125 | 4.971022324901784e6 | 0.6002367373422239 | -1.1607068528170505 | 0.0 | 11.0 | 0.0 |
| extreme_ramp | standard | gurobi | 1 | 100.0 | 30.387894792 | 2044.890625 | 5.9562647961099995e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 1 | 100.0 | 32.781969792 | 2101.046875 | 5.9562647961099995e6 | 0.9269697637088227 | 0.0 | 3.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 67.615097583 | 2296.8125 | 6.260468971138497e6 | 0.4494246977118942 | 5.107297701525471 | 0.0 | 12.0 | 3.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 19117.556243896484 | 0.0 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 16193.455993652344 | -15.295366274534672 |
| baseline | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 65854.17231750488 | 244.46961461682446 |
| smooth | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 19121.446166992188 | 0.0 |
| smooth | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 15956.781616210938 | -16.550341031444347 |
| smooth | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 67718.89498138428 | 254.15153430330992 |
| extreme_ramp | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 19128.526565551758 | 0.0 |
| extreme_ramp | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 20737.375549316406 | 8.410731366324885 |
| extreme_ramp | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 69314.81338500977 | 262.3635785405325 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 2 | 1 | 108 | 39 | 63.9 | failed | residence_flow | insufficient mature off pool |
| baseline | 1 | 3 | 1 | 108 | 39 | 63.9 | failed | residence_flow | insufficient mature on pool |
| smooth | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 2 | 1 | 108 | 36 | 66.7 | failed | residence_flow | insufficient mature off pool |
| smooth | 1 | 3 | 1 | 108 | 35 | 67.6 | failed | residence_flow | insufficient mature on pool |
| extreme_ramp | 1 | 1 | 1 | 108 | 31 | 71.3 | failed | network_disaggregation | diagnostic relaxation identified ramp; lines=Int64[], periods=[24, 13, 14, 19, 20, 21, 22], deviations=23 |
| extreme_ramp | 1 | 2 | 1 | 108 | 34 | 68.5 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 3 | 1 | 108 | 34 | 68.5 | failed | cluster_master | INFEASIBLE |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 4.006550073623657 | OK |
| baseline | 1 | 2 | 10 | 7 | false | 0 | steady | 10 | 34 | 2.500734806060791 | OK |
| baseline | 1 | 3 | 10 | 7 | false | 0 | steady | 10 | 34 | 2.28261399269104 | OK |
| smooth | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 3.325653076171875 | OK |
| smooth | 1 | 2 | 12 | 5 | false | 0 | steady | 12 | 36 | 2.535428047180176 | OK |
| smooth | 1 | 3 | 9 | 9 | false | 0 | steady+unit_dwell | 9 | 33 | 2.1374409198760986 | OK |
| extreme_ramp | 1 | 1 | 10 | 0 | true | 12 | ramp | 12 | 36 | 8.155471086502075 | OK |
| extreme_ramp | 1 | 2 | 10 | 7 | true | 12 | ramp | 12 | 36 | 2.9639031887054443 | OK |
| extreme_ramp | 1 | 3 | 10 | 1 | true | 12 | ramp | 12 | 36 | 4.497560024261475 | OK |

## 解释口径

- `speedup_vs_standard > 1` 表示比 standard 更快。
- `cost_delta_pct` 为相对 standard 的总调度成本变化；缺少可靠成本文件时记为 `NA`。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

