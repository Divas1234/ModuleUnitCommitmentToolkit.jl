# Overlap Criteria Combination Comparison

- Archive batch: `output/archive/pcm_ieee6_criteria_20260808_211327`
- Generated: `2026-08-08 21:15:13`
- Operational solve time uses `SubproblemSolveTime_sec`; offline training/calibration and local reference solves are retained as excluded fields.

## Consolidated Performance

| Scenario | Mode | Cost USD | Gap vs All % | Solve s | Memory MB | Avg overlap h | Load shedding | Wind curtailment |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| ieee6 | NoOverlap | 264103.20 | -0.7482 | 0.51 | 125.64 | 0.00 | 0.00 | 13.70 |
| ieee6 | SteadyOnly | 266094.17 | 0.0000 | 0.81 | 138.66 | 8.86 | 0.00 | 13.51 |
| ieee6 | UnitOnly | 264356.14 | -0.6532 | 0.66 | 101.64 | 2.00 | 0.00 | 13.56 |
| ieee6 | RampOnly | 264314.95 | -0.6686 | 0.70 | 114.84 | 4.57 | 0.00 | 13.55 |
| ieee6 | Steady+Unit | 266094.17 | 0.0000 | 0.84 | 138.67 | 8.86 | 0.00 | 13.51 |
| ieee6 | Steady+Ramp | 266094.17 | 0.0000 | 0.83 | 139.28 | 9.00 | 0.00 | 13.51 |
| ieee6 | Unit+Ramp | 264314.95 | -0.6686 | 0.75 | 114.33 | 4.57 | 0.00 | 13.55 |
| ieee6 | Steady+Unit+Ramp | 266094.17 | 0.0000 | 0.80 | 139.28 | 9.00 | 0.00 | 13.51 |

## Cross-Scenario Charts

## Detailed Files

- `criteria_comparison_all_scenarios.csv`
