# Benchmark UC vs Benders vs CCG Report

- Run id: `20260712_183243_three_way_2`
- Generated at: `2026-07-12 18:32:55`
- Scenario counts: `2`
- Benders max iterations: `100`
- CCG max iterations: `10`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benchmark_uc | 2 | OPTIMAL | 1 | 152036.84197254595 | 152036.84197254595 | 0.0 | 6.855 | 1891.7 |
| benders | 2 | no_violated_cuts | 1 | 260.0 | 1.1510155694551012e6 | 0.9997741125247134 | 4.338 | 1743.72 |
| ccg | 2 | converged | 1 | 152036.84197254595 | 152036.84126773363 | 4.635799564295151e-9 | 1.003 | 1734.34 |

## Tables

- Summary: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183243_three_way_2/summary.csv`
- Iteration history: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183243_three_way_2/iteration_history.csv`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_183243_three_way_2/power_balance_quality.csv`

## Interpretation

- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.
- Benders evaluates scenario subproblems under first-stage commitments; the exported scheduling files use the best incumbent dispatch reconstruction.
- CCG starts from a scenario subset and adds uncovered scenarios; its active-scenario history is recorded in `iteration_history.csv`.
- Power-balance quality reports residual balance error, load curtailment, wind curtailment, and peak served load from each algorithm's generated power-balance CSV.
