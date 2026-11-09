# ModuleUnitCommitmentToolkit

`ModuleUnitCommitmentToolkit` is a Julia package for stochastic, network-constrained, and security-constrained unit commitment. One function, `solve_uc`, runs three algorithms on one data interface:

| Algorithm | Selector | What it solves |
| --- | --- | --- |
| Benchmark | `:benchmark` | Extensive-form UC over the full scenario set. This is the reference solve. |
| Benders | `:benders` | Multi-cut Benders decomposition. Commitment stays in the master; scenario recourse stays in the subproblems. |
| CCG | `:ccg` | Column-and-constraint generation. The master grows by adding the worst unused renewable scenarios. |

Renewable uncertainty can be treated as a Wasserstein distributionally robust problem inside Benchmark and CCG. That robust model is not a fourth solver. It is controlled by `CCG_DRO_ENABLED` and `CCG_DRO_RADIUS`, and documented in [`docs/algorithms/wasserstein_dro_ccg.md`](docs/algorithms/wasserstein_dro_ccg.md).

The same call accepts Excel workbooks or PowerSystems systems. Each run writes the input tables, the effective configuration, and the solver report to an explicit output directory.

## Status

- Version: `0.1.0`
- Julia: `1.10` or later
- License: MIT
- Solver: JuMP with Gurobi. A separate Gurobi license is required.
- Module: `ModuleUnitCommitmentToolkit`

## Installation

After `v0.1.0` is in the Julia General registry:

```julia
using Pkg
Pkg.add("ModuleUnitCommitmentToolkit")
```

Before that, install a checkout or a release tag:

```julia
using Pkg
Pkg.develop(path = "/path/to/ModuleUnitCommitmentToolkit.jl")

# or a tagged release
Pkg.add(url = "https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl.git", rev = "v0.1.0")
```

From a clone, instantiate the project and check Gurobi:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Gurobi; println(Gurobi.Env())'
```

The package can be loaded without solving. An optimization run needs Julia 1.10+, a working Gurobi installation, and a license that Julia can see. This package does not distribute Gurobi.

## Quick start

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,       # :benchmark, :benders, or :ccg
    input = :excel,               # :excel, :powersystems, or :powersystems_csv
    scenario_limit = 1,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        BENCHMARK_UC_USE_DRO = false,
    ),
    output_dir = "output/quickstart",
    verbosity = :summary,
)

println(result.status)
println(result.upper_bound)
println(result.output_dir)
```

`solve_uc` validates the request, loads the data, applies calibration only for that call, dispatches to Benchmark, Benders, or CCG, and returns a `UCSolveResult`. Algorithm modules under `tools/` load on the first solve.

Build the request first when it will be stored or reused:

```julia
request = UCSolveRequest(
    algorithm = :ccg,
    input = :excel,
    scenario_limit = 3,
    calibration = (
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 5,
        CCG_DRO_ENABLED = false,
    ),
    output_dir = "output/ccg_demo",
    verbosity = :silent,
)

result = solve_uc(request)
print_uc_result(result; detail = true)
```

`"extensive-form"` is accepted and normalized to `:benchmark`.

## PowerSystems

Only the input arguments change:

```julia
using ModuleUnitCommitmentToolkit

sys = build_system_from_powersystems(:ieee30)
frequency_parameters = generate_frequency_parameters(sys)
data_centers = [(
    bus = 5,
    p_max = 20.0,
    p_min = 0.0,
    idle_power = 0.0,
    server_energy = 0.0,
    lambda = 0.0,
    mu = 1.0,
    workload = fill(0.0, 24),
)]

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
    ),
    output_dir = "output/powersystems/ieee30/benchmark",
    verbosity = :summary,
)
```

Stable case aliases include `:ieee6`, `:ieee14`, `:ieee24`, `:ieee30`, `:ieee118`, `:c_sys5_all_components`, `:rts_gmlc`, `:activsg2000`, and `:activsg10k` when the installed PowerSystems test data provides them. Inspect the catalog with `powersystems_case_catalog()` and `list_powersystems_cases()`.

The worked IEEE 30-bus example adds wind, frequency response, and a data center, then writes input snapshots before the solve:

```bash
UC_HORIZON=4 julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

`UC_ALGORITHM`, `UC_HORIZON`, `UC_SCENARIO_LIMIT`, `UC_WIND_PENETRATION`, `UC_FREQUENCY_CONTINGENCY_FRACTION`, and `UC_RUN_SOLVE` control that example.

## Calibration

Calibration values last for one `solve_uc` call. They do not rewrite the global environment for later calls.

| Parameter | Effect |
| --- | --- |
| `MODEL_CONSIDER_DATA_CENTER` | Data-center load constraints |
| `MODEL_CONSIDER_FREQUENCY_CONTROL` | Frequency-support constraints |
| `MODEL_CONSIDER_BESS` | Storage constraints |
| `MODEL_CONSIDER_WIND` | Wind-unit constraints |
| `MODEL_NETWORK_CONSTRAINT` | Network constraints |
| `MODEL_THERMAL_UNIT_CONSTRAINT` | Thermal-unit constraints |
| `BENCHMARK_UC_USE_DRO` | Use DRO scenario probabilities in the extensive form |
| `BENDERS_MAX_ITERATIONS` | Benders iteration limit |
| `BENDERS_PARALLEL_SUBPROBLEMS` | Solve Benders subproblems in parallel |
| `CCG_INITIAL_SCENARIOS` | Scenarios in the first CCG master |
| `CCG_SCENARIOS_PER_ITERATION` | Scenarios added after each separation |
| `CCG_MAX_ITERATIONS` | CCG iteration limit |
| `CCG_GAP_TOL` | CCG convergence tolerance |
| `CCG_DRO_ENABLED` | Wasserstein worst-case distribution inside CCG |
| `CCG_DRO_RADIUS` | Wasserstein radius. `0` recovers the empirical distribution |

The full key list is in [`config/runtime_config.toml`](config/runtime_config.toml) and [`docs/runtime_configuration.md`](docs/runtime_configuration.md).

## Output

Set `output_dir` on the request, or set `MODULE_UC_OUTPUT_DIR`. Relative paths are resolved from the project root. `result.output_dir` is the path to read after the solve.

`print_uc_result(result; detail = true)` prints each section as a DataFrame and writes the same fields under `result.output_dir/result/`:

- `01_request.csv`
- `02_status.csv`
- `03_progress.csv`
- `04_input_data.csv`
- `05_effective_config.csv`
- `06_model_solver.csv`
- `07_iteration_history.csv`
- `08_cost_breakdown.csv`
- `09_algorithm_diagnostics.csv`

Benchmark and CCG also write scheduling files under `<output_dir>/<algorithm>/<run_id>/scheduling/`. The Benders entry currently returns the in-memory result and the configured output directory.

## Repository layout

```text
src/                         package module and UC model
tools/benchmark/             extensive-form reference solver
tools/benders/               Benders master, subproblems, and cuts
tools/ccg/                   CCG solver and Wasserstein DRO
examples/unified_api/        runnable solve_uc examples
data/data.xlsx               default Excel case
config/runtime_config.toml   default runtime switches
test/                        unit, interface, smoke, and GUI tests
docs/                        API, configuration, and algorithm notes
gui/                         optional local dashboard
```

New application code should call `solve_uc` or `load_uc_data`. The `tools/` drivers remain available for algorithm debugging:

```bash
julia --project=. tools/benchmark/run_algorithm_comparison.jl
julia --project=. tools/benders/driver.jl
julia --project=. tools/ccg/driver.jl
```

## Examples and further reading

- [`examples/unified_api/README.md`](examples/unified_api/README.md) — how to call the unified API
- [`examples/unified_api/01_excel_single_solve.jl`](examples/unified_api/01_excel_single_solve.jl) — one Excel solve
- [`examples/unified_api/03_three_algorithm_comparison.jl`](examples/unified_api/03_three_algorithm_comparison.jl) — Benchmark, Benders, and CCG on the same data
- [`examples/unified_api/04_powersystems_native.jl`](examples/unified_api/04_powersystems_native.jl) — native PowerSystems input
- [`docs/api_reference.md`](docs/api_reference.md) — public functions, fields, and command-line entry points
- [`docs/powersystems_algorithms_guide.md`](docs/powersystems_algorithms_guide.md) — PowerSystems bridge and frequency parameters
- [`docs/testing.md`](docs/testing.md) — what each test file covers
- [`docs/juliahub_publishing.md`](docs/juliahub_publishing.md) — registry release steps

## Testing

Run the same checks that CI runs, from the repository root:

```bash
julia --project=. test/runtests.jl
julia --project=. test/fast_interface.jl
julia --project=. test/smoke_algorithms.jl
python3 -m unittest discover -s test -p 'test_gui_security.py'
```

`test/runtests.jl` covers data loading, the PowerSystems bridge, model helpers, DRO and CCG helpers, and Benders structures. `test/fast_interface.jl` checks request validation and result rendering without a full solve. `test/smoke_algorithms.jl` solves one Excel scenario with each algorithm and needs Gurobi. `test/test_gui_security.py` checks the local dashboard's bind address, token, and request limits.

`Pkg.test()` runs `test/runtests.jl`. The fast interface, smoke, and GUI checks are separate CI steps because they load the package as an external caller or use Python.

## Local dashboard

The HTML dashboard is optional and is not part of the solver API:

```bash
./gui/start.sh
```

It listens on `127.0.0.1` by default. A remote bind requires `MODULE_UC_GUI_ALLOW_REMOTE=1`, a bearer token, and an origin allow-list together.

## Development

Keep new behavior behind `solve_uc` and `load_uc_data`. Add a test for a new route, and add an example under `examples/unified_api/` when the public behavior changes. The root `Project.toml` is the only package environment.

## License

Project source is under the MIT License. See [`LICENSE`](LICENSE).

Gurobi, PowerSystems, and other dependencies keep their own licenses. Gurobi is proprietary: install it separately and supply a valid license. This package does not redistribute solver binaries or third-party licenses.
