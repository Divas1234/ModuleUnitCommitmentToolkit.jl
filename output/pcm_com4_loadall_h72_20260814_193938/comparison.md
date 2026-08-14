# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\data\data_118_clustered_pcm.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：integrated_uc, standard, adaptive_overlap, clustered_pcm, clustered_adaptive_overlap
- 滚动范围：3 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | integrated_uc | gurobi | 1 | 100.0 | 42.87000012397766 | 0.0 | 0.0 | 56.4084313 | 2005.56640625 | 5.59057145713e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | standard | gurobi | 1 | 100.0 | 24.572999954223633 | 0.0 | 0.0 | 38.1035952 | 1939.7890625 | 5.69992158947e6 | 1.744597737510235 | 1.9559741464450608 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 31.075999975204468 | 0.0 | 0.0 | 57.1528256 | 1991.91796875 | 5.6886734148625005e6 | 1.3795211789864725 | 1.7547751331822292 | 0.0 | 7.333333333333333 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 35.388999938964844 | 0.0 | 0.0 | 48.7393179 | 2006.6484375 | 7.2386832682e6 | 1.2113933764140057 | 29.480202940042233 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 43.694000005722046 | 0.0 | 0.0 | 69.3261137 | 2203.1875 | 5.707995716266256e6 | 0.9811415782112767 | 2.100398144209348 | 0.0 | 6.666666666666667 | 0.0 | 0.0 | 0.0 |
| smooth | integrated_uc | gurobi | 1 | 100.0 | 48.07100009918213 | 0.0 | 0.0 | 61.8522262 | 1974.171875 | 5.17138625664e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 24.100000143051147 | 0.0 | 0.0 | 38.132962 | 1916.90625 | 5.26586735821e6 | 1.9946472951803131 | 1.82699757630147 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 25.768999576568604 | 0.0 | 0.0 | 51.9015621 | 2017.60546875 | 5.207045326800037e6 | 1.865458531145013 | 0.6895456728696514 | 0.0 | 8.333333333333334 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 32.08500003814697 | 0.0 | 0.0 | 46.141346 | 2085.6328125 | 5.242343969799999e6 | 1.4982390538266743 | 1.3721217027424792 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 55.989999771118164 | 0.0 | 0.0009999275207519531 | 82.0832556 | 2266.71484375 | 5.232686171737229e6 | 0.8585640345720993 | 1.1853671734251225 | 0.0 | 6.333333333333333 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | integrated_uc | gurobi | 1 | 100.0 | 54.95100021362305 | 0.0 | 0.0 | 69.9879936 | 1972.6484375 | 8.268608021600001e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | standard | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 1815.53515625 | 0.0 | NA | -100.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 43.12400031089783 | 0.0 | 0.0 | 68.7814217 | 2051.95703125 | 7.991524319607217e6 | 1.2742556306803576 | -3.3510320149287565 | 0.0 | 12.0 | 3.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 3790.23828125 | 0.0 | NA | -100.0 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 600.0590000152588 | 0.0 | 0.0 | 626.2694966 | 5775.640625 | 8.13239075904268e6 | 0.0915759953808304 | -1.6474025882165622 | 1.0 | 12.0 | 3.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | integrated_uc | 108.0 | 108.0 | 0.0 | 23328.0 | 0.0 | 45182.84816169739 | 0.0 |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | 19055.372178077698 | -57.82609341074827 |
| baseline | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | 29841.957787513733 | -33.95290690680386 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | 9836.804997444153 | -78.22889570342966 |
| baseline | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | 13463.883200645447 | -70.20134022436612 |
| smooth | integrated_uc | 108.0 | 108.0 | 0.0 | 23328.0 | 0.0 | 45190.48631668091 | 0.0 |
| smooth | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | 19063.158749580383 | -57.81599114470315 |
| smooth | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | 30929.623909950256 | -31.557222701245024 |
| smooth | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | 9577.306856155396 | -78.80680728009742 |
| smooth | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | 12644.254385948181 | -72.02009666959286 |
| extreme_ramp | integrated_uc | 108.0 | 108.0 | 0.0 | 23328.0 | 0.0 | 45193.03437805176 | 0.0 |
| extreme_ramp | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | NA | NA |
| extreme_ramp | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 66.66666666666667 | 36650.92712879181 | -18.90138019457368 |
| extreme_ramp | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | NA | NA |
| extreme_ramp | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 90.4320987654321 | 52022.67973232269 | 15.1121637399674 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 2 | 1 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| baseline | 1 | 3 | 1 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| baseline | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 2 | 108 | 35 | 67.6 | completed |  | ✓ True clustered UC completed (35 virtual units) |
| baseline | 1 | 0 | 3 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| smooth | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 2 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 3 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 2 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 0 | 3 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| extreme_ramp | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 2 | 1 | 108 | 34 | 68.5 | attempted |  |  |
| extreme_ramp | 1 | 2 | 2 | 108 | 34 | 68.5 | attempted |  |  |
| extreme_ramp | 1 | 2 | 3 | 108 | 34 | 68.5 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 2 | 108 | 36 | 66.7 | attempted |  |  |
| extreme_ramp | 1 | 0 | 3 | 108 | 36 | 66.7 | attempted |  |  |
| extreme_ramp | 1 | 0 | 4 | 108 | 36 | 66.7 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 5 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 6 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 7 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 4 | 0 | false | 0 | steady | 4 | 28 | 14.660000085830688 | OK |
| baseline | 1 | 2 | 3 | 6 | false | 0 | unit_dwell | 6 | 30 | 3.25600004196167 | OK |
| baseline | 1 | 3 | 12 | 3 | false | 0 | steady | 12 | 36 | 11.766999959945679 | OK |
| baseline | 1 | 1 | 4 | 0 | false | 0 | steady | 4 | 28 | 17.82200002670288 | OK |
| baseline | 1 | 2 | 4 | 3 | false | 0 | steady | 4 | 28 | 9.587000131607056 | OK |
| baseline | 1 | 3 | 12 | 1 | false | 0 | steady | 12 | 36 | 14.38700008392334 | OK |
| smooth | 1 | 1 | 9 | 0 | false | 0 | steady | 9 | 33 | 16.822999954223633 | OK |
| smooth | 1 | 2 | 6 | 7 | false | 0 | unit_dwell | 7 | 31 | 3.544999837875366 | OK |
| smooth | 1 | 3 | 9 | 0 | false | 0 | steady | 9 | 33 | 3.5829999446868896 | OK |
| smooth | 1 | 1 | 2 | 0 | false | 0 | steady | 2 | 26 | 18.817999839782715 | OK |
| smooth | 1 | 2 | 2 | 5 | false | 0 | unit_dwell | 5 | 29 | 10.810999870300293 | OK |
| smooth | 1 | 3 | 12 | 7 | false | 0 | steady | 12 | 36 | 24.82099986076355 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 25.453999996185303 | OK |
| extreme_ramp | 1 | 2 | 7 | 4 | true | 12 | ramp | 12 | 36 | 4.015000104904175 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 12.134999990463257 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 501.7060000896454 | OK |
| extreme_ramp | 1 | 2 | 2 | 4 | true | 12 | ramp | 12 | 36 | 68.77600002288818 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 28.06499981880188 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

