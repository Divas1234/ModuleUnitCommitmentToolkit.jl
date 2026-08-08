# Criteria Combination Performance Summary

- Experiment: `ieee6`
- Scenario: `ieee6`
- Source: `D:\GithubClonefiles\module_unitcommitment\output\archive\pcm_ieee6_criteria_20260808_211327\ieee6\criteria_combination_performance.csv`
- Generated: `2026-08-08 21:15:18`

## Key Findings

- Lowest total cost: `NoOverlap` at `264103.2` USD.
- Fastest rolling simulation: `NoOverlap` at `0.51` s.
- Lowest Julia allocation: `UnitOnly` at `101.64` MB.
- Calibration time is excluded from operational runtime; reference no-boundary solve time is also reported separately when available.

## Results

| Mode | Cost USD | Gap vs All % | Gap vs Best % | Solve s | Delta vs NoOverlap s | Memory MB | Avg Overlap h | Load Shed | Wind Curtail |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| NoOverlap | 264103.2 | -0.7482 | 0.0 | 0.51 | 0.0 | 125.64 | 0.0 | 0.0 | 13.7 |
| SteadyOnly | 266094.17 | 0.0 | 0.7539 | 0.81 | 0.3 | 138.66 | 8.86 | 0.0 | 13.51 |
| UnitOnly | 264356.14 | -0.6532 | 0.0958 | 0.66 | 0.15 | 101.64 | 2.0 | 0.0 | 13.56 |
| RampOnly | 264314.95 | -0.6686 | 0.0802 | 0.7 | 0.19 | 114.84 | 4.57 | 0.0 | 13.55 |
| Steady+Unit | 266094.17 | 0.0 | 0.7539 | 0.84 | 0.33 | 138.67 | 8.86 | 0.0 | 13.51 |
| Steady+Ramp | 266094.17 | 0.0 | 0.7539 | 0.83 | 0.31 | 139.28 | 9.0 | 0.0 | 13.51 |
| Unit+Ramp | 264314.95 | -0.6686 | 0.0802 | 0.75 | 0.24 | 114.33 | 4.57 | 0.0 | 13.55 |
| Steady+Unit+Ramp | 266094.17 | 0.0 | 0.7539 | 0.8 | 0.29 | 139.28 | 9.0 | 0.0 | 13.51 |
