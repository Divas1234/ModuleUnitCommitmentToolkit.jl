# Benchmark UC vs Benders vs CCG Report

- Run id: `20260606_three_way_20_50_clean_logs_v2`
- Generated at: `2026-06-06 22:38:23`
- Scenario counts: `20, 50`
- Benders max iterations: `5`
- CCG max iterations: `5`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benchmark_uc | 20 | OPTIMAL | 1 | 129596.03713143409 | 129596.03713143409 | 0.0 | 7.788 | 1593.73 |
| benders | 20 | maximum_iterations | 5 | 121172.24657890643 | 1.139769560248672e6 | 0.8936870655210664 | 3.619 | 1518.45 |
| ccg | 20 | maximum_iterations | 5 | 124259.08710213612 | 160145.84237405038 | 0.22408796094668496 | 4.489 | 1587.22 |
| benchmark_uc | 50 | OPTIMAL | 1 | 1.109097340776581e6 | 1.109097340776581e6 | 0.0 | 10.581 | 1017.42 |
| benders | 50 | maximum_iterations | 5 | 278853.5327828358 | 1.1239284151626425e6 | 0.7518938670633795 | 1.44 | 1520.77 |
| ccg | 50 | maximum_iterations | 5 | 138350.97821158127 | 151625.9591028888 | 0.087550845315425 | 5.081 | 1755.12 |

## Figures

- Gap convergence: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_20_50_clean_logs_v2/gap_convergence.svg`
- Runtime comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_20_50_clean_logs_v2/runtime_seconds.svg`
- RAM comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_20_50_clean_logs_v2/ram_mb.svg`
- Power-balance sample: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_20_50_clean_logs_v2/power_balance_sample.svg`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_three_way_20_50_clean_logs_v2/power_balance_quality.csv`

## Interpretation

- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.
- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.
- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.
- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.
