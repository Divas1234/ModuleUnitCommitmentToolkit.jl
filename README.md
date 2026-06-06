# Datacenter Unit Commitment Model

## Table of Contents

- [Datacenter Unit Commitment Model](#datacenter-unit-commitment-model)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Usage](#usage)
  - [File Structure](#file-structure)
  - [Benders Decomposition Implementation](#benders-decomposition-implementation)
  - [CCG and Wasserstein DRO](#ccg-and-wasserstein-dro)
  - [Testing](#testing)
  - [Dependencies](#dependencies)
  - [License](#license)

## Description

This project implements a unit commitment model for power systems integrated with datacenters. The model optimizes the commitment and dispatch of generation units, considering the power consumption of datacenters, generation costs, transmission constraints, and renewable energy integration. It aims to provide a cost-effective and reliable power system operation.

## Usage

1.  **Prerequisites:**
    *   [Julia](https://julialang.org/downloads/) (version 1.6 or higher).
    *   Install required Julia packages: Run `] instantiate` in the Julia REPL within the project directory. This installs all dependencies from `Project.toml`.
2.  **Environment Activation:**
    *   Open a Julia REPL in the project directory.
    *   Activate the project environment: `julia --project=.` or `julia -p auto --project=.`
3.  **Model Execution:**
    *   Run the main script: `julia main_function.jl`
    *   Alternatively, from within the Julia REPL: `include("main_function.jl")`

## File Structure

*   `main_function.jl`: Main script to run the unit commitment model.
*   `src/environment_config.jl`: Environment configurations.
*   `src/input_data`: Excel readers, data formatting, and boundary checks.
*   `src/renewables`: Renewable scenario generation and stochastic simulation.
*   `src/unit_commitment`: Core SUC-SCUC formulation.
*   `src/unit_commitment/constraints`: Generator, network, storage, system, data center, and frequency constraints.
*   `src/unit_commitment/objectives`: Economic objective definitions.
*   `src/unit_commitment/utilities`: Decision variables, linearization, solver helpers, power flow, exports, and result saving.
*   `src/unit_commitment/validation`: Input and model validation helpers.
*   `src/visualization`: Plotting and visualization helpers.
*   `tools/ccg`: Column-and-Constraint Generation solver with Wasserstein DRO renewable uncertainty.
*   `test`: Lightweight Julia unit and smoke tests.
*   `docs/algorithms`: Algorithm notes and modeling documentation.
*   `docs/testing.md`: Testing guide.

## Benders Decomposition Implementation

The Benders decomposition algorithm is implemented in the `tools` directory to solve the stochastic unit commitment problem. The main components are:

*   `tools/benders/driver.jl`: Benders executable entry point and optional extensive-form benchmark path.
*   `tools/benders/setup.jl`: Data loading, scenario generation, master/subproblem construction, and batch subproblem setup.
*   `tools/benders/decomposition.jl`: Core Benders decomposition loop, cut generation, cut rollback, and convergence checks.
*   `tools/benders/models`: Master, subproblem, batch subproblem, and SCUC model structure definitions.
*   `tools/benders/cuts`: Benders optimality, feasibility, coefficient, and multi-cut helpers.
*   `tools/archive`: Historical Benders cut-construction drafts kept out of the active include path.
*   `dev/debug`: Development-only debugging scripts.
*   `examples/benders`: Small standalone Benders, LP dual, and Farkas examples.
*   `docs/benchmarks/benders`: Benders performance report and raw benchmark logs.
*   `scripts/run_benders_benchmarks.sh`: Reproducible Benders benchmark runner.

## CCG and Wasserstein DRO

The CCG workflow for renewable uncertainty is implemented in `tools/ccg`. It uses generated wind scenarios as the finite support and can solve a Wasserstein distributionally robust model.

Run a quick DRO CCG example:

```bash
julia examples/ccg/run_wasserstein_dro_ccg.jl
```

Key controls:

```bash
CCG_SCENARIO_LIMIT=20
CCG_INITIAL_SCENARIOS=3
CCG_MAX_ITERATIONS=20
CCG_DRO_ENABLED=1
CCG_DRO_RADIUS=0.05
```

See `docs/algorithms/wasserstein_dro_ccg.md` for the modeling and algorithm details.

## Testing

Run the lightweight test suite:

```bash
julia test/runtests.jl
```

Or from examples:

```bash
julia examples/testing/run_light_tests.jl
```

See `docs/testing.md` for test coverage and conventions.

## Dependencies

The project depends on the following Julia packages:

*   CSV
*   Clustering
*   DataFrames
*   DelimitedFiles
*   Distributions
*   Gurobi
*   JLD
*   JuMP
*   LaTeXStrings
*   MultivariateStats
*   PlotlyJS
*   Plots
*   Revise
*   StatsPlots
*   Test
*   XLSX

## License

This project is licensed under the [MIT License](LICENSE). See the `LICENSE` file for details.
