# Benders vs CCG Benchmark Report

- Run id: `20260606_222120_scaling_20_50`
- Generated at: `2026-06-06 22:23:02`
- Scenario counts: `20, 50`
- Benders max iterations: `5`
- CCG max iterations: `5`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benders | 20 | maximum_iterations | 5 | 143743.5426190488 | 1.1419848426191038e6 | 0.874128327053578 | 7.348 | 1341.92 |
| ccg | 20 | maximum_iterations | 5 | 127019.69969765439 | 156092.51437034868 | 0.18625374054472088 | 6.185 | 1582.67 |
| benders | 50 | maximum_iterations | 5 | 285654.4484530236 | 1.1307980687078128e6 | 0.7473868621121768 | 1.013 | 1676.89 |
| ccg | 50 | maximum_iterations | 5 | 132508.79931162065 | 150707.30862599745 | 0.12075399315515845 | 4.957 | 1696.84 |

## Figures

- Gap convergence: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120_scaling_20_50/gap_convergence.svg`
- Runtime comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120_scaling_20_50/runtime_seconds.svg`
- RAM comparison: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120_scaling_20_50/ram_mb.svg`
- Power-balance sample: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120_scaling_20_50/power_balance_sample.svg`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260606_222120_scaling_20_50/power_balance_quality.csv`

## Interpretation

- Benders evaluates all scenario subproblems in each iteration; its RAM and runtime usually grow with the full scenario count.
- CCG starts from a subset and adds worst uncovered scenarios, so its early iterations are typically lighter but may stop with a larger gap if the iteration cap is tight.
- Power-balance CSV files report load, served load, thermal generation, available/used wind, curtailment, storage charge/discharge, and residual balance error by scenario and time period.
