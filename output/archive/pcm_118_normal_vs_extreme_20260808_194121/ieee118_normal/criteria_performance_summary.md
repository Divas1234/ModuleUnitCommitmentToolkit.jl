# Criteria Combination Performance Summary

- Experiment: `ieee118_normal`
- Scenario: `ieee118_reconstructed_load`
- Source: `D:\GithubClonefiles\module_unitcommitment\output\archive\pcm_118_normal_vs_extreme_20260808_194121\ieee118_normal\criteria_combination_performance.csv`
- Generated: `2026-08-08 19:56:33`

## Key Findings

- Lowest total cost: `Steady+Unit` at `1.399318742e7` USD.
- Fastest rolling simulation: `Steady+Unit+Ramp` at `18.09` s.
- Lowest Julia allocation: `NoOverlap` at `9525.51` MB.
- Calibration time is excluded from operational runtime; reference no-boundary solve time is also reported separately when available.

## Results

| Mode | Cost USD | Gap vs All % | Gap vs Best % | Solve s | Delta vs NoOverlap s | Memory MB | Avg Overlap h | Load Shed | Wind Curtail |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| NoOverlap | 1.40358028e7 | 0.3045 | 0.3045 | 21.28 | 0.0 | 9525.51 | 0.0 | 6.46 | 1.5 |
| SteadyOnly | 1.399618138e7 | 0.0214 | 0.0214 | 33.25 | 11.96 | 13453.17 | 4.57 | 6.46 | 0.57 |
| UnitOnly | 1.40345376e7 | 0.2955 | 0.2955 | 26.22 | 4.94 | 13337.89 | 4.43 | 6.46 | 1.64 |
| RampOnly | 1.41167421e7 | 0.883 | 0.883 | 18.7 | -2.58 | 11728.83 | 2.71 | 6.46 | 0.0 |
| Steady+Unit | 1.399318742e7 | 0.0 | 0.0 | 18.51 | -2.77 | 14271.88 | 5.43 | 6.55 | 0.41 |
| Steady+Ramp | 1.399618138e7 | 0.0214 | 0.0214 | 19.9 | -1.38 | 13453.15 | 4.57 | 6.46 | 0.57 |
| Unit+Ramp | 1.400818195e7 | 0.1072 | 0.1072 | 19.5 | -1.79 | 13597.07 | 4.71 | 6.46 | 1.84 |
| Steady+Unit+Ramp | 1.399318742e7 | 0.0 | 0.0 | 18.09 | -3.19 | 14271.88 | 5.43 | 6.55 | 0.41 |
