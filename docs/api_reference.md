# Public interface and calling reference

This document follows the current source. It separates the package public interface from the tool-script interface. Commands are run from the project root unless noted otherwise.

Runnable end-to-end examples are in [`examples/unified_api/README.md`](../examples/unified_api/README.md).

## 1. Interface boundary

### Package interface

```julia
using ModuleUnitCommitmentToolkit
```

Use the following functions for data loading, data conversion, and the base UC solve:

| Interface | Purpose | Main return value |
|---|---|---|
| `load_uc_data(; ...)` | Load Excel, a native PowerSystems system, or a CSV extension case through one entry | Named data object |
| `build_system_from_powersystems(name; case_category=...)` | Build a `System` from `PowerSystemCaseBuilder` | `PowerSystems.System` |
| `load_native_powersystems_case(name; ...)` | Build a native case and convert it directly to UC data | Same data object as `load_uc_data` |
| `extract_uc_data_from_powersystems(sys; ...)` | Convert an existing `System` to the lower-level UC structure | Legacy positional tuple, for bridging and debugging |
| `generate_frequency_parameters(sys; overrides=...)` | Build frequency-control parameters for conventional units | `Dict{String, NamedTuple}` |
| `generate_wind_scenarios_from_system(sys, params, mode, horizon; ...)` | Build wind scenarios from a native system | `(winds, NW)` |
| `SUC_scucmodel(...)` | Build and solve the lower-level SUC/SCUC model directly | `Dict`; may be `nothing` if the solve fails |
| `load_runtime_config!(; ...)` | Load a TOML configuration into `ENV` | `(config_path, applied, skipped)` |

### Unified algorithm entry

New code calls one function:

```julia
result = solve_uc(
    algorithm = :benchmark,       # :benchmark, :benders, or :ccg
    input = :excel,               # :excel, :powersystems, or :powersystems_csv
    scenario_limit = 3,
    calibration = (
        MODEL_CONSIDER_DATA_CENTER = 0,
        CCG_MAX_ITERATIONS = 10,
    ),
)
```

`solve_uc` loads the selected algorithm module, chooses the data entry, applies calibration, and returns the result. `algorithm` accepts string aliases. `calibration` may be a `NamedTuple` or a dictionary. Keys match TOML and `ENV` parameters, Booleans become `1/0`, and the override lasts only for that call.

Common calibration keys are below. The full list remains in [`runtime_configuration.md`](runtime_configuration.md) and `config/runtime_config.toml`:

| Scope | Example parameters | Effect |
|---|---|---|
| Shared model | `MODEL_CONSIDER_DATA_CENTER`, `MODEL_CONSIDER_FREQUENCY_CONTROL`, `MODEL_CONSIDER_BESS` | Toggle data-center, frequency-control, and storage constraints |
| benchmark | `BENCHMARK_UC_USE_DRO` | Use DRO scenario probabilities in benchmark |
| Benders | `BENDERS_MAX_ITERATIONS`, `BENDERS_PARALLEL_SUBPROBLEMS` | Maximum iterations and the parallel-subproblem switch |
| CCG | `CCG_INITIAL_SCENARIOS`, `CCG_SCENARIOS_PER_ITERATION`, `CCG_MAX_ITERATIONS`, `CCG_GAP_TOL` | Initial scenarios, scenarios added each round, maximum iterations, and convergence tolerance |

A PowerSystems call only changes `input`. The rest of the entry stays the same:

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
)
```

All three algorithms return a named result with `algorithm`, `input`, and `output_dir`, plus their own `status`, bounds, `gap`, `history`, and model or output fields. Modules under `tools/` load lazily on the first `solve_uc` call.

### Output modes

The unified entry defaults to `verbosity=:detailed`. After data loading, the terminal prints the full system boundary, the effective model `config`, and the runtime configuration. After the solve, it prints the objective, bounds, gap, model size, iteration history, cost breakdown, algorithm diagnostics, and output paths.

The four modes are:

| Mode | Use | Terminal behavior |
|---|---|---|
| `:detailed` | Default interactive and experiment runs | Full boundary and configuration report, plus a detailed optimization result |
| `:summary` | Fast feedback | Request, Status, Progress, and Artifacts summary only |
| `:verbose` | Lower-level algorithm diagnosis | Keeps the raw algorithm log and prints the solve progress |
| `:silent` | Batch jobs and service layers | Prints nothing; the caller renders the result |

A batch job can use `verbosity=:silent` and then call `print_uc_result(result; detail=true)`:

```julia
result = solve_uc(
    algorithm = :ccg,
    input = :excel,
    verbosity = :silent,
)

print_uc_result(result; detail = true)
```

Each layer of `print_uc_result` is rendered as a `DataFrame` and written under `result.output_dir/result/`. The files are `01_request.csv`, `02_status.csv`, `03_progress.csv`, `04_input_data.csv`, `05_effective_config.csv`, `06_model_solver.csv`, `07_iteration_history.csv`, `08_cost_breakdown.csv`, and, when the algorithm provides it, `09_algorithm_diagnostics.csv`. The terminal result and the post-processing CSV files use the same fields.

The four modes do not change the contents of `UCSolveResult`. They only control terminal output. Algorithm-specific raw logs stay available under `:verbose`. Shared result fields are always read through named properties such as `result.status` and `result.upper_bound`.

## 2. Unified data loading

### 2.1 Default Excel mode

```julia
data = load_uc_data(; scenario_limit = 3)
```

This mode reads `data/data.xlsx` in the project and applies the model switches mapped from `config/runtime_config.toml` through environment variables.

### 2.2 Existing PowerSystems.System

```julia
using PowerSystems

data = load_uc_data(
    input = :powersystems,
    sys = sys,
    scenario_limit = 3,
    horizon = 24,
    frequency_parameters = frequency_params,
    data_centers = data_centers,
)
```

`sys` and `case_name` cannot be supplied together. When `sys` is passed and `case_dir == ""`, the native PowerSystems bridge is used and no extension CSV files are required.

### 2.3 PowerSystemCaseBuilder cases

```julia
data = load_uc_data(
    input = :powersystems,
    case_name = "c_sys5_all_components",
    case_category = PSITestSystems,
    scenario_limit = 3,
    horizon = 24,
)
```

`load_native_powersystems_case` can be called directly. Common `case_category` values are `MatpowerTestSystems`, `PSITestSystems`, and `PSYTestSystems`. The exact names depend on the installed `PowerSystemCaseBuilder` version.

Prefer the stable case aliases provided by the toolkit. Inspect the catalog with:

```julia
catalog = powersystems_case_catalog()
println(catalog.ieee6.case_name)
println(catalog.ieee118.description)

for case in list_powersystems_cases()
    println(case.alias, " => ", case.case_name)
end
```

Core aliases that can be used directly are `:ieee6`, `:ieee14`, `:ieee24`, `:ieee30`, `:ieee118`, `:c_sys5_all_components`, `:rts_gmlc`, `:activsg2000`, and `:activsg10k`. The first four MATPOWER cases come from `MatpowerTestSystems`. `:ieee118` is built from the installed `PowerSystemsTestData/118-Bus` asset and is bridged as 118 buses, thermal units, AC branches, and area loads. Other local `.m`, `.raw`, or PowerSystems-readable files can still be passed as a `case_name` path.

The unified entry suppresses the low-level rating-range notices and deserialization messages that `PowerSystemCaseBuilder` emits while reading raw MATPOWER data, so those implementation details do not mix with the system boundary, configuration, and optimization result. This affects log display only. It does not modify case data. Construction failures and parameter errors are still raised. To see the raw diagnostics, call `PowerSystemCaseBuilder.build_system(...)` directly. Application code should keep using `build_system_from_powersystems(...)`.

Unified entry example:

```julia
data = load_uc_data(
    input = :powersystems,
    case_name = :ieee30,       # "ieee30" or "case30" is also accepted
    scenario_limit = 1,
    horizon = 24,
)

result = solve_uc(
    algorithm = :benchmark,    # change to :benders or :ccg to reuse the same data entry
    input = :powersystems,
    case_name = :ieee118,
    scenario_limit = 1,
    output_dir = "output/powersystems/ieee118/benchmark",
    verbosity = :summary,
)
```

For a large case such as 118-bus, start with `scenario_limit = 1` to check the input bridge and model feasibility, then raise the scenario count. When comparing algorithms, give each algorithm its own `output_dir`.

### 2.4 PowerSystems plus project extension CSV files

Pass a case directory when the project-specific startup, frequency, storage, wind, and data-center parameters are required:

```julia
data = load_uc_data(
    input = :powersystems_csv,
    sys = sys,
    case_dir = "/path/to/case_dir",
    scenario_limit = 5,
)
```

`case_dir` mode requires at least `thermal_uc.csv`. Enabling the corresponding model components also requires `frequency_parameters.csv`, `storage_uc.csv`, `renewable_profiles.csv`, `data_centers.csv`, and `data_center_workloads.csv`. Fields and required conditions are documented on the functions in `src/input_data/powersystems_reader.jl` and in the parameter-validation errors.

## 3. Input object conventions

### Frequency parameters

`frequency_parameters` may be a dictionary indexed by unit name, or a matrix kept for older code. Prefer the dictionary:

```julia
frequency_parameters = Dict(
    "Gen-1" => (H = 6.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05),
)
```

The fields are inertia `H`, damping `D`, governor gain `K`, turbine fraction `F`, time constant `T`, and droop `R`. A unit that does not provide primary frequency response should still use a nonzero `R`, usually `1.0`, so the frequency fit does not divide by zero. For a large system, call `generate_frequency_parameters` first and then override key units with `overrides`.

The same dictionary can also describe wind units in PowerSystems. Wind records are indexed by component name and use `Fcmode`, `Kw`, `Rw`, `Mw`, `Dw`, and `Tw`. `Fcmode >= 0.5` enables virtual inertia and damping. `Kw` and `Rw` are the primary frequency gain and droop. `Mw`, `Dw`, and `Tw` are the equivalent inertia, damping, and response time constant. Thermal and wind records can be merged and passed once to `UCSolveRequest`:

```julia
frequency_parameters = merge(
    generate_frequency_parameters(sys),
    Dict("Wind Farm 1" => (Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0)),
)
```

A complete IEEE 30-bus UC example with wind, frequency control, and a data center is in [`examples/unified_api/07_ieee30_frequency_datacenter_uc.jl`](../examples/unified_api/07_ieee30_frequency_datacenter_uc.jl).

### Data centers

Each data center requires `bus` and `p_max`. Optional fields are `p_min`, `idle_power`, `server_energy`, `lambda`, `mu`, `workload`, and `voltage_regulation`:

```julia
data_centers = [(
    bus = 3,
    p_max = 0.5,
    p_min = 0.0,
    idle_power = 0.0,
    server_energy = 0.0,
    lambda = 0.0,
    mu = 1.0,
    workload = fill(0.0, 24),
)]
```

Power components inside a native `PowerSystems.System` are already in the `SYSTEM_BASE` per-unit system. The bridge keeps those system base values and does not divide by `base_power` again. Only extra data-center parameters accepted by the interface are entered in MW and converted to per unit when they enter the model. `horizon` must be a positive integer. A workload shorter than `horizon` is padded with its last value.

### `load_uc_data` return object

The return value is a `NamedTuple` with stable fields:

```text
config_param, units, lines, loads, winds, psses, DataCentras,
NB, NG, NL, ND, NT, NC, ND2, NW, NS, full_scenario_probability
```

Power in the model structure is usually per unit. PowerSystems components keep their existing system base. External MW parameters, such as data centers, are converted only at the matching extension entry. `NS` is the scenario count, `NW` is the wind-unit count, and `full_scenario_probability` is `1 / NS` for equally likely scenarios.

## 4. Compatibility interfaces for the three algorithms

Application code should prefer `solve_uc` from the previous section. The functions here are kept for algorithm debugging, old scripts, and callers that need intermediate model objects. They still use `load_uc_data`, but the caller must `include` the tool file. They should not be a new application entry point.

### 4.1 Extensive-form benchmark

```julia
include("tools/benchmark/benchmark_uc.jl")

result = solve_benchmark_uc(; scenario_limit = 3)
```

A native PowerSystems system can use:

```julia
result = solve_benchmark_uc_powersystems(
    sys;
    scenario_limit = 3,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
)
```

`solve_benchmark_uc_powersystems("case_name"; case_category=...)` is also supported. The main result fields are `status`, `model`, `data`, `upper_bound`, `lower_bound`, `gap`, `active_scenarios`, `history`, and `cost_summary`.

### 4.2 C&CG

```julia
include("tools/ccg/ccg_solver.jl")

result = solve_ccg_unit_commitment(
    input = :powersystems,
    scenario_limit = 3,
    sys = sys,
    horizon = 24,
)
```

This function accepts keyword arguments only. It does not accept the `load_uc_data` return object as a positional argument. The initial scenario count is controlled by `CCG_INITIAL_SCENARIOS`. Result fields include `status`, `model`, `evaluation`, `data`, `history`, `active_scenarios`, `upper_bound`, `lower_bound`, `gap`, and `cost_summary`.

### 4.3 Benders

```julia
include("tools/benders/setup.jl")

setup = main(; scenario_limit = 3)

result = multiple_bender_decomposition_scuc(
    setup.master_model,
    setup.sub_model,
    setup.master_struct,
    setup.batch_subproblems,
    setup.winds,
    setup.config_param,
    setup.NG,
    setup.NT,
    length(setup.winds.index),
    setup.ND,
    setup.NL,
)
```

`main` returns a named `BendersSetup`. Old code can still unpack the original 20 values through the compatibility iterator, but new code should use field access. The iterator is read-only and does not include the newer `setup.data` field, so the positional interface can be removed later. If only the input data is needed, prefer the named fields from `load_uc_data`. The main Benders result fields are `status`, `history`, `upper_bound`, `lower_bound`, `gap`, `iterations`, and `incumbent`.

## 5. Command-line entry points

| Command | Purpose |
|---|---|
| `julia --project=. tools/benchmark/run_algorithm_comparison.jl` | Compare benchmark, Benders, and C&CG in batch |
| `julia --project=. tools/benders/driver.jl` | Run Benders |
| `julia --project=. tools/ccg/driver.jl` | Run C&CG |
| `julia --project=. examples/unified_api/04_powersystems_native.jl` | Run the unified PowerSystems example |
| `julia --project=. examples/powersystems_algorithms_demo.jl` | Run the lower-level three-algorithm PowerSystems debug example |
| `julia --project=. test/runtests.jl` | Run the lightweight tests |
| `./gui/start.sh` | Start the local dashboard |

A single command can override TOML defaults with environment variables, for example:

```bash
CCG_SCENARIO_LIMIT=5 CCG_MAX_ITERATIONS=20 \
  julia --project=. tools/ccg/driver.jl
```

The full configuration is documented in [`runtime_configuration.md`](runtime_configuration.md).

## 6. Output and paths

Algorithm output defaults to `output/` under the project root and no longer depends on the caller's working directory. Set the base output directory with an absolute `MODULE_UC_OUTPUT_DIR` or with `output_dir` on the unified entry. Relative paths are resolved from the project root. Set the run id with `MODULE_UC_RUN_ID`. Benchmark and CCG schedule files are usually under `<output_dir>/<algorithm>/<run_id>/scheduling/`. The current Benders unified entry returns the in-memory solve result and does not yet export the same schedule files automatically.

Benchmark comparison results are usually at:

```text
output/comparison/<run_id>/summary.csv
output/comparison/<run_id>/benchmark_report.md
output/<algorithm>/<run_id>/scheduling/
```

When calling lower-level functions directly, also use `MODULE_UC_OUTPUT_DIR` or an explicit `output_dir` so notebooks, service processes, and CI can keep their results separate.
