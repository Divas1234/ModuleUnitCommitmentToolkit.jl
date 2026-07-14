# Module Unit Commitment Toolkit

Julia toolkit and browser dashboard for stochastic Unit Commitment (UC)
experiments with data-center load, renewable scenarios, decomposition
algorithms, and result comparison workflows.

The repository contains three connected layers:

- A JuMP/Gurobi UC modeling core under `src/`
- Algorithm drivers for Benchmark UC, Benders decomposition, and CCG under `tools/`
- A native HTML/CSS/JavaScript dashboard served by a small Python server under `gui/`

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Package Installation](#package-installation)
- [Dashboard](#dashboard)
- [Command-Line Workflows](#command-line-workflows)
- [Unified Solver Entry](#unified-solver-entry)
- [Runtime Configuration](#runtime-configuration)
- [API and Code Review](#api-and-code-review)
- [Outputs](#outputs)
- [Project Layout](#project-layout)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- Stochastic and security-constrained UC model components built with JuMP.
- Benchmark extensive-form UC runner for baseline comparisons.
- Benders decomposition workflow with cut, subproblem, and fast benchmark modes.
- Column-and-Constraint Generation (CCG) workflow with optional Wasserstein DRO.
- Data-center, wind, network, storage, and frequency-control modeling modules.
- Runtime configuration through `config/runtime_config.toml`.
- Local GUI dashboard for:
  - overview metrics
  - quality and convergence charts
  - schedule inspection
  - benchmark reports and SVG charts
  - runtime configuration editing
  - launching Julia tasks from the browser

## Requirements

- Julia with the project environment available. The current development setup is
  tested with Julia `1.12.x`.
- Python 3 for the local dashboard server.
- Gurobi and a valid Gurobi license for optimization runs that use Gurobi.
- Git submodules and data files required by the selected case.

Install Julia dependencies from the repository root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

If Gurobi is not configured yet, verify that Julia can load it:

```bash
julia --project=. -e 'using Gurobi; println(Gurobi.Env())'
```

## Quick Start

Run the dashboard:

```bash
./gui/start.sh
```

Then open:

```text
http://localhost:8080/gui/
```

The dashboard binds to `127.0.0.1` by default. Remote deployment is disabled unless all
security settings are provided explicitly:

```bash
MODULE_UC_GUI_ALLOW_REMOTE=1 \
MODULE_UC_GUI_HOST=0.0.0.0 \
MODULE_UC_GUI_TOKEN='replace-with-a-long-random-token' \
MODULE_UC_GUI_ALLOWED_ORIGINS='https://dashboard.example.com' \
python3 gui/server.py
```

Remote API requests use `Authorization: Bearer <token>`. The browser dashboard asks for the
token once per page session; it is kept in memory only.

Run the lightweight test suite:

```bash
julia --project=. test/runtests.jl
```

Run a small Benders or CCG experiment:

```bash
julia --project=. tools/benders/driver.jl
julia --project=. tools/ccg/driver.jl
```

## Dashboard

The GUI is generated from `gui/build_html.py` into `gui/index.html` and served
by `gui/server.py`.

Start it with:

```bash
python3 gui/server.py
```

or use the convenience scripts:

```bash
./gui/start.sh
gui/start.bat
gui/start.ps1
```

The dashboard exposes these panels:

- `Overview`: run-level summary table and status metrics.
- `Quality`: Plotly charts for curtailment, gap, runtime, RAM, convergence, and
  bounds, with quality and iteration tables.
- `Schedule`: dispatch, commitment, cost, curtailment, power balance, startup,
  reserve, and report views.
- `Reports`: benchmark report text and generated SVG chart previews.
- `Settings`: structured runtime configuration editor.
- `Run`: browser controls for boundary checks, benchmark runs, CCG, Benders,
  Benders Fast, and tests.

After changing the dashboard generator, rebuild the static HTML:

```bash
python3 gui/build_html.py
```

## Command-Line Workflows

### Benchmark UC

```bash
julia --project=. tools/benchmark/run_algorithm_comparison.jl
```

This runner compares Benchmark UC, Benders, and CCG for configured scenario
counts and writes consolidated output under `output/`.

### Benders

```bash
julia --project=. tools/benders/driver.jl
```

Useful one-off override:

```bash
BENDERS_SCENARIO_LIMIT=5 julia --project=. tools/benders/driver.jl
```

### CCG

```bash
julia --project=. tools/ccg/driver.jl
```

Useful one-off override:

```bash
CCG_SCENARIO_LIMIT=5 julia --project=. tools/ccg/driver.jl
```

### Wasserstein DRO Example

```bash
julia --project=. examples/ccg/run_wasserstein_dro_ccg.jl
```

See [docs/algorithms/wasserstein_dro_ccg.md](docs/algorithms/wasserstein_dro_ccg.md)
for the modeling notes.

## Unified Solver Entry

New integrations should use one data/algorithm entry point and select behavior
with parameters:

```julia
using ModuleUnitCommitmentToolkit

result = solve_uc(
    algorithm = :benchmark,  # :benchmark, :benders, or :ccg
    input = :excel,          # :excel, :powersystems, or :powersystems_csv
    scenario_limit = 3,
    calibration = (CCG_MAX_ITERATIONS = 10,),
)
```

The runnable example is [examples/unified_solver.jl](examples/unified_solver.jl).
Detailed input, calibration, result, and compatibility rules are in
[docs/api_reference.md](docs/api_reference.md).
The detailed, commented programs are in
[examples/unified_api/README.md](examples/unified_api/README.md).

## Runtime Configuration

Central runtime settings live in:

```text
config/runtime_config.toml
```

The algorithm drivers load this file before reading environment variable
overrides. Shell variables are still useful for temporary runs:

```bash
CCG_MAX_ITERATIONS=20 CCG_DRO_ENABLED=1 julia --project=. tools/ccg/driver.jl
```

Important configuration groups include:

- `boundary`: input and boundary report options.
- `common`: shared display and compatibility switches.
- `model`: network, system, wind, thermal, data-center, BESS, and precision flags.
- `benders`: scenario limits, iteration limits, fast mode, and solver controls.
- `benders.cuts`: cut violation tolerances and cut selection controls.
- `benders.subproblems`: parallel subproblem options.
- `ccg`: master, recourse, scenario, and convergence controls.
- `dro`: Wasserstein DRO controls for CCG.
- `frequency`: frequency support and nadir fitting settings.
- `test`: test harness switches.

See [docs/runtime_configuration.md](docs/runtime_configuration.md) for more
detail.

## API and Code Review

The public package functions, algorithm script interfaces, input conventions,
result fields, output paths, and runnable examples are documented in
[docs/api_reference.md](docs/api_reference.md). The project-wide review findings,
security boundary, test evidence, and follow-up priorities are recorded in
[docs/code_review.md](docs/code_review.md).

## Outputs

All unified solver and export functions write below the project `output/` directory by
default, independent of the caller's current directory. Set `MODULE_UC_OUTPUT_DIR` to
override the root globally, or pass `output_dir` to `solve_uc` for one request:

```bash
MODULE_UC_OUTPUT_DIR=/tmp/module-uc-output julia --project=. test/smoke_algorithms.jl
```

The `solve_uc` result also exposes the resolved `output_dir` so callers can discover the
location without reconstructing algorithm-specific paths.

Most experiments write to `output/` using timestamped run folders. Common output
locations include:

- `output/benchmark_uc/`
- `output/benders/`
- `output/ccg/`
- `output/comparison/`

Typical artifacts are:

- `summary.csv`
- algorithm logs under `logs/`
- quality metrics
- iteration history
- schedule result tables
- report text and SVG charts

The dashboard reads these artifacts and renders them into the Overview, Quality,
Schedule, and Reports panels.

## Project Layout

```text
config/                  Runtime TOML configuration
data/                    Input data used by model readers
docs/                    Algorithm, benchmark, runtime, and testing notes
examples/                Small reproducible examples
gui/                     Native HTML/CSS/JS dashboard and Python server
output/                  Generated run artifacts
ref/                     Reference projects and input cases
scripts/                 Helper scripts
src/                     Core Julia model, data, renewable, and visualization code
test/                    Julia unit and smoke tests
tools/benchmark/         Benchmark UC and comparison runner
tools/benders/           Benders decomposition implementation
tools/ccg/               CCG and Wasserstein DRO implementation
```

## Testing

Run all tests:

```bash
julia --project=. test/runtests.jl
```

Run the lightweight example test entry:

```bash
julia --project=. examples/testing/run_light_tests.jl
```

See [docs/testing.md](docs/testing.md) for test scope and conventions.

## Troubleshooting

### Julia is not found from the dashboard

Ensure `julia` is on `PATH`:

```bash
julia -v
```

Then restart `gui/server.py`.

### Port 8080 is already in use

Stop the existing server or process using the port:

```bash
lsof -i :8080
```

### Gurobi cannot start

Confirm that Gurobi is installed, licensed, and visible to Julia:

```bash
julia --project=. -e 'using Gurobi; println(Gurobi.Env())'
```

## Package Installation

After the package is registered in the Julia General registry and synchronized to
JuliaHub, install the released package from any Julia environment:

```julia
using Pkg
Pkg.add("ModuleUnitCommitmentToolkit")

using ModuleUnitCommitmentToolkit
```

For development before registry registration, install directly from the GitHub repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl.git", rev = "revised_ModuleUnitCommitmentTookits")
```

Optimization runs require a working Gurobi installation and license. The package itself
provides the unified `solve_uc` entry point for Benchmark UC, Benders, and CCG; callers do
not need to include algorithm implementation files manually.

### Dashboard data looks stale

Rebuild the generated dashboard after changing the generator or refreshing data
schemas:

```bash
python3 gui/build_html.py
```

Then reload `http://localhost:8080/gui/`.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
