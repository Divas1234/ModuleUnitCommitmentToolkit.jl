# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\.worktrees\108_168h\data\data_118_clustered_pcm.xlsx`
- 场景：baseline, smooth, extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap, clustered_adaptive_overlap
- 滚动范围：7 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 1 | 100.0 | 42.03399991989136 | 0.0 | 0.0 | 92.7938889 | 1997.71875 | 1.627596232615e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 3850.1875 | 0.0 | NA | -100.0 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 44.403000354766846 | 3468.940999984741 | 0.0 | 3541.3304714 | 2459.0859375 | 1.5846605714522481e7 | 0.9466477396584043 | -2.637979881150787 | 0.0 | 9.428571428571429 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 83.30299997329712 | 7816.085000038147 | 0.0 | 7925.5813183 | 6286.15234375 | 1.5881968963732496e7 | 0.5045916705684719 | -2.4207070188684954 | 0.0 | 8.571428571428571 | 0.0 | 0.0 | 0.0 |
| smooth | standard | gurobi | 1 | 100.0 | 36.22500014305115 | 0.0 | 0.0 | 85.3424115 | 1908.98828125 | 1.417770663973e7 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 59.81099987030029 | 0.0 | 0.0 | 74.7200082 | 2429.40234375 | 1.416741450303e7 | 0.6056578258448244 | -0.07259380491876355 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 39.91800045967102 | 3160.4489998817444 | 0.0 | 3227.5450573 | 2461.53125 | 1.4299706078429926e7 | 0.9074853380907469 | 0.8605019260170543 | 0.0 | 9.571428571428571 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 69.19799995422363 | 8453.421999931335 | 0.0 | 8548.9919603 | 5710.875 | 1.427093535777074e7 | 0.5234977913670189 | 0.6575726272928017 | 0.0 | 5.428571428571429 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | standard | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 1943.1328125 | 0.0 | NA | NA | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 3652.0234375 | 0.0 | NA | NA | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 57.5450005531311 | 4361.467000007629 | 0.0 | 4446.0945656 | 2463.828125 | 2.119186261989532e7 | NA | NA | 0.0 | 12.0 | 7.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 965.3739998340607 | 15690.588999986649 | 0.003000020980834961 | 16684.5934412 | 7682.69140625 | 2.118206219976053e7 | NA | NA | 3.0 | 12.0 | 7.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 37006.768527030945 | 0.0 |
| baseline | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | NA | NA |
| baseline | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 4.762213174282074e6 | 12768.492342971256 |
| baseline | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 3.73795057330513e6 | 10000.721360133915 |
| smooth | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 37014.71653652191 | 0.0 |
| smooth | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 15490.089519500732 | -58.151538174777386 |
| smooth | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 4.763163014615059e6 | 12768.295262818807 |
| smooth | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 3.4792619279050827e6 | 9299.671950674383 |
| extreme_ramp | standard | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | NA | NA |
| extreme_ramp | clustered_pcm | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | NA | NA |
| extreme_ramp | adaptive_overlap | 108.0 | 108.0 | 0.0 | 7776.0 | 0.0 | 4.733719445317268e6 | NA |
| extreme_ramp | clustered_adaptive_overlap | 108.0 | 31.0 | 71.2962962962963 | 2232.0 | 71.2962962962963 | 9.287262688898087e6 | NA |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 2 | 1 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| baseline | 1 | 3 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| baseline | 1 | 4 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| baseline | 1 | 5 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| baseline | 1 | 6 | 1 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| baseline | 1 | 7 | 1 | 108 | 34 | 68.5 | attempted |  |  |
| baseline | 1 | 7 | 2 | 108 | 34 | 68.5 | attempted |  |  |
| baseline | 1 | 7 | 3 | 108 | 34 | 68.5 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 2 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 3 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 4 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 5 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 6 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 7 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 8 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 9 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 10 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 11 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 12 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 13 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 14 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 15 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 16 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 17 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 18 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 19 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 20 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 21 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 22 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 23 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 24 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 25 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 26 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 27 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 28 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 29 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 30 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 31 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 32 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 33 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 34 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 35 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 36 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 37 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 38 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 39 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 40 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 41 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 42 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 43 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 44 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 45 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 46 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 47 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 48 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 49 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 50 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 51 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 52 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 53 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 54 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 55 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 56 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 57 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 58 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 59 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 60 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 61 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 62 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 63 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 64 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 65 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 66 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 67 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 68 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 69 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 70 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 71 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 72 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 73 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 74 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 75 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 76 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 77 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 78 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 79 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 80 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 81 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 82 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 83 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 84 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 85 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 86 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 87 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 88 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 89 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 90 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 91 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 92 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 93 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 94 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 95 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 96 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 97 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 98 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 99 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 100 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 101 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 102 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 103 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 104 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 105 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 106 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 107 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 108 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 109 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 110 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 111 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 112 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 113 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 114 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 115 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 116 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 117 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 118 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 119 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 120 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 121 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 122 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 123 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 124 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 125 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 126 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 127 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 128 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 129 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 130 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 131 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 132 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 133 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 134 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 135 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 136 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 137 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 138 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 139 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 140 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 141 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 142 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 143 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 144 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 145 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 146 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 147 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 148 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 149 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 150 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 151 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 152 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 153 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 154 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 155 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 156 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 157 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 158 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 159 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 160 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 161 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 162 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 163 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 164 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 165 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 166 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 167 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 168 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 169 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 170 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 171 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[9, 10, 34], deviations=3 |
| baseline | 1 | 0 | 172 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 173 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 174 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[9, 10, 34], deviations=3 |
| baseline | 1 | 0 | 175 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 176 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 177 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 178 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 179 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 180 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[9, 10, 28], deviations=3 |
| baseline | 1 | 0 | 181 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 182 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 183 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 184 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 185 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 186 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 187 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 188 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 189 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 190 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 191 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 192 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 193 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 194 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 195 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 196 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 197 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 198 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 199 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 200 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 201 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 202 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 203 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 204 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 205 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 206 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 207 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 208 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 209 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 210 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 211 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 212 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 213 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 214 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 215 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 216 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 217 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 218 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 219 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 220 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 221 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 222 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 223 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 224 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 225 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 226 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 227 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 228 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 229 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 230 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 231 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 232 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 233 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 234 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 235 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 236 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 237 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 238 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 239 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 240 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 241 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 242 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 243 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 244 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 245 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 246 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 247 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 248 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 249 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 250 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 251 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 252 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 253 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 254 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 255 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 256 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 257 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 258 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 259 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 260 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 261 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 262 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 263 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 264 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 265 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 266 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 267 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 268 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 269 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 270 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 271 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 272 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 273 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 274 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 275 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 276 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 277 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 278 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 279 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 280 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 281 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 282 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 283 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 284 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 285 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 286 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 287 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 288 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 289 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 290 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 291 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 292 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 293 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 294 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 295 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 296 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 297 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 298 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 299 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 300 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 301 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 302 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 303 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 304 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 305 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 306 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 307 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 308 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 309 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 310 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 311 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 312 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 313 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 314 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 315 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 316 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 317 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 318 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 319 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 320 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 321 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 322 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 323 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 324 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 325 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 326 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 327 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 328 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 329 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 330 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 331 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 332 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 333 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 334 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 335 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 336 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 337 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 338 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 339 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 340 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 341 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 342 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 343 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 344 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 345 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 346 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 347 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 348 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 349 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 350 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 351 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 352 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 353 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 354 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 355 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 356 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 357 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 358 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 359 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 360 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 361 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 362 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 363 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 364 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 365 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 366 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 367 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 368 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 369 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 370 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 371 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 372 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 373 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 374 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 375 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 376 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 377 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 378 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 379 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 380 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 381 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 382 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 383 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 384 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 385 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 386 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 387 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 388 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 389 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 390 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 391 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 392 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 393 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 394 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 395 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 396 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 397 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 398 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 399 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 400 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 401 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 402 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 403 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 404 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 405 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 406 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 407 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 408 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 409 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 410 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 411 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 412 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 413 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 414 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 415 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 416 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 417 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 418 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 419 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 420 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 421 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 422 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 423 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 424 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 425 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 426 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 427 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 428 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 429 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 430 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 431 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 432 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 433 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 434 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 435 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 436 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 437 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 438 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 439 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 440 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 441 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 442 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 443 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 444 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 445 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 446 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 447 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 448 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 449 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 450 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 451 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 452 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 453 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 454 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 455 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 456 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 457 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 458 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 459 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 460 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 461 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 462 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 463 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 464 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 465 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 466 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 467 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 468 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 469 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 470 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 471 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 472 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 473 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 474 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 475 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 476 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 477 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 478 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 479 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 480 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 481 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 482 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 483 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 484 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 485 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 486 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 487 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 488 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 489 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 490 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 491 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 492 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 493 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 494 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 495 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 496 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 497 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 498 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 499 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 500 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 501 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 502 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 503 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 504 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 505 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 506 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 507 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 508 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 509 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 510 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 511 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 512 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 513 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 514 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 515 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 516 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 517 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 518 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 519 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 520 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 521 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 522 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 523 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 524 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 525 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 526 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 527 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 528 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 529 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 530 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 531 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 532 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 533 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 534 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 535 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 536 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 537 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 538 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 539 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 540 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 541 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 542 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 543 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 544 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 545 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 546 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 547 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 548 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 549 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 550 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 551 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 552 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 553 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 554 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 555 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 556 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 557 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 558 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 559 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 560 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 561 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 562 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 563 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 564 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 565 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 566 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 567 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 568 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 569 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 570 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 571 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 572 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 573 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 574 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 575 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 576 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 577 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 578 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 579 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 580 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 581 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 582 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 583 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 584 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 585 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 586 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 587 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 588 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 589 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 590 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 591 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 592 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 593 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 594 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 595 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 596 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 597 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 598 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 599 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 600 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 601 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 602 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 603 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 604 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 605 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 606 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 607 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 608 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 609 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 610 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 611 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 612 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 613 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 614 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 615 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 616 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 617 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 618 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 619 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 620 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 621 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 622 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 623 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 624 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 625 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 626 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 627 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 628 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 629 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 630 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 631 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 632 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 633 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 634 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 635 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 636 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 637 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 638 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 639 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 640 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 641 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 642 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 643 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 644 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 645 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 646 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 647 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 648 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 649 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 650 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 651 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 652 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 653 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 654 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 655 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 656 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 657 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 658 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 659 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 660 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 661 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 662 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 663 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 664 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 665 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 666 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 667 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 668 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 669 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 670 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 671 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 672 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 673 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 674 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 675 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 676 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 677 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 678 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 679 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 680 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 681 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 682 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 683 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 684 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 685 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 686 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 687 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 688 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 689 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 690 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 691 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 692 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 693 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 694 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 695 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 696 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 697 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 698 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 699 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 700 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 701 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 702 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 703 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 704 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 705 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 706 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 707 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 708 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 709 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 710 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 711 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 712 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 713 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 714 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 715 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 716 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 717 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 718 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 719 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 720 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 721 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 722 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 723 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 724 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 725 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 726 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 727 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 728 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 729 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 730 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 731 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 732 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 733 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 734 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 735 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 736 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 737 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 738 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 739 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 740 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 741 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 742 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 743 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 744 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 745 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 746 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 747 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 748 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 749 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 750 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 751 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 752 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 753 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 754 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 755 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 756 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 757 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 758 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 759 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 760 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 761 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 762 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 763 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 764 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 765 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 766 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 767 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 768 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 769 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 770 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 771 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 772 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 773 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 774 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 775 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 776 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 777 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 778 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 779 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 780 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 781 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 782 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 783 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 784 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 785 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 786 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 787 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 788 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 789 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 790 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 791 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 792 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 793 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 794 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 795 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 796 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 797 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 798 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 799 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 800 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 801 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 802 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 803 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 804 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 805 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 806 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 807 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 808 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 809 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 810 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 811 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 812 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 813 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 814 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 815 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 816 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 817 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 818 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 819 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 820 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 821 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 822 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 823 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 824 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 825 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 826 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 827 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 828 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 829 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 830 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 831 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 832 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 833 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 834 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 835 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 836 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 837 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 838 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 839 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 840 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 841 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 842 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 843 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 844 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 845 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 846 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 847 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 848 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 849 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 850 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 851 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 852 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 853 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 854 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 855 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 856 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 857 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 858 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 859 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 860 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 861 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 862 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 863 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 864 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 865 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 866 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 867 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 868 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 869 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 870 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 871 | 108 | 31 | 71.3 | attempted |  |  |
| baseline | 1 | 0 | 872 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 873 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 874 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 875 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 876 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 877 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 878 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| baseline | 1 | 0 | 879 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 0 | 880 | 108 | 38 | 64.8 | completed |  | ✓ True clustered UC completed (38 virtual units) |
| baseline | 1 | 0 | 881 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 0 | 882 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 0 | 883 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 2 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 3 | 1 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 4 | 1 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 5 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 6 | 1 | 108 | 35 | 67.6 | completed |  | ✓ True clustered UC completed (35 virtual units) |
| smooth | 1 | 7 | 1 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 2 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 3 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 4 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 5 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 6 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 7 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 8 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 9 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 10 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 11 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 12 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 13 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 14 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 15 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 16 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 17 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 18 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 19 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 20 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 21 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 22 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 23 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 24 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 25 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 26 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 27 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 28 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 29 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 30 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 31 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 32 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 33 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 34 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 35 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 36 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 37 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 38 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 39 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 40 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 41 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 42 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 43 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 44 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 45 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 46 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 47 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 48 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 49 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 50 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 51 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 52 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 53 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 54 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 55 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 56 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 57 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 58 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 59 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 60 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 61 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 62 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 63 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 64 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 65 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 66 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 67 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 68 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 69 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 70 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 71 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 72 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 73 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 74 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 75 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 76 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 77 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 78 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 79 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 80 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 81 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 82 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 83 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 84 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 85 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 86 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 87 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 88 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 89 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 90 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 91 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 92 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 93 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 94 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 95 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 96 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 97 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 98 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 99 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 100 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 101 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 102 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 103 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 104 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 105 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 106 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 107 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 108 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 109 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 110 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 111 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 112 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 113 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 114 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 115 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 116 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 117 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 118 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 119 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 120 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 121 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 122 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 123 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 124 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 125 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 126 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 127 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 128 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 129 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 130 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 131 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 132 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 133 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 134 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 135 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 136 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 137 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 138 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 139 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 140 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 141 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 142 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 143 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 144 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 145 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 146 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 147 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 148 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 149 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 150 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 151 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 152 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 153 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 154 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 155 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 156 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 157 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 158 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 159 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 160 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 161 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 162 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 163 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 164 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 165 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 166 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 167 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 168 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 169 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 170 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 171 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 172 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 173 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 174 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 175 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 176 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 177 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 178 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 179 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 180 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 181 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 182 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 183 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 184 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 185 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 186 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 187 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 188 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 189 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 190 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 191 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 192 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 193 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 194 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 195 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 196 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 197 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 198 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 199 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 200 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 201 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 202 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 203 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 204 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 205 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 206 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 207 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 208 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 209 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 210 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 211 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 212 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 213 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 214 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 215 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 216 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 217 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 218 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 219 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 220 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 221 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 222 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 223 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 224 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 225 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 226 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 227 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 228 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 229 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 230 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 231 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 232 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 233 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 234 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 235 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 236 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 237 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 238 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 239 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 240 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 241 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 242 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 243 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 244 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 245 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 246 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 247 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 248 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 249 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 250 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 251 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 252 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 253 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 254 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 255 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 256 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 257 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 258 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 259 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 260 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 261 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 262 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 263 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 264 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 265 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 266 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 267 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 268 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 269 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 270 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 271 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 272 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 273 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 274 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 275 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 276 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 277 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 278 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 279 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 280 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 281 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 282 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 283 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 284 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 285 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 286 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 287 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 288 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 289 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 290 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 291 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 292 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 293 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 294 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 295 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 296 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 297 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 298 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 299 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 300 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 301 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 302 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 303 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 304 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 305 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 306 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 307 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 308 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 309 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 310 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 311 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 312 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 313 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 314 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 315 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 316 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 317 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 318 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 319 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 320 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 321 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 322 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 323 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 324 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 325 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 326 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 327 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 328 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 329 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 330 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 331 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 332 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 333 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 334 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 335 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 336 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 337 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 338 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 339 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 340 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 341 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 342 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 343 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 344 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 345 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 346 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 347 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 348 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 349 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 350 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 351 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 352 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 353 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 354 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 355 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 356 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 357 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 358 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 359 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 360 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 361 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 362 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 363 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 364 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 365 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 366 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 367 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 368 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 369 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 370 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 371 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 372 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 373 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 374 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 375 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 376 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 377 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 378 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 379 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 380 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 381 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 382 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 383 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 384 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 385 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 386 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 387 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 388 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 389 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 390 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 391 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 392 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 393 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 394 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 395 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 396 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 397 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 398 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 399 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 400 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 401 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 402 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 403 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 404 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 405 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 406 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 407 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 408 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 409 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 410 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 411 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 412 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 413 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 414 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 415 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 416 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 417 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 418 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 419 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 420 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 421 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 422 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 423 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 424 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 425 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 426 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 427 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 428 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 429 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 430 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 431 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 432 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 433 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 434 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 435 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 436 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 437 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 438 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 439 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 440 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 441 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 442 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 443 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 444 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 445 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 446 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 447 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 448 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 449 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 450 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 451 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 452 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 453 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 454 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 455 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 456 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 457 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 458 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 459 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 460 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 461 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 462 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 463 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 464 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 465 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 466 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 467 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 468 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 469 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 470 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 471 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 472 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 473 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 474 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 475 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 476 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 477 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 478 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 479 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 480 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 481 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 482 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 483 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 484 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 485 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 486 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 487 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 488 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 489 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 490 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 491 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 492 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 493 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 494 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 495 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 496 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 497 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 498 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 499 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 500 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 501 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 502 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 503 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 504 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 505 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 506 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 507 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 508 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 509 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 510 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 511 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 512 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 513 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 514 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 515 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 516 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 517 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 518 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 519 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 520 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 521 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 522 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 523 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 524 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 525 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 526 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 527 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[1, 13], deviations=2 |
| smooth | 1 | 0 | 528 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 529 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 530 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[1, 13], deviations=2 |
| smooth | 1 | 0 | 531 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 532 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 533 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[1, 13], deviations=2 |
| smooth | 1 | 0 | 534 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 535 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 536 | 108 | 31 | 71.3 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[1], deviations=1 |
| smooth | 1 | 0 | 537 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 538 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 539 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 540 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 541 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 542 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 543 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 544 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 545 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 546 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 547 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 548 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 549 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 550 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 551 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 552 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 553 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 554 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 555 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 556 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 557 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 558 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 559 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 560 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 561 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 562 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 563 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 564 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 565 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 566 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 567 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 568 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 569 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 570 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 571 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 572 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 573 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 574 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 575 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 576 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 577 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 578 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 579 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 580 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 581 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 582 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 583 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 584 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 585 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 586 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 587 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 588 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 589 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 590 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 591 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 592 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 593 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 594 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 595 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 596 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 597 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 598 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 599 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 600 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 601 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 602 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 603 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 604 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 605 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 606 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 607 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 608 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 609 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 610 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 611 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 612 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 613 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 614 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 615 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 616 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 617 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 618 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 619 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 620 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 621 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 622 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 623 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 624 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 625 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 626 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 627 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 628 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 629 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 630 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 631 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 632 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 633 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 634 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 635 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 636 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 637 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 638 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 639 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 640 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 641 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 642 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 643 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 644 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 645 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 646 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 647 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 648 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 649 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 650 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 651 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 652 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 653 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 654 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 655 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 656 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 657 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 658 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 659 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 660 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 661 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 662 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 663 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 664 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 665 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 666 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 667 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 668 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 669 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 670 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 671 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 672 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 673 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 674 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 675 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 676 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 677 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 678 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 679 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 680 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 681 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 682 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 683 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 684 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 685 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 686 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 687 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 688 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 689 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 690 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 691 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 692 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 693 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 694 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 695 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 696 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 697 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 698 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 699 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 700 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 701 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 702 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 703 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 704 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 705 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 706 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 707 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 708 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 709 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 710 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 711 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 712 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 713 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 714 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 715 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 716 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 717 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 718 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 719 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 720 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 721 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 722 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 723 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 724 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 725 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 726 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 727 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 728 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 729 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 730 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 731 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 732 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 733 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 734 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 735 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 736 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 737 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 738 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 739 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 740 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 741 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 742 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 743 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 744 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 745 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 746 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 747 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 748 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 749 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 750 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 751 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 752 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 753 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 754 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 755 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 756 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 757 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 758 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 759 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 760 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 761 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 762 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 763 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 764 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 765 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 766 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 767 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 768 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 769 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 770 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 771 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 772 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 773 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 774 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 775 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 776 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 777 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 778 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 779 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 780 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 781 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 782 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 783 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 784 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 785 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 786 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 787 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 788 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 789 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 790 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 791 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 792 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 793 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 794 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 795 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 796 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 797 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 798 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 799 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 800 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 801 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 802 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 803 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 804 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 805 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 806 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 807 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 808 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 809 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 810 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 811 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 812 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 813 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 814 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 815 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 816 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 817 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 818 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 819 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 820 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 821 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 822 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 823 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 824 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 825 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 826 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 827 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 828 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 829 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 830 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 831 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 832 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 833 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 834 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 835 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 836 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 837 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 838 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 839 | 108 | 31 | 71.3 | attempted |  |  |
| smooth | 1 | 0 | 840 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 841 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 842 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 843 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 844 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 845 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 846 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 847 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 848 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 849 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 850 | 108 | 36 | 66.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| smooth | 1 | 0 | 851 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 0 | 852 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 0 | 853 | 108 | 32 | 70.4 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 0 | 854 | 108 | 33 | 69.4 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 0 | 855 | 108 | 34 | 68.5 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| extreme_ramp | 1 | 1 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 2 | 1 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 2 | 2 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 2 | 3 | 108 | 35 | 67.6 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 2 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 3 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 4 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 5 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 6 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 7 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 8 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 9 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 10 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 11 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 12 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 13 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 14 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 15 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 16 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 17 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 18 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 19 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 20 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 21 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 22 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 23 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 24 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 25 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 26 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 27 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 28 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 29 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 30 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 31 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 32 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 33 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 34 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 35 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 36 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 37 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 38 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 39 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 40 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 41 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 42 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 43 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 44 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 45 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 46 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 47 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 48 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 49 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 50 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 51 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 52 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 53 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 54 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 55 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 56 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 57 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 58 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 59 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 60 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 61 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 62 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 63 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 64 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 65 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 66 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 67 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 68 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 69 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 70 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 71 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 72 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 73 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 74 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 75 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 76 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 77 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 78 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 79 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 80 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 81 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 82 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 83 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 84 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 85 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 86 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 87 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 88 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 89 | 108 | 34 | 68.5 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[1, 29, 30], deviations=3 |
| extreme_ramp | 1 | 0 | 90 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 91 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 92 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 93 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 94 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 95 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 96 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 97 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 98 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 99 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 100 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 101 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 102 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 103 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 104 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 105 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 106 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 107 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 108 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 109 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 110 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 111 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 112 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 113 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 114 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 115 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 116 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 117 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 118 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 119 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 120 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 121 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 122 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 123 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 124 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 125 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 126 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 127 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 128 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 129 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 130 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 131 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 132 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 133 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 134 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 135 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 136 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 137 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 138 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 139 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 140 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 141 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 142 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 143 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 144 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 145 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 146 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 147 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 148 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 149 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 150 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 151 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 152 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 153 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 154 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 155 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 156 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 157 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 158 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 159 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 160 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 161 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 162 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 163 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 164 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 165 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 166 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 167 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 168 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 169 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 170 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 171 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 172 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 173 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 174 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 175 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 176 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 177 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 178 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 179 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 180 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 181 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 182 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 183 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 184 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 185 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 186 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 187 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 188 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 189 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 190 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 191 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 192 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 193 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 194 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 195 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 196 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 197 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 198 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 199 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 200 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 201 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 202 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 203 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 204 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 205 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 206 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 207 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 208 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 209 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 210 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 211 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 212 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 213 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 214 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 215 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 216 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 217 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 218 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 219 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 220 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 221 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 222 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 223 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 224 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 225 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 226 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 227 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 228 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 229 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 230 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 231 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 232 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 233 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 234 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 235 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 236 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 237 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 238 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 239 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 240 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 241 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 242 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 243 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 244 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 245 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 246 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 247 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 248 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 249 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 250 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 251 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 252 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 253 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 254 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 255 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 256 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 257 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 258 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 259 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 260 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 261 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 262 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 263 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 264 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 265 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 266 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 267 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 268 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 269 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 270 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 271 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 272 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 273 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 274 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 275 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 276 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 277 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 278 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 279 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 280 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 281 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 282 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 283 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 284 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 285 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 286 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 287 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 288 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 289 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 290 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 291 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 292 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 293 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 294 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 295 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 296 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 297 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 298 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 299 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 300 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 301 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 302 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 303 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 304 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 305 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 306 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 307 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 308 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 309 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 310 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 311 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 312 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 313 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 314 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 315 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 316 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 317 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 318 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 319 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 320 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 321 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 322 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 323 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 324 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 325 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 326 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 327 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 328 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 329 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 330 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 331 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 332 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 333 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 334 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 335 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 336 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 337 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 338 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 339 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 340 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 341 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 342 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 343 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 344 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 345 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 346 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 347 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 348 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 349 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 350 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 351 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 352 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 353 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 354 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 355 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 356 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 357 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 358 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 359 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 360 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 361 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 362 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 363 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 364 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 365 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 366 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 367 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 368 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 369 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 370 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 371 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 372 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 373 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 374 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 375 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 376 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 377 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 378 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 379 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 380 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 381 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 382 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 383 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 384 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 385 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 386 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 387 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 388 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 389 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 390 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 391 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 392 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 393 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 394 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 395 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 396 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 397 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 398 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 399 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 400 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 401 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 402 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 403 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 404 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 405 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 406 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 407 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 408 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 409 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 410 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 411 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 412 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 413 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 414 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 415 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 416 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 417 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 418 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 419 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 420 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 421 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 422 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 423 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 424 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 425 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 426 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 427 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 428 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 429 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 430 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 431 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 432 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 433 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 434 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 435 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 436 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 437 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 438 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 439 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 440 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 441 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 442 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 443 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 444 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 445 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 446 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 447 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 448 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 449 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 450 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 451 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 452 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 453 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 454 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 455 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 456 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 457 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 458 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 459 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 460 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 461 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 462 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 463 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 464 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 465 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 466 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 467 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 468 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 469 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 470 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 471 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 472 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 473 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 474 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 475 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 476 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 477 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 478 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 479 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 480 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 481 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 482 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 483 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 484 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 485 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 486 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 487 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 488 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 489 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 490 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 491 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 492 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 493 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 494 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 495 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 496 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 497 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 498 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 499 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 500 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 501 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 502 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 503 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 504 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 505 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 506 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 507 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 508 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 509 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 510 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 511 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 512 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 513 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 514 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 515 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 516 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 517 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 518 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 519 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 520 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 521 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 522 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 523 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 524 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 525 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 526 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 527 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 528 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 529 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 530 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 531 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 532 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 533 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 534 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 535 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 536 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 537 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 538 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 539 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 540 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 541 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 542 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 543 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 544 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 545 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 546 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 547 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 548 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 549 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 550 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 551 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 552 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 553 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 554 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 555 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 556 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 557 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 558 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 559 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 560 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 561 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 562 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 563 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 564 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 565 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 566 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 567 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 568 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 569 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 570 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 571 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 572 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 573 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 574 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 575 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 576 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 577 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 578 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 579 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 580 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 581 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 582 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 583 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 584 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 585 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 586 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 587 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 588 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 589 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 590 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 591 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 592 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 593 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 594 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 595 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 596 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 597 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 598 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 599 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 600 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 601 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 602 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 603 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 604 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 605 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 606 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 607 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 608 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 609 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 610 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 611 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 612 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 613 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 614 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 615 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 616 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 617 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 618 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 619 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 620 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 621 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 622 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 623 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 624 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 625 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 626 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 627 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 628 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 629 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 630 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 631 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 632 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 633 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 634 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 635 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 636 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 637 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 638 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 639 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 640 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 641 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 642 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 643 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 644 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 645 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 646 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 647 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 648 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 649 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 650 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 651 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 652 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 653 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 654 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 655 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 656 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 657 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 658 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 659 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 660 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 661 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 662 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 663 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 664 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 665 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 666 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 667 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 668 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 669 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 670 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 671 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 672 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 673 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 674 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 675 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 676 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 677 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 678 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 679 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 680 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 681 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 682 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 683 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 684 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 685 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 686 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 687 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 688 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 689 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 690 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 691 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 692 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 693 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 694 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 695 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 696 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 697 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 698 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 699 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 700 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 701 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 702 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 703 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 704 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 705 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 706 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 707 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 708 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 709 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 710 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 711 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 712 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 713 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 714 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 715 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 716 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 717 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 718 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 719 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 720 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 721 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 722 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 723 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 724 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 725 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 726 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 727 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 728 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 729 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 730 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 731 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 732 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 733 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 734 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 735 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 736 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 737 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 738 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 739 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 740 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 741 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 742 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 743 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 744 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 745 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 746 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 747 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 748 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 749 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 750 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 751 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 752 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 753 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 754 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 755 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 756 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 757 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 758 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 759 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 760 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 761 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 762 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 763 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 764 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 765 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 766 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 767 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 768 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 769 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 770 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 771 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 772 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 773 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 774 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 775 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 776 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 777 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 778 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 779 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 780 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 781 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 782 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 783 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 784 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 785 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 786 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 787 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 788 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 789 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 790 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 791 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 792 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 793 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 794 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 795 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 796 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 797 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 798 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 799 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 800 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 801 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 802 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 803 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 804 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 805 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 806 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 807 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 808 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 809 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 810 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 811 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 812 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 813 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 814 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 815 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 816 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 817 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 818 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 819 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 820 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 821 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 822 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 823 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 824 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 825 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 826 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 827 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 828 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 829 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 830 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 831 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 832 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 833 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 834 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 835 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 836 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 837 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 838 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 839 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 840 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 841 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 842 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 843 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 844 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 845 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 846 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 847 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 848 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 849 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 850 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 851 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 852 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 853 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 854 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 855 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 856 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 857 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 858 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 859 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 860 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 861 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 862 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 863 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 864 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 865 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 866 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 867 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 868 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 869 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 870 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 871 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 872 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 873 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 874 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 875 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 876 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 877 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 878 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 879 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 880 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 881 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 882 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 883 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 884 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 885 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 886 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 887 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 888 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 889 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 890 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 891 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 892 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 893 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 894 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 895 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 896 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 897 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 898 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 899 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 900 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 901 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 902 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 903 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 904 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 905 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 906 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 907 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 908 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 909 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 910 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 911 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 912 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 913 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 914 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 915 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 916 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 917 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 918 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 919 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 920 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 921 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 922 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 923 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 924 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 925 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 926 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 927 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 928 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 929 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 930 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 931 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 932 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 933 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 934 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 935 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 936 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 937 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 938 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 939 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 940 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 941 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 942 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 943 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 944 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 945 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 946 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 947 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 948 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 949 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 950 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 951 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 952 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 953 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 954 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 955 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 956 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 957 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 958 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 959 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 960 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 961 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 962 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 963 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 964 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 965 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 966 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 967 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 968 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 969 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 970 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 971 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 972 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 973 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 974 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 975 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 976 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 977 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 978 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 979 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 980 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 981 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 982 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 983 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 984 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 985 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 986 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 987 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 988 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 989 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 990 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 991 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 992 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 993 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 994 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 995 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 996 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 997 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 998 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 999 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1000 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1001 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1002 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1003 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1004 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1005 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1006 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1007 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1008 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1009 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1010 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1011 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1012 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1013 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1014 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1015 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1016 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1017 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1018 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1019 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1020 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1021 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1022 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1023 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1024 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1025 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1026 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1027 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1028 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1029 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1030 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1031 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1032 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1033 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1034 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1035 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1036 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1037 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1038 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1039 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1040 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1041 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1042 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1043 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1044 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1045 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1046 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1047 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1048 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1049 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1050 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1051 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1052 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1053 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1054 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1055 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1056 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1057 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1058 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1059 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1060 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1061 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1062 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1063 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1064 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1065 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1066 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1067 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1068 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1069 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1070 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1071 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1072 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1073 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1074 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1075 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1076 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1077 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1078 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1079 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1080 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1081 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1082 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1083 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1084 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1085 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1086 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1087 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1088 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1089 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1090 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1091 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1092 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1093 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1094 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1095 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1096 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1097 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1098 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1099 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1100 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1101 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1102 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1103 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1104 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1105 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1106 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1107 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1108 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1109 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1110 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1111 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1112 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1113 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1114 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1115 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1116 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1117 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1118 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1119 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1120 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1121 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1122 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1123 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1124 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1125 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1126 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1127 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1128 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1129 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1130 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1131 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1132 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1133 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1134 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1135 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1136 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1137 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1138 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1139 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1140 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1141 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1142 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1143 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1144 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1145 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1146 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1147 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1148 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1149 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1150 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1151 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1152 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1153 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1154 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1155 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1156 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1157 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1158 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1159 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1160 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1161 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1162 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1163 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1164 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1165 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1166 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1167 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1168 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1169 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1170 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1171 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1172 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1173 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1174 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1175 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1176 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1177 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1178 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1179 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1180 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1181 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1182 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1183 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1184 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1185 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1186 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1187 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1188 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1189 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1190 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1191 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1192 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1193 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1194 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1195 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1196 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1197 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1198 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1199 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1200 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1201 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1202 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1203 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1204 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1205 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1206 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1207 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1208 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1209 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1210 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1211 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1212 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1213 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1214 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1215 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1216 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1217 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1218 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1219 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1220 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1221 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1222 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1223 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1224 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1225 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1226 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1227 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1228 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1229 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1230 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1231 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1232 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1233 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1234 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1235 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1236 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1237 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1238 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1239 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1240 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1241 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1242 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1243 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1244 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1245 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1246 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1247 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1248 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1249 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1250 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1251 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1252 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1253 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1254 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1255 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1256 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1257 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1258 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1259 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1260 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1261 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1262 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1263 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1264 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1265 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1266 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1267 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1268 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1269 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1270 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1271 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1272 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1273 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1274 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1275 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1276 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1277 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1278 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1279 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1280 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1281 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1282 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1283 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1284 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1285 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1286 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1287 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1288 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1289 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1290 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1291 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1292 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1293 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1294 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1295 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1296 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1297 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1298 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1299 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1300 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1301 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1302 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1303 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1304 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1305 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1306 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1307 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1308 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1309 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1310 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1311 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1312 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1313 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1314 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1315 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1316 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1317 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1318 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1319 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1320 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1321 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1322 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1323 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1324 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1325 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1326 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1327 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1328 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1329 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1330 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1331 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1332 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1333 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1334 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1335 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1336 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1337 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1338 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1339 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1340 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1341 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1342 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1343 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1344 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1345 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1346 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1347 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1348 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1349 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1350 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1351 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1352 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1353 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1354 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1355 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1356 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1357 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1358 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1359 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1360 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1361 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1362 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1363 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1364 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1365 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1366 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1367 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1368 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1369 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1370 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1371 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1372 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1373 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1374 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1375 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1376 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1377 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1378 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1379 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1380 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1381 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1382 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1383 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1384 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1385 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1386 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1387 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1388 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1389 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1390 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1391 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1392 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1393 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1394 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1395 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1396 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1397 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1398 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1399 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1400 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1401 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1402 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1403 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1404 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1405 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1406 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1407 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1408 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1409 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1410 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1411 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1412 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1413 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1414 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1415 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1416 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1417 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1418 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1419 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1420 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1421 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1422 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1423 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1424 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1425 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1426 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1427 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1428 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1429 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1430 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1431 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1432 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1433 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1434 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1435 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1436 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1437 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1438 | 108 | 31 | 71.3 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1439 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1440 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1441 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1442 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1443 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1444 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1445 | 108 | 35 | 67.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1446 | 108 | 35 | 67.6 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1447 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1448 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1449 | 108 | 31 | 71.3 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| extreme_ramp | 1 | 0 | 1450 | 108 | 41 | 62.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1451 | 108 | 41 | 62.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1452 | 108 | 41 | 62.0 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1453 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1454 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1455 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1456 | 108 | 38 | 64.8 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1457 | 108 | 39 | 63.9 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1458 | 108 | 42 | 61.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1459 | 108 | 43 | 60.2 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1460 | 108 | 44 | 59.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1461 | 108 | 45 | 58.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1462 | 108 | 46 | 57.4 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1463 | 108 | 55 | 49.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1464 | 108 | 56 | 48.1 | completed |  | ✓ True clustered UC completed (56 virtual units) |
| extreme_ramp | 1 | 0 | 1465 | 108 | 40 | 63.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1466 | 108 | 40 | 63.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1467 | 108 | 40 | 63.0 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1468 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1469 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1470 | 108 | 31 | 71.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1471 | 108 | 38 | 64.8 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1472 | 108 | 39 | 63.9 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1473 | 108 | 42 | 61.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1474 | 108 | 43 | 60.2 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1475 | 108 | 44 | 59.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1476 | 108 | 45 | 58.3 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1477 | 108 | 46 | 57.4 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1478 | 108 | 47 | 56.5 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1479 | 108 | 48 | 55.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1480 | 108 | 49 | 54.6 | attempted |  |  |
| extreme_ramp | 1 | 0 | 1481 | 108 | 58 | 46.3 | completed |  | ✓ True clustered UC completed (58 virtual units) |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 10 | 0 | false | 0 | steady | 10 | 34 | 10.749000072479248 | OK |
| baseline | 1 | 2 | 9 | 6 | false | 0 | steady | 9 | 33 | 4.668999910354614 | OK |
| baseline | 1 | 3 | 12 | 1 | false | 0 | steady | 12 | 36 | 5.022000074386597 | OK |
| baseline | 1 | 4 | 9 | 4 | false | 0 | steady | 9 | 33 | 7.874000072479248 | OK |
| baseline | 1 | 5 | 10 | 1 | false | 0 | steady | 10 | 34 | 5.425000190734863 | OK |
| baseline | 1 | 6 | 9 | 1 | false | 0 | steady | 9 | 33 | 5.453000068664551 | OK |
| baseline | 1 | 7 | 7 | 1 | false | 0 | steady | 7 | 31 | 4.400000095367432 | OK |
| baseline | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 15.956000089645386 | OK |
| baseline | 1 | 2 | 6 | 6 | false | 0 | steady+unit_dwell | 6 | 30 | 10.963000059127808 | OK |
| baseline | 1 | 3 | 12 | 1 | false | 0 | steady | 12 | 36 | 13.601999998092651 | OK |
| baseline | 1 | 4 | 6 | 3 | false | 0 | steady | 6 | 30 | 9.38700008392334 | OK |
| baseline | 1 | 5 | 8 | 2 | false | 0 | steady | 8 | 32 | 11.671000003814697 | OK |
| baseline | 1 | 6 | 4 | 4 | false | 0 | steady+unit_dwell | 4 | 28 | 7.300999879837036 | OK |
| baseline | 1 | 7 | 12 | 1 | false | 0 | steady | 12 | 36 | 13.618000030517578 | OK |
| smooth | 1 | 1 | 7 | 0 | false | 0 | steady | 7 | 31 | 7.127000093460083 | OK |
| smooth | 1 | 2 | 2 | 4 | false | 0 | unit_dwell | 4 | 28 | 3.820000171661377 | OK |
| smooth | 1 | 3 | 12 | 7 | false | 0 | steady | 12 | 36 | 5.803999900817871 | OK |
| smooth | 1 | 4 | 10 | 2 | false | 0 | steady | 10 | 34 | 4.602999925613403 | OK |
| smooth | 1 | 5 | 12 | 7 | false | 0 | steady | 12 | 36 | 6.9070000648498535 | OK |
| smooth | 1 | 6 | 10 | 3 | false | 0 | steady | 10 | 34 | 5.020000219345093 | OK |
| smooth | 1 | 7 | 12 | 5 | false | 0 | steady | 12 | 36 | 5.7820000648498535 | OK |
| smooth | 1 | 1 | 6 | 0 | false | 0 | steady | 6 | 30 | 9.192999839782715 | OK |
| smooth | 1 | 2 | 2 | 5 | false | 0 | unit_dwell | 5 | 29 | 7.74399995803833 | OK |
| smooth | 1 | 3 | 6 | 7 | false | 0 | unit_dwell | 7 | 31 | 14.417999982833862 | OK |
| smooth | 1 | 4 | 2 | 4 | false | 0 | unit_dwell | 4 | 28 | 8.849999904632568 | OK |
| smooth | 1 | 5 | 6 | 6 | false | 0 | steady+unit_dwell | 6 | 30 | 10.570000171661377 | OK |
| smooth | 1 | 6 | 2 | 4 | false | 0 | unit_dwell | 4 | 28 | 6.015000104904175 | OK |
| smooth | 1 | 7 | 6 | 3 | false | 0 | steady | 6 | 30 | 11.611999988555908 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 18.111000061035156 | OK |
| extreme_ramp | 1 | 2 | 7 | 4 | true | 12 | ramp | 12 | 36 | 5.226999998092651 | OK |
| extreme_ramp | 1 | 3 | 11 | 0 | true | 12 | ramp | 12 | 36 | 5.677999973297119 | OK |
| extreme_ramp | 1 | 4 | 10 | 5 | true | 12 | ramp | 12 | 36 | 5.621999979019165 | OK |
| extreme_ramp | 1 | 5 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 6.331000089645386 | OK |
| extreme_ramp | 1 | 6 | 7 | 2 | true | 12 | ramp | 12 | 36 | 8.89900016784668 | OK |
| extreme_ramp | 1 | 7 | 11 | 0 | true | 12 | ramp | 12 | 36 | 6.765000104904175 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 64.01999998092651 | OK |
| extreme_ramp | 1 | 2 | 7 | 4 | true | 12 | ramp | 12 | 36 | 72.33699989318848 | OK |
| extreme_ramp | 1 | 3 | 11 | 0 | true | 12 | ramp | 12 | 36 | 58.66700005531311 | OK |
| extreme_ramp | 1 | 4 | 10 | 6 | true | 12 | ramp | 12 | 36 | 98.82100009918213 | OK |
| extreme_ramp | 1 | 5 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 313.38899993896484 | OK |
| extreme_ramp | 1 | 6 | 8 | 5 | true | 12 | ramp | 12 | 36 | 69.52900004386902 | OK |
| extreme_ramp | 1 | 7 | 11 | 0 | true | 12 | ramp | 12 | 36 | 287.65499997138977 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

