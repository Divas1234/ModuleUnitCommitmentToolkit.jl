# Benders vs CCG Benchmark Report

- Run id: `20260606_221948`
- Generated at: `2026-06-06 22:20:05`
- Scenario counts: `2, 6`
- Benders max iterations: `10000`
- CCG max iterations: `50`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benders | 2 | converged | 27 | 277019.25819701015 | 277181.0248636769 | 0.0005836137836121921 | 8.75 | 1273.14 |
| ccg | 2 | completed | 1 | 108813.97463349011 | 184827.04618505063 | 0.41126595441580677 | 3.392 | 1073.31 |
| benders | 6 | converged | 36 | 362530.5531250027 | 362816.65312500286 | 0.0007885525582553441 | 2.304 | 1224.59 |
| ccg | 6 | completed | 3 | 120005.85583163926 | 144403.10936546465 | 0.16895241134946967 | 1.425 | 1250.41 |

## Figures

- Gap convergence: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_221948/gap_convergence.svg`
- Runtime comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_221948/runtime_seconds.svg`
- RAM comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_221948/ram_mb.svg`

## Interpretation

- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.
- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.
- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.
