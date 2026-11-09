# Benders Performance Report

Date: 2026-06-06

Branch: `revised_ModuleUnitCommitmentTookits`

Commit tested: `027ccde`

## Test Setup

The Benders module was tested with different scenario limits using the same convergence settings:

```bash
BENDERS_MAX_ITERATIONS=180
BENDERS_VERBOSE_CUTS=0
```

Each run was measured with `/usr/bin/time -p`. Full raw logs are stored in `docs/benchmarks/benders/logs/`.

Example command:

```bash
/usr/bin/time -p env BENDERS_SCENARIO_LIMIT=20 BENDERS_MAX_ITERATIONS=180 BENDERS_VERBOSE_CUTS=0 julia tools/benders/driver.jl
```

## Results

| Scenarios | Iterations | Wall Time (s) | User Time (s) | Sys Time (s) | Final Upper Bound | Final Lower Bound | Final Gap | Notes |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 5 | 23 | 23.40 | 23.17 | 1.55 | 266626.22462673095 | 266626.2246267309 | 2.1831183708481095e-16 | Converged |
| 10 | 30 | 22.02 | 23.34 | 1.44 | 486300.72915864765 | 486198.20975567226 | 0.00021081482471258035 | Converged |
| 20 | 31 | 23.56 | 27.01 | 1.65 | 417773.5226718181 | 417747.72950070724 | 0.0000617396022271476 | One over-strong dual cut batch was rolled back |
| 50 | 17 | 22.54 | 25.49 | 0.87 | 489846.96484169294 | 489719.9778925395 | 0.0002592380034327641 | Converged |

## Observations

All tested scenario counts converged within the configured 180-iteration limit.

The 20-scenario case triggered the new cut rollback guard once:

```text
WARNING: Benders lower bound exceeded upper bound at iteration 28
Rolled back the last dual cut batch and added conservative integer cuts.
```

After rollback, the run continued and converged at iteration 31. This confirms the guard is active and prevents over-strong cut batches from invalidating the Benders bounds.

The 50-scenario Benders upper bound matches the extensive-form benchmark from the previous validation:

```text
Benders UB:         489846.96484169294
Extensive objective: 489846.9648416931
```

## Raw Logs

| Scenarios | Benders Log | Timing Log |
|---:|---|---|
| 5 | `docs/benchmarks/benders/logs/benders_5.log` | `docs/benchmarks/benders/logs/benders_5.time` |
| 10 | `docs/benchmarks/benders/logs/benders_10.log` | `docs/benchmarks/benders/logs/benders_10.time` |
| 20 | `docs/benchmarks/benders/logs/benders_20.log` | `docs/benchmarks/benders/logs/benders_20.time` |
| 50 | `docs/benchmarks/benders/logs/benders_50.log` | `docs/benchmarks/benders/logs/benders_50.time` |
