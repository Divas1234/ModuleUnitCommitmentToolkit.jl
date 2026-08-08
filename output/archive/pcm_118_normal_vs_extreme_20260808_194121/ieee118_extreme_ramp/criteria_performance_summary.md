# Criteria Combination Performance Summary

- Experiment: `ieee118_extreme_ramp`
- Scenario: `extreme_ramp`
- Source: `D:\GithubClonefiles\module_unitcommitment\output\archive\pcm_118_normal_vs_extreme_20260808_194121\ieee118_extreme_ramp\criteria_combination_performance.csv`
- Generated: `2026-08-08 19:56:33`

## Key Findings

- Lowest total cost: `Steady+Ramp` at `1.455787875e7` USD.
- Fastest rolling simulation: `NoOverlap` at `14.96` s.
- Lowest Julia allocation: `NoOverlap` at `9525.54` MB.
- Calibration time is excluded from operational runtime; reference no-boundary solve time is also reported separately when available.

## Results

| Mode | Cost USD | Gap vs All % | Gap vs Best % | Solve s | Delta vs NoOverlap s | Memory MB | Avg Overlap h | Load Shed | Wind Curtail |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| NoOverlap | 1.513084864e7 | 3.6549 | 3.9358 | 14.96 | 0.0 | 9525.54 | 0.0 | 41.04 | 6.5 |
| SteadyOnly | 1.456513565e7 | -0.2205 | 0.0498 | 22.78 | 7.83 | 12926.46 | 4.0 | 40.53 | 3.19 |
| UnitOnly | 1.461363631e7 | 0.1117 | 0.383 | 16.89 | 1.93 | 12539.05 | 3.57 | 40.68 | 5.31 |
| RampOnly | 1.461397099e7 | 0.114 | 0.3853 | 16.32 | 1.36 | 12395.44 | 3.43 | 40.65 | 3.98 |
| Steady+Unit | 1.460610794e7 | 0.0602 | 0.3313 | 21.8 | 6.84 | 14016.98 | 5.14 | 40.56 | 2.3 |
| Steady+Ramp | 1.455787875e7 | -0.2702 | 0.0 | 21.66 | 6.71 | 13333.98 | 4.43 | 40.56 | 2.6 |
| Unit+Ramp | 1.520824319e7 | 4.1851 | 4.4674 | 19.71 | 4.76 | 13060.59 | 4.14 | 40.53 | 7.9 |
| Steady+Unit+Ramp | 1.459732514e7 | 0.0 | 0.271 | 23.72 | 8.76 | 13870.34 | 5.0 | 40.56 | 2.3 |
