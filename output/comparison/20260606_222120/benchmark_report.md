# Benders vs CCG Benchmark Report

- Run id: `20260606_222120`
- Generated at: `2026-06-06 22:21:34`
- Scenario counts: `2, 6`
- Benders max iterations: `10000`
- CCG max iterations: `50`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benders | 2 | converged | 27 | 277019.25819701015 | 277181.0248636769 | 0.0005836137836121921 | 7.471 | 1394.44 |
| ccg | 2 | converged | 1 | 108813.97463349011 | 184827.04618505063 | 0.41126595441580677 | 2.57 | 1234.14 |
| benders | 6 | converged | 36 | 362530.5531250027 | 362816.65312500286 | 0.0007885525582553441 | 1.796 | 1285.8 |
| ccg | 6 | converged | 3 | 120005.85583163926 | 144403.10936546465 | 0.16895241134946967 | 1.476 | 1303.91 |

## Figures

- Gap convergence: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120/gap_convergence.svg`
- Runtime comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120/runtime_seconds.svg`
- RAM comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120/ram_mb.svg`
- Power-balance sample: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120/power_balance_sample.svg`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120/power_balance_quality.csv`

## Interpretation

- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.
- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.
- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.
