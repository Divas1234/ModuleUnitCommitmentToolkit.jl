# Unified interface examples

Every program in this directory is written against the package-level unified entry point:

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    scenario_limit = 1,
    calibration = (MODEL_CONSIDER_FREQUENCY_CONTROL = 0,),
    output_dir = "output/examples/benchmark",
)
```

Callers set two selector arguments:

| Argument | Accepted values | Meaning |
|---|---|---|
| `algorithm` | `:benchmark`, `:benders`, `:ccg` | Selects the internal algorithm module |
| `input` | `:excel`, `:powersystems`, `:powersystems_csv` | Selects the unified data entry |

`solve_uc` loads algorithm modules lazily. Callers do not manage `include` order. Application code should call `solve_uc` or construct a `UCSolveRequest`. Use the lower-level interface in `tools/benders/setup.jl` only when the Benders intermediate models are needed.

## Example files

| File | Contents | Runs optimization |
|---|---|---:|
| `01_excel_single_solve.jl` | Excel data and one unified solve | Yes |
| `02_input_spec_and_data.jl` | Load and inspect named data with `UCInputSpec` | No |
| `03_three_algorithm_comparison.jl` | Call the three algorithms from the same data entry | Yes |
| `04_powersystems_native.jl` | Native PowerSystems system plus data-center parameters | Yes |
| `05_benders_named_setup.jl` | Benders named fields and the legacy positional compatibility layer | Yes |
| `06_powersystems_case_catalog.jl` | 6/30/118-bus and large-case catalog, bridge, and optional solve | No by default |
| `07_ieee30_frequency_datacenter_uc.jl` | Full UC for IEEE 30-bus with frequency response and a data center | Yes by default |

Run them from the repository root:

```bash
julia --project=. examples/unified_api/01_excel_single_solve.jl
julia --project=. examples/unified_api/02_input_spec_and_data.jl
julia --project=. examples/unified_api/03_three_algorithm_comparison.jl
julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
UC_HORIZON=4 julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

Changing the PowerSystems case only requires a different environment variable. The data entry stays the same:

```bash
UC_CASE=ieee30 julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
UC_CASE=ieee118 UC_RUN_SOLVE=1 UC_ALGORITHM=benchmark \
  julia --project=. examples/unified_api/06_powersystems_case_catalog.jl
```

Stable aliases come from `powersystems_case_catalog()` and `list_powersystems_cases()`. Core aliases are `ieee6`, `ieee30`, and `ieee118`. The catalog also provides `ieee14`, `ieee24`, `c_sys5_all_components`, `rts_gmlc`, `activsg2000`, and `activsg10k`. The 118-bus entry uses the `PowerSystemsTestData/118-Bus` asset shipped with the installed dependency. An external exact IEEE-118 file can still be passed as a file path.

If a Julia REPL has already executed `using ModuleUnitCommitmentToolkit`, quit and restart Julia after updating the source, then run the example again. `UCSolveRequest` is a public struct with fields. A field change cannot be hot-swapped inside an already loaded module; otherwise an older session can report that `verbosity` is unsupported.

The PowerSystems examples need the built-in `PowerSystemCaseBuilder` cases and a working Gurobi environment:

```bash
julia --project=. examples/unified_api/04_powersystems_native.jl
```

### IEEE 30-bus frequency and data-center UC

`07_ieee30_frequency_datacenter_uc.jl` is a fuller application example. It always reads `:ieee30`, prints the system boundary of 30 buses, 6 conventional units, 1 wind unit, 41 branches, and 21 loads, assigns `H/D/K/F/T/R` to the conventional units, assigns `Fcmode/Kw/Rw/Mw/Dw/Tw` to wind capacity derived from the penetration rate, and attaches a 20 MW data center to bus 5. The default wind penetration and contingency size are both 5 percent. Change them with `UC_WIND_PENETRATION` and `UC_FREQUENCY_CONTINGENCY_FRACTION`. The script then prints unified data dimensions and the effective config through `load_uc_data`, and calls `benchmark`, `benders`, or `ccg` through `UCSolveRequest`.

Input reporting is no longer only a long text log. Each input table is converted to a `DataFrame`, printed as a table, and written under an explicit output root before the solve:

```text
output/examples/powersystems/ieee30/<algorithm>/<run_id>/
├── input/
│   ├── 01_buses.csv
│   ├── 02_thermal_generators.csv
│   ├── 03_wind_generators.csv
│   ├── 04_branches.csv
│   ├── 05_loads.csv
│   ├── 06_thermal_frequency_parameters.csv
│   ├── 07_wind_frequency_parameters.csv
│   ├── 08_data_centers.csv
│   ├── 09_model_dimensions.csv
│   ├── 10_effective_config.csv
│   ├── 11_unified_wind_parameters.csv
│   └── 12_wind_availability.csv
└── benchmark_uc/<run_id>/scheduling/   # or benders/ or ccg/
```

`02_thermal_generators.csv` keeps the original PowerSystems `source_p_max_pu`, the unit `rating_pu`, and the bridged `uc_p_max_pu`, so the zero-limit fallback can be checked. `10_effective_config.csv` is the model configuration actually returned by `load_uc_data`, not a draft declared only by the caller.

Validate the interface and model path with a 4-hour window first:

```bash
UC_HORIZON=4 UC_ALGORITHM=benchmark \
  julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

Inspect the PowerSystems bridge, frequency parameters, and data-center data without starting the optimization:

```bash
UC_HORIZON=4 UC_RUN_SOLVE=0 \
  julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

That command skips the optimization, but it still prints every input `DataFrame` and writes the CSV snapshots. After it finishes, open the latest `output/examples/powersystems/ieee30/benchmark/<run_id>/input/` directory.

Native `PowerSystems` power fields are already in `SYSTEM_BASE` per unit. Data-center parameters in the example are still entered in MW and converted to internal per unit by the unified bridge. The 5 percent contingency and 5 percent wind penetration are teaching values for a smoke test that produces a multi-unit commitment. A formal study should reset both parameters from the actual N-1 contingency and the planned renewable share.

## 1. Two ways to call `solve_uc`

### Keyword call

Use this for scripts and simple service calls. Every input argument is declared in one place:

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 5,
    ),
)
```

### Explicit request object

Use this when the request must be recorded, batched, or passed through an application layer:

```julia
request = UCSolveRequest(
    algorithm = :benders,
    input = :excel,
    scenario_limit = 3,
    calibration = Dict(
        "BENDERS_MAX_ITERATIONS" => 5,
        "BENDERS_PARALLEL_SUBPROBLEMS" => 0,
    ),
    output_dir = "/tmp/module-uc/benders",
)

result = solve_uc(request)
```

`UCSolveRequest` validates the algorithm and data entry in its constructor. Algorithm names accept strings and common aliases. For example, `"extensive-form"` is normalized to `:benchmark`.

## 2. Output modes and result display

The default `solve_uc` output mode is `verbosity=:detailed`. After the data is configured, it prints system boundary parameters, the effective `config` fields, and the runtime configuration. After the solve, it prints a layered optimization report:

```text
[Request]
  algorithm       : benchmark
  input           : excel
[Status]
  status          : OPTIMAL
  upper_bound     : ...
  lower_bound     : ...
  gap             : ...
[Progress]
  iterations      : -
[Artifacts]
  output_dir      : /path/to/output
```

The four modes are:

| `verbosity` | Use | Terminal behavior |
|---|---|---|
| `:detailed` | Interactive runs; the default | Full boundary and configuration report, plus a detailed optimization report |
| `:summary` | Fast feedback | Unified layered summary only; internal logs are hidden |
| `:verbose` | Algorithm debugging | Keeps the full lower-level algorithm log |
| `:silent` | Batch jobs, services, or a custom report | Prints nothing; the caller handles the return value |

Batch jobs usually use `:silent`, then call `print_uc_result` when a standard format is needed:

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 1,
    verbosity = :silent,
)

print_uc_result(result; detail = true)
```

`verbosity` controls output only. It does not change `UCSolveResult`. Algorithm-specific fields are still available through `result.details` or `hasproperty(result, :field_name)`.

`print_uc_result(result; detail=true)` renders each layer as a `DataFrame` and writes it under `result.output_dir/result/`. The request, status, progress, input dimensions, effective configuration, solver information, iteration history, cost breakdown, and algorithm diagnostics are saved as numbered CSV files for post-processing with DataFrames or CSV.

## 3. Result object

All three algorithms return a `UCSolveResult`. The result has three shared fields:

```julia
result.algorithm   # :benchmark, :benders, or :ccg
result.input       # :excel, :powersystems, or :powersystems_csv
result.output_dir  # output root actually used by this run
```

Named algorithm fields are also available on the result object:

```julia
result.status
result.upper_bound
result.lower_bound
result.gap
result.history
```

`result.details` returns the full underlying `NamedTuple`:

```julia
println(keys(result.details))
println(result[:upper_bound])
```

Extra fields differ by algorithm. Benchmark and CCG usually include `model`, `data`, and `cost_summary`. Benders usually includes `history`, `iterations`, and `incumbent`. Application code should prefer the shared fields and call `hasproperty(result, :field_name)` before reading an algorithm-specific field.

## 4. Calibration scope

`calibration` may be a `NamedTuple` or a dictionary. Keys match TOML and `ENV` parameters, and Boolean values are converted to `0/1`. Overrides apply only to the current `solve_uc` call and do not leak into later calls:

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 10,
        CCG_PARALLEL_RECOURSE = false,
    ),
)
```

Common parameters:

| Algorithm | Parameter | Purpose |
|---|---|---|
| Shared model | `MODEL_CONSIDER_BESS` | Enable storage constraints |
| Shared model | `MODEL_CONSIDER_FREQUENCY_CONTROL` | Enable frequency-control constraints |
| Shared model | `MODEL_CONSIDER_DATA_CENTER` | Enable data-center constraints |
| benchmark | `BENCHMARK_UC_USE_DRO` | Use DRO scenario probabilities |
| Benders | `BENDERS_MAX_ITERATIONS` | Maximum decomposition iterations |
| Benders | `BENDERS_PARALLEL_SUBPROBLEMS` | Solve subproblems in parallel |
| CCG | `CCG_INITIAL_SCENARIOS` | Number of initial scenarios |
| CCG | `CCG_SCENARIOS_PER_ITERATION` | Scenarios added each round |
| CCG | `CCG_MAX_ITERATIONS` | Maximum iterations |
| CCG | `CCG_GAP_TOL` | Convergence gap tolerance |

The full parameter list is in [`config/runtime_config.toml`](../../config/runtime_config.toml) and [`docs/runtime_configuration.md`](../../docs/runtime_configuration.md).

## 5. Output directory

The default output root is `output/` under the project root. It does not change when the caller starts Julia from another directory. Set a global output directory with an environment variable:

```bash
MODULE_UC_OUTPUT_DIR=/tmp/module-uc-output \
  julia --project=. examples/unified_api/01_excel_single_solve.jl
```

Or set it for one request:

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :excel,
    output_dir = "/tmp/module-uc-output/benchmark",
)
```

`result.output_dir` is the recommended way for a caller to find outputs. Do not concatenate internal algorithm directory names in application code. `MODULE_UC_RUN_ID` fixes the algorithm run id for CI or a batch experiment:

```bash
MODULE_UC_RUN_ID=demo_001 julia --project=. examples/unified_api/01_excel_single_solve.jl
```

## 6. Three PowerSystems data forms

### Existing `System`

```julia
data = load_uc_data(
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
)
```

### Built-in case name

```julia
result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems,
    case_name = "c_sys5_all_components",
    case_category = PSITestSystems,
    scenario_limit = 3,
)
```

### PowerSystems plus project extension CSV files

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :powersystems_csv,
    sys = sys,
    case_dir = "/path/to/case_dir",
    scenario_limit = 3,
)
```

`input=:powersystems_csv` requires both `sys` and `case_dir`. `input=:powersystems` requires `sys` or `case_name`, and those two cannot be supplied together.

## 7. Benders positional-tuple migration

New code uses named fields:

```julia
setup = main(; scenario_limit = 1)

master_model = setup.master_model
sub_model = setup.sub_model
batch_subproblems = setup.batch_subproblems
NG = setup.NG
NT = setup.NT
```

`BendersSetup` returned by `main` still supports the old 20-value iterator, but only for migrating old programs:

```julia
# Compatibility for old code. Do not extend this positional interface in new code.
legacy_values = collect(setup)
@assert length(legacy_values) == 20
```

New application logic should call `solve_uc(algorithm=:benders, ...)`. Open `BendersSetup` only when debugging a cut, the master problem, or a subproblem.
