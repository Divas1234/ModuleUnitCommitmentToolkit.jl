# Runtime Configuration

The runtime parameters used by Benders, CCG, Wasserstein DRO, boundary reporting, and tests are centralized in:

```text
config/runtime_config.toml
```

Both `tools/benders/driver.jl` and `tools/ccg/driver.jl` load this file before reading environment variables.

## Precedence

Configuration values are applied in this order:

1. Shell environment variables already set by the user.
2. Values from `config/runtime_config.toml`.
3. Hard-coded fallback defaults in individual functions.

This means shell variables can temporarily override the config file:

```bash
BENDERS_SCENARIO_LIMIT=5 julia tools/benders/driver.jl
```

For normal use, edit `config/runtime_config.toml` directly:

```toml
[benders]
BENDERS_SCENARIO_LIMIT = 20
BENDERS_MAX_ITERATIONS = 180

[ccg]
CCG_SCENARIO_LIMIT = 20
CCG_MAX_ITERATIONS = 20

[dro]
CCG_DRO_ENABLED = true
CCG_DRO_RADIUS = 0.05
```

## Alternate Config File

Use `MODULE_UC_CONFIG_FILE` to load another TOML file:

```bash
MODULE_UC_CONFIG_FILE=config/runtime_config.toml julia tools/ccg/driver.jl
```

Set `MODULE_UC_CONFIG_VERBOSE=1` to print which variables were applied or preserved:

```bash
MODULE_UC_CONFIG_VERBOSE=1 julia tools/benders/driver.jl
```

## Common Sections

| Section | Purpose |
|---|---|
| `[boundary]` | Terminal system summary and Unicode plot controls. |
| `[common]` | Shared runtime flags. |
| `[model]` | SCUC `config` structure fields, including model switches and penalty coefficients. |
| `[benders]` | Benders scenario count, iteration limits, direct solve mode, and solver defaults. |
| `[benders.cuts]` | Benders cut mode, cut tolerances, and logic cut controls. |
| `[benders.subproblems]` | Parallel subproblem and dual collection controls. |
| `[ccg]` | CCG scenario count, iteration limits, solver gap, and threading. |
| `[dro]` | Wasserstein DRO enable flag, radius, and distance power. |
| `[test]` | Test environment controls. |

## Disable Boundary Report

The drivers print imported system statistics by default. Disable this when running large benchmark batches:

```toml
[boundary]
PRINT_BOUNDARY_CONDITION = false
BOUNDARY_SHOW_PLOTS = false
```

## Model Configuration

The `[model]` section maps directly to the `config` struct in `src/input_data/formatted_data.jl`.

| TOML key | Struct field |
|---|---|
| `MODEL_IS_NETWORK_CON` | `is_NetWorkCon` |
| `MODEL_IS_THERMAL_UNIT_CON` | `is_ThermalUnitCon` |
| `MODEL_IS_WIND_UNIT_CON` | `is_WindUnitCon` |
| `MODEL_IS_SYSTEM_CON` | `is_SysticalCon` |
| `MODEL_IS_PIECE_LINEAR` | `is_PieceLinear` |
| `MODEL_NUM_SEGMENTS` | `is_NumSeg` |
| `MODEL_ALPHA` | `is_Alpha` |
| `MODEL_BETA` | `is_Belta` |
| `MODEL_COAL_PRICE` | `is_CoalPrice` |
| `MODEL_IS_ACTIVE_LOAD` | `is_ActiveLoad` |
| `MODEL_IS_WIND_INTEGRATION` | `is_WindIntegration` |
| `MODEL_LOAD_CUTTING_COEFFICIENT` | `is_LoadsCuttingCoefficient` |
| `MODEL_WIND_CUTTING_COEFFICIENT` | `is_WindsCuttingCoefficient` |
| `MODEL_MAX_ITERATIONS_NUM` | `is_MaxIterationsNum` |
| `MODEL_CALCULATION_PRECISION` | `is_CalculPrecision` |
| `MODEL_CONSIDER_DATA_CENTER` | `is_ConsiderDataCentra` |
| `MODEL_CONSIDER_FREQUENCY_CONTROL` | `is_ConsiderFrequencyControl` |
| `MODEL_CONSIDER_BESS` | `is_ConsiderBESS` |
| `MODEL_CONSIDER_MULTI_CUTS` | `is_ConsiderMultiCUTs` |
