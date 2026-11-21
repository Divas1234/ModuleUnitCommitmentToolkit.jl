# Benchmark UC vs Benders vs CCG Report

- Run id: `20260712_183007_three_way_2`
- Generated at: `2026-07-12 18:30:20`
- Scenario counts: `2`
- Benders max iterations: `100`
- CCG max iterations: `10`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benchmark_uc | 2 | OPTIMAL | 1 | 152036.84197254595 | 152036.84197254595 | 0.0 | 6.753 | 1774.83 |
| benders | 2 | bound_inconsistency | 24 | 210879.16820431204 | 193966.76468312196 | 0.08719227517524562 | 4.752 | 1738.25 |
| ccg | 2 | converged | 1 | 152036.84197254595 | 152036.84126773363 | 4.635799564295151e-9 | 0.99 | 1707.48 |

## Tables

- Summary: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183007_three_way_2/summary.csv`
- Iteration history: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183007_three_way_2/iteration_history.csv`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183007_three_way_2/power_balance_quality.csv`

## Interpretation

- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.
- Benders evaluates scenario subproblems under first-stage commitments; the exported scheduling files use the best incumbent dispatch reconstruction.
- CCG starts from a scenario subset and adds uncovered scenarios; its active-scenario history is recorded in `iteration_history.csv`.
- Power-balance quality reports residual balance error, load curtailment, wind curtailment, and peak served load from each algorithm's generated power-balance CSV.
