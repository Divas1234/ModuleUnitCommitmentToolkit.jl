# ModuleUnitCommitmentToolkit

`ModuleUnitCommitmentToolkit` is a Julia package for stochastic, network-constrained,
and security-constrained unit commitment (UC). It provides one public solver entry point
for Benchmark UC, Benders decomposition, and Column-and-Constraint Generation (CCG),
along with one data entry point for Excel and PowerSystems inputs.

The package is designed for reproducible research workflows: input data, effective model
configuration, solver results, iteration history, cost breakdowns, and diagnostics are
written to an explicit output directory in tabular form.

## Package status

- First public registration target: `v0.1.0`
- Julia compatibility: `1.10` and later
- License: MIT
- Optimization backend: JuMP + Gurobi
- Main module: `ModuleUnitCommitmentToolkit`

## Installation

After `v0.1.0` is merged into the Julia General Registry, install it with:

```julia
using Pkg
Pkg.add("ModuleUnitCommitmentToolkit")

using ModuleUnitCommitmentToolkit
```

Before General Registry synchronization, install the release tag directly from GitHub:

```julia
using Pkg
Pkg.add(
    url = "https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl.git",
    rev = "v0.1.0",
)
```

For local development:

```julia
using Pkg
Pkg.develop(path = "/path/to/ModuleUnitCommitmentToolkit.jl")
```

## Requirements

The package can be loaded without solving an optimization problem, but optimization runs
require:

1. Julia `1.10` or later;
2. a working Gurobi installation;
3. a valid Gurobi license visible to Julia;
4. the package environment instantiated.

From a checkout, instantiate the environment with:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Check the solver installation with:

```bash
julia --project=. -e 'using Gurobi; println(Gurobi.Env())'
```

## Quick start: one unified solver entry point

The recommended interface is `solve_uc`. Select the algorithm and data source with
indicators; callers do not include or call algorithm implementation files directly.

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,       # :benchmark, :benders, or :ccg
    input = :excel,               # :excel or :powersystems
    scenario_limit = 1,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENCHMARK_UC_USE_DRO = false,
    ),
    output_dir = "output/quickstart",
    verbosity = :detailed,
)

println("status     = ", result.status)
println("objective  = ", result.upper_bound)
println("output_dir = ", result.output_dir)
```

`solve_uc` performs the following work internally:

1. validates the algorithm and input indicators;
2. loads and normalizes the selected data source;
3. applies the request-local calibration values;
4. dispatches to Benchmark, Benders, or CCG;
5. returns a named result object with common status, bounds, gap, history, and artifact fields.

## Request object form

For applications that build a request in one place and execute it later, use
`UCSolveRequest`:

```julia
using ModuleUnitCommitmentToolkit

request = UCSolveRequest(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 5,
    ),
    output_dir = "output/ccg_demo",
    verbosity = :summary,
)

result = solve_uc(request)
print_uc_result(result; detail = true)
```

Use `verbosity = :silent` in batch jobs and call `print_uc_result` explicitly when the
application is ready to render the result.

## PowerSystems example

PowerSystems data uses the same solver entry point. Only `input` and the system-specific
arguments change:

```julia
using ModuleUnitCommitmentToolkit

sys = build_system_from_powersystems(:ieee30)

frequency_parameters = generate_frequency_parameters(sys)
data_centers = [
    (
        bus = 10,
        p_max = 20.0,
        p_min = 0.0,
        idle_power = 0.0,
        server_energy = 0.0,
        lambda = 0.0,
        mu = 1.0,
        workload = fill(0.0, 24),
    ),
]

result = solve_uc(
    algorithm = :benchmark,
    input = :powersystems,
    sys = sys,
    scenario_limit = 1,
    horizon = 24,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    calibration = (
        MODEL_CONSIDER_DATA_CENTER = true,
        MODEL_CONSIDER_FREQUENCY_CONTROL = true,
        BENCHMARK_UC_USE_DRO = false,
    ),
    output_dir = "output/powersystems/ieee30/benchmark",
    verbosity = :detailed,
)
```

The package includes aliases for common test systems, including `:ieee6`, `:ieee14`,
`:ieee24`, `:ieee30`, `:ieee118`, `:rts_gmlc`, `:activsg2000`, and `:activsg10k` when
the corresponding PowerSystems test data is available in the installed environment.
Use `powersystems_case_catalog()` and `list_powersystems_cases()` to inspect the catalog.

For a complete IEEE 30-bus example with wind penetration, frequency disturbance, data-center
load, input snapshots, and detailed comments, see:

[`examples/unified_api/07_ieee30_frequency_datacenter_uc.jl`](examples/unified_api/07_ieee30_frequency_datacenter_uc.jl)

Run it with:

```bash
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

Useful environment variables include `UC_ALGORITHM`, `UC_HORIZON`,
`UC_SCENARIO_LIMIT`, `UC_WIND_PENETRATION`, and
`UC_FREQUENCY_CONTINGENCY_FRACTION`.

## Calibration parameters

Calibration values are request-local. They are applied for the current solve and do not
silently modify the user's global runtime configuration.

Common switches:

| Parameter | Meaning |
| --- | --- |
| `MODEL_CONSIDER_DATA_CENTER` | Enable data-center load constraints |
| `MODEL_CONSIDER_FREQUENCY_CONTROL` | Enable frequency-support constraints |
| `MODEL_CONSIDER_BESS` | Enable battery constraints |
| `MODEL_CONSIDER_WIND` | Enable wind-unit constraints |
| `MODEL_NETWORK_CONSTRAINT` | Enable network constraints |
| `MODEL_THERMAL_UNIT_CONSTRAINT` | Enable thermal-unit constraints |

Algorithm controls:

| Algorithm | Typical parameters |
| --- | --- |
| Benchmark | `BENCHMARK_UC_USE_DRO` |
| Benders | `BENDERS_MAX_ITERATIONS`, `BENDERS_PARALLEL_SUBPROBLEMS` |
| CCG | `CCG_INITIAL_SCENARIOS`, `CCG_SCENARIOS_PER_ITERATION`, `CCG_MAX_ITERATIONS`, `CCG_GAP_TOL` |

The complete configuration reference is in
[`docs/runtime_configuration.md`](docs/runtime_configuration.md).

## Structured outputs

The output root is explicit. Set it per request with `output_dir`, or set the global
`MODULE_UC_OUTPUT_DIR` environment variable. The solver does not need the caller's
`pwd()` to locate output files.

Each run contains separate `input/` and `result/` directories. Input tables are written
before optimization, which makes it possible to audit the exact data and effective config
used by a run. Result tables include:

- `01_request.csv`
- `02_status.csv`
- `03_progress.csv`
- `04_input_data.csv`
- `05_effective_config.csv`
- `06_model_solver.csv`
- `07_iteration_history.csv`
- `08_cost_breakdown.csv`
- `09_algorithm_diagnostics.csv`

The same sections can be printed as DataFrames:

```julia
print_uc_result(result; detail = true)
```

The result object exposes the resolved output directory:

```julia
println(result.output_dir)
```

## Examples and documentation

- [`examples/unified_api/README.md`](examples/unified_api/README.md): unified API examples;
- [`examples/unified_api/01_excel_single_solve.jl`](examples/unified_api/01_excel_single_solve.jl): Excel solve;
- [`examples/unified_api/03_three_algorithm_comparison.jl`](examples/unified_api/03_three_algorithm_comparison.jl): compare all three algorithms;
- [`examples/unified_api/04_powersystems_native.jl`](examples/unified_api/04_powersystems_native.jl): native PowerSystems input;
- [`examples/unified_api/07_ieee30_frequency_datacenter_uc.jl`](examples/unified_api/07_ieee30_frequency_datacenter_uc.jl): IEEE 30-bus extended example;
- [`docs/api_reference.md`](docs/api_reference.md): public API and result fields;
- [`docs/powersystems_algorithms_guide.md`](docs/powersystems_algorithms_guide.md): PowerSystems and algorithm notes;
- [`docs/juliahub_publishing.md`](docs/juliahub_publishing.md): package registration workflow.

## Testing

Run the package test suite:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

The repository CI includes fast routing/data-entry tests and smoke tests for Benchmark,
Benders, and CCG. The extended PowerSystems tests may require the corresponding test data
and a configured Gurobi installation.

## Optional local dashboard

The repository also contains an optional local HTML dashboard for inspecting generated
experiment artifacts. It is not required for using the Julia package API:

```bash
./gui/start.sh
```

The dashboard binds to `127.0.0.1` by default. Do not expose it on a remote interface unless
authentication, origin restrictions, and request protection have been configured according
to the repository's security guidance.

## Contributing

Please keep new integrations behind the unified `solve_uc` and `load_uc_data` entry points,
add or update tests for new routes, and include a runnable example for new public behavior.
Avoid adding a second package project directory; the root `Project.toml` is canonical.

## License

This project is licensed under the MIT License. See [`LICENSE`](LICENSE).
