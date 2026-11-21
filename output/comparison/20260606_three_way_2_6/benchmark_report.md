# Benchmark UC vs Benders vs CCG Report

- Run id: `20260606_three_way_2_6`
- Generated at: `2026-06-06 22:29:25`
- Scenario counts: `2, 6`
- Benders max iterations: `10000`
- CCG max iterations: `50`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benchmark_uc | 2 | OPTIMAL | 1 | 116557.50639980531 | 116557.50639980531 | 0.0 | 4.857 | 1529.84 |
| benders | 2 | bound_inconsistency | 24 | 211053.65309007664 | -4.347830463963848e6 | 1.0485422913423845 | 4.178 | 1439.3 |
| ccg | 2 | converged | 1 | 97739.11377165276 | 1.1803261478959722e6 | 0.9171931300964585 | 1.186 | 1272.91 |
| benchmark_uc | 6 | OPTIMAL | 1 | 121002.02928230038 | 121002.02928230038 | 0.0 | 0.381 | 1369.92 |
| benders | 6 | converged | 14 | 283159.549615424 | 283344.1140720723 | 0.0006513791798784707 | 0.451 | 1384.81 |
| ccg | 6 | converged | 3 | 130129.33905779924 | 153630.04960716635 | 0.15296949138079238 | 1.237 | 1391.97 |

## Figures

- Gap convergence: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_2_6/gap_convergence.svg`
- Runtime comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_2_6/runtime_seconds.svg`
- RAM comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_2_6/ram_mb.svg`
- Power-balance sample: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_2_6/power_balance_sample.svg`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_2_6/power_balance_quality.csv`

## Interpretation

- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.
- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.
- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.
- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.
