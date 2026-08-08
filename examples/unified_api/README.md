# Unified API Examples

The examples in this directory are written around the package-level unified entry points:

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    data_file = "data/data.xlsx",
)
```

Callers normally only need to choose two dispatch parameters:

| Parameter | Options | Meaning |
|---|---|---|
| `algorithm` | `:benchmark`, `:benders`, `:ccg` | Select the internal algorithm module. |
| `input` | `:excel`, `:powersystems`, `:powersystems_csv` | Select the unified data source. |

Algorithm modules are loaded lazily by `solve_uc`, so callers do not need to manage `include` order. Application code should prefer `solve_uc` or explicitly construct `UCSolveRequest`. Use the lower-level `tools/benders/setup.jl` interface only when debugging Benders intermediate models.

## Example Files

| File | Purpose | Runs optimization |
|---|---|---|
| `01_excel_single_solve.jl` | Excel data with one unified solve. | Yes |
| `02_input_spec_and_data.jl` | Load and inspect named data through `UCInputSpec`. | No |
| `03_three_algorithm_comparison.jl` | Run the three algorithms from the same data entry point. | Yes |
| `04_powersystems_native.jl` | Native PowerSystems system with data-center parameters. | Yes |
| `05_benders_named_setup.jl` | Benders named fields plus legacy destructuring compatibility. | Yes |
| `06_powersystems_case_catalog.jl` | 6/30/118-bus and larger case catalog, bridge, and optional solve. | No by default |
| `07_ieee30_frequency_datacenter_uc.jl` | IEEE 30-bus UC with frequency model and data-center attachment. | Yes by default |

Run from the repository root:

```bash
julia --project=. examples/unified_api/01_excel_single_solve.jl
```

Select another PowerSystems case with environment variables while keeping the same data-entry path:

```bash
$env:UC_CASE_NAME = "ieee118"
$env:UC_ALGORITHM = "benchmark"
julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
```

The stable aliases returned by `powersystems_case_catalog()` and `list_powersystems_cases()` include `ieee6`, `ieee14`, `ieee24`, `ieee30`, `ieee118`, `c_sys5_all_components`, `rts_gmlc`, `activsg2000`, and `activsg10k`. The 118-bus entry uses the `PowerSystemsTestData/118-Bus` asset provided by the installed dependency. External IEEE-118 files can still be passed directly as file paths.

If you test from a Julia REPL that has already loaded `ModuleUnitCommitmentToolkit`, restart Julia after changing source code. Public structs such as `UCSolveRequest` cannot be hot-swapped in an already loaded module.

## IEEE 30 Frequency and Data-Center Example

`07_ieee30_frequency_datacenter_uc.jl` is a complete application-side example. It loads the `:ieee30` case, prints the system boundary, configures frequency parameters for conventional units, adds a wind unit with virtual inertia/damping fields, mounts a 20 MW data center at bus 5, snapshots every input table as CSV, and then calls `solve_uc` through `UCSolveRequest`.

Use a four-hour horizon for quick interface validation:

```bash
$env:UC_HORIZON = "4"
$env:UC_SCENARIO_LIMIT = "1"
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

To inspect only the PowerSystems bridge, frequency parameters, and data-center input without solving:

```bash
$env:UC_RUN_SOLVE = "0"
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

Input snapshots are written under `output/examples/powersystems/ieee30/<algorithm>/<run_id>/input/`. PowerSystems native power fields already use `SYSTEM_BASE` per unit. Extra data-center parameters are entered in MW and converted by the unified bridge.

## Calling Styles

`solve_uc` supports direct keyword calls:

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    data_file = "data/data.xlsx",
    scenario_limit = 3,
    horizon = 24,
)
```

It also supports explicit request objects:

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

`UCSolveRequest` validates algorithm and input names at construction. Common aliases such as `"extensive-form"` normalize to `:benchmark`.

## Output Modes

`verbosity = :detailed` is the default. It prints system boundaries, effective configuration, and layered optimization results. Other modes are:

| `verbosity` | Use case | Terminal behavior |
|---|---|---|
| `:detailed` | Interactive runs | Full boundary/configuration report and detailed result report. |
| `:summary` | Fast feedback | Compact layered summary. |
| `:verbose` | Algorithm debugging | Preserve low-level algorithm logs. |
| `:silent` | Batch jobs or custom reports | Do not print automatically. |

Batch runs typically use `:silent` and then call `print_uc_result(result; detail=true)` when a standard report is needed.

## Outputs and Paths

The default output root is `<project>/output/`, independent of the caller's current working directory. Override it with `MODULE_UC_OUTPUT_DIR` or the unified `output_dir` keyword. Use `MODULE_UC_RUN_ID` to make run IDs deterministic in CI or batch experiments.

Prefer `result.output_dir` when locating outputs. Do not reconstruct internal algorithm paths in application code.
