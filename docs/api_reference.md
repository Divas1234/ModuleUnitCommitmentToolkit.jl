# API Reference

This reference summarizes the public data-loading and solve interfaces for `ModuleUnitCommitmentToolkit`.

## 1. Unified Solve Entry Point

The preferred entry point is `solve_uc`:

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    data_file = "data/data.xlsx",
)
```

The public result object is `UCSolveResult`. Stable fields include:

```julia
result.algorithm
result.input
result.output_dir
result.status
result.details
```

Algorithm-specific information is available through `result.details` or direct properties when present. Use `hasproperty(result, :field_name)` before depending on optional fields.

## 2. Request Object

For batch jobs, services, or reproducible experiments, construct a request explicitly:

```julia
request = UCSolveRequest(
    algorithm = :benders,
    input = :powersystems,
    case_name = :ieee30,
    scenario_limit = 1,
    horizon = 24,
)
result = solve_uc(request)
```

`algorithm` accepts `:benchmark`, `:benders`, and `:ccg`. String aliases such as `"extensive-form"` normalize to `:benchmark`. `input` accepts `:excel`, `:powersystems`, and `:powersystems_csv`.

## 3. Data Sources

### Excel

Use `input = :excel` with `data_file`:

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    data_file = "data/data.xlsx",
)
```

### Native PowerSystems System

Use an existing `PowerSystems.System` object:

```julia
sys = build_system_from_powersystems(:ieee30)
result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems,
    sys = sys,
    scenario_limit = 1,
    horizon = 24,
)
```

### Curated PowerSystems Case

Use a stable alias:

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems,
    case_name = :ieee118,
    scenario_limit = 1,
    horizon = 24,
)
```

Supported curated aliases include `:ieee6`, `:ieee14`, `:ieee24`, `:ieee30`, `:ieee118`, `:c_sys5_all_components`, `:rts_gmlc`, `:activsg2000`, and `:activsg10k`. The `:ieee118` alias is backed by the `PowerSystemsTestData/118-Bus` artifact in the installed dependency. Local `.m`, `.raw`, or other PowerSystems-readable files can still be passed as paths.

`sys` and `case_name` are mutually exclusive. If `sys` is provided and `case_dir == ""`, the native PowerSystems bridge is used without extension CSV files.

### PowerSystems with Extension CSV Files

Use `input = :powersystems_csv` with both `sys` and `case_dir` when custom project tables are required:

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems_csv,
    sys = sys,
    case_dir = "data/powersystems_case",
)
```

The `case_dir` mode requires at least `thermal_uc.csv`. Optional model components require their corresponding extension tables, such as `data_centers.csv` and `data_center_workloads.csv`.

## 4. Frequency Parameters

Frequency parameters can be provided as dictionaries keyed by unit name or as legacy matrices. A conventional-unit record uses:

```julia
(H = 5.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05)
```

Wind units use:

```julia
(Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0)
```

`Fcmode >= 0.5` enables virtual inertia/damping mode. Use nonzero droop values for units that do not participate in primary response to avoid division-by-zero during frequency fitting.

## 5. Data Centers

A data-center record requires a `bus` and `p_max`. Optional fields include `p_min`, `idle_power`, `server_energy`, `lambda`, `mu`, `workload`, and `voltage_regulation`:

```julia
data_centers = [(
    bus = 5,
    p_max = 20.0,
    p_min = 0.0,
    idle_power = 1.0,
    server_energy = 0.05,
    lambda = 1.0,
    mu = 1.0,
    workload = fill(0.10, 24),
)]
```

Native PowerSystems components are already on `SYSTEM_BASE` per unit and are passed through directly. Extra data-center parameters are entered in MW and converted by the bridge.

## 6. `load_uc_data`

`load_uc_data` returns a named tuple with stable fields such as `config_param`, `units`, `loads`, `winds`, `network`, `data_centers`, `NB`, `NG`, `NL`, `ND`, `NT`, `ND2`, `NW`, and `NS`.

Power quantities inside the model structures are generally per unit. PowerSystems components use their existing system base; external MW fields are converted only at the corresponding extension entry point.

## 7. Compatibility Interfaces

New application code should prefer `solve_uc`. Lower-level algorithm interfaces remain available for debugging model internals:

| Command | Purpose |
|---|---|
| `julia --project=. tools/benchmark/run_algorithm_comparison.jl` | Compare Benchmark, Benders, and CCG runs. |
| `julia --project=. tools/benders/driver.jl` | Run Benders directly. |
| `julia --project=. tools/ccg/driver.jl` | Run CCG directly. |
| `julia --project=. examples/unified_api/04_powersystems_native.jl` | Run the unified PowerSystems example. |
| `julia --project=. examples/powersystems_algorithms_demo.jl` | Run the lower-level PowerSystems algorithm demo. |
| `julia --project=. test/runtests.jl` | Run lightweight tests. |
| `./gui/start.sh` | Start the local dashboard. |

`tools/benders/setup.jl` returns a named `BendersSetup`. Legacy 20-element destructuring is still supported for migration, but new code should use named fields.

## 8. Runtime Configuration

Runtime configuration can be supplied through `config/runtime_config.toml`, environment variables, the `calibration` request field, or dedicated function arguments. Boolean values are normalized to `0` or `1` for environment-backed configuration during a solve.

Common parameters include:

| Scope | Parameter | Purpose |
|---|---|---|
| Model | `MODEL_CONSIDER_BESS` | Enable storage constraints. |
| Model | `MODEL_CONSIDER_FREQUENCY_CONTROL` | Enable frequency constraints. |
| Model | `MODEL_CONSIDER_DATA_CENTER` | Enable data-center constraints. |
| Benchmark | `BENCHMARK_UC_USE_DRO` | Use DRO scenario probabilities. |
| Benders | `BENDERS_MAX_ITERATIONS` | Maximum decomposition iterations. |
| CCG | `CCG_INITIAL_SCENARIOS` | Initial number of active scenarios. |
| CCG | `CCG_SCENARIOS_PER_ITERATION` | Scenarios added per iteration. |
| CCG | `CCG_MAX_ITERATIONS` | Maximum CCG iterations. |
| CCG | `CCG_GAP_TOL` | Convergence-gap tolerance. |

## 9. Output Paths

Algorithm output defaults to `<project>/output/`. Override the base directory with `MODULE_UC_OUTPUT_DIR` or `output_dir`. Relative paths are resolved from the project root. Use `MODULE_UC_RUN_ID` to set a deterministic run ID. Benchmark and CCG scheduling files are usually written under `<output_dir>/<algorithm>/<run_id>/scheduling/`.
