# Benchmark UC vs Benders vs CCG Report

- Run id: `20260712_185712_three_way_2`
- Generated at: `2026-07-12 18:57:25`
- Scenario counts: `2`
- Benders max iterations: `100`
- CCG max iterations: `10`

## Summary

| Algorithm | Scenarios | Status | Iterations | Lower bound | Upper bound | Gap | Time (s) | Max RAM (MB) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| benchmark_uc | 2 | OPTIMAL | 1 | 270042.0261676852 | 270042.0261676853 | 0.0 | 6.182 | 1874.73 |
| benders | 2 | converged | 57 | 270042.0261676852 | 270042.02616768517 | 2.1555037835891237e-16 | 6.262 | 1903.62 |
| ccg | 2 | converged | 1 | 270042.0261676852 | 270042.0261676849 | 1.2933022701534758e-15 | 0.852 | 1916.16 |

## Tables

- Summary: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_185712_three_way_2/summary.csv`
- Iteration history: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_185712_three_way_2/iteration_history.csv`
- Power-balance quality table: `/Users/yuanyiping/Documents/GitHub/02 Ongoing/module_unitcommitment-revised_ModuleUnitCommitmentTookits/output/comparison/20260712_185712_three_way_2/power_balance_quality.csv`

## Interpretation

- Benchmark UC solves the full extensive-form SCUC directly and is the reference result for objective, feasibility, runtime, and memory.
- Benders evaluates scenario subproblems under first-stage commitments; the exported scheduling files use the best incumbent dispatch reconstruction.
- CCG starts from a scenario subset and adds uncovered scenarios; its active-scenario history is recorded in `iteration_history.csv`.
- Power-balance quality reports residual balance error, load curtailment, wind curtailment, and peak served load from each algorithm's generated power-balance CSV.
