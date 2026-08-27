# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\data\data_118_clustered_pcm.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap, clustered_adaptive_overlap
- 滚动范围：3 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 41.32000017166138 | 0.0 | 0.0 | 102.4038066 | 1948.38671875 | 5.710659314139999e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 1 | 100.0 | 59.13599991798401 | 0.0 | 0.0 | 83.2485921 | 2253.26171875 | 7.16192976891e6 | 0.6987283588502482 | 25.413360786145155 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 43.78000020980835 | 0.0 | 0.0 | 89.7698479 | 2171.71875 | 5.762295065203445e6 | 0.9438099582832838 | 0.9041994666989073 | 0.0 | 8.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 74.41700005531311 | 0.0 | 0.0 | 119.7330821 | 2622.83203125 | 5.712805083547937e6 | 0.5552494744607925 | 0.03757481036601451 | 0.0 | 6.666666666666667 | 0.0 | 0.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 30.688999891281128 | 0.0 | 0.0 | 53.2477123 | 1964.54296875 | 5.20919667043e6 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 53.9539999961853 | 0.0 | 0.0 | 75.0332514 | 2199.69140625 | 5.229387896199999e6 | 0.5687993456175803 | 0.38760728472040373 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 24.712000131607056 | 0.0 | 0.0 | 49.9598554 | 2121.55859375 | 5.19192009605302e6 | 1.2418662887602283 | -0.3316552526236971 | 0.0 | 8.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 49.75099992752075 | 0.0 | 0.0 | 77.5240531 | 2603.80078125 | 5.250186082627677e6 | 0.6168519212878152 | 0.7868662826718387 | 0.0 | 6.333333333333333 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | standard | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 1995.4921875 | 0.0 | NA | NA | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 3643.05859375 | 0.0 | NA | NA | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 37.342000007629395 | 0.0 | 0.0 | 62.7720781 | 2315.73046875 | 7.996314217519175e6 | NA | NA | 0.0 | 12.0 | 3.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 143.56900024414062 | 0.0 | 0.0009999275207519531 | 170.1088256 | 6292.99609375 | 8.130275262387202e6 | NA | NA | 1.0 | 12.0 | 3.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 19020.661589622498 | 0.0 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 9773.76503944397 | -48.61501008578772 |
| baseline | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 30706.51287841797 | 61.43766994504107 |
| baseline | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 12678.533737182617 | -33.34336096858003 |
| smooth | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 19028.800072669983 | 0.0 |
| smooth | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 9534.296907424927 | -49.89543812003936 |
| smooth | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 30447.039101600647 | 60.005039652132616 |
| smooth | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 12457.747338294983 | -34.53214448247128 |
| extreme_ramp | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | NA | NA |
| extreme_ramp | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | NA | NA |
| extreme_ramp | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 36614.49136638641 | NA |
| extreme_ramp | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 51287.12917327881 | NA |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 2 | 1 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| baseline | 1 | 3 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| baseline | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 2 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 0 | 3 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 2 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 3 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 2 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 0 | 3 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| extreme_ramp | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 2 | 1 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 2 | 2 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 2 | 3 | 108 | 35 | 67.6 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 2 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 3 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 4 | 108 | 35 | 67.6 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 5 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 6 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 7 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 4 | 0 | false | 0 | steady | 4 | 28 | 24.993000030517578 | OK |
| baseline | 1 | 2 | 3 | 8 | false | 0 | unit_dwell | 8 | 32 | 7.565000057220459 | OK |
| baseline | 1 | 3 | 12 | 1 | false | 0 | steady | 12 | 36 | 8.769000053405762 | OK |
| baseline | 1 | 1 | 4 | 0 | false | 0 | steady | 4 | 28 | 34.18400001525879 | OK |
| baseline | 1 | 2 | 4 | 3 | false | 0 | steady | 4 | 28 | 14.76200008392334 | OK |
| baseline | 1 | 3 | 12 | 1 | false | 0 | steady | 12 | 36 | 22.931999921798706 | OK |
| smooth | 1 | 1 | 9 | 0 | false | 0 | steady | 9 | 33 | 15.70799994468689 | OK |
| smooth | 1 | 2 | 6 | 4 | false | 0 | steady | 6 | 30 | 3.317000150680542 | OK |
| smooth | 1 | 3 | 9 | 7 | false | 0 | steady | 9 | 33 | 4.295000076293945 | OK |
| smooth | 1 | 1 | 2 | 0 | false | 0 | steady | 2 | 26 | 19.266000032424927 | OK |
| smooth | 1 | 2 | 2 | 5 | false | 0 | unit_dwell | 5 | 29 | 11.009000062942505 | OK |
| smooth | 1 | 3 | 12 | 7 | false | 0 | steady | 12 | 36 | 17.895999908447266 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 24.52500009536743 | OK |
| extreme_ramp | 1 | 2 | 7 | 4 | true | 12 | ramp | 12 | 36 | 5.429999828338623 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 5.926000118255615 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 66.2590000629425 | OK |
| extreme_ramp | 1 | 2 | 2 | 4 | true | 12 | ramp | 12 | 36 | 50.27800011634827 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 25.60599994659424 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

