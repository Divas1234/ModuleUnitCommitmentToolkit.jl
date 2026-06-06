# Datacenter Unit Commitment Model

## Table of Contents

- [Datacenter Unit Commitment Model](#datacenter-unit-commitment-model)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Usage](#usage)
  - [File Structure](#file-structure)
  - [Benders Decomposition Implementation](#benders-decomposition-implementation)
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
*   `src/read_inputdata_modules/_formatteddata.jl`: Formats input data.
*   `src/read_inputdata_modules/_readdatafromexcel.jl`: Reads data from Excel sheets.
*   `src/read_inputdata_modules/_showboundrycase.jl`: Shows boundary cases.
*   `src/read_inputdata_modules/readdatas.jl`: Reads data.
*   `src/renewableresource_modules/_renewableenergysimulation.jl`: Simulates renewable energy sources.
*   `src/renewableresource_modules/stochasticsimulation.jl`: Performs stochastic simulations.
*   `src/unitcommitment_model_modules/SUCuccommitmentmodel.jl`: Implements the SUC-SCUC model.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_datacentra.jl`: Defines constraints for datacenters.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_frequencydynamic.jl`: Defines frequency dynamic constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_generator.jl`: Defines generator constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_network.jl`: Defines network constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_storage.jl`: Defines storage constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_systemwide.jl`: Defines system-wide constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraints_generatefittingparameters.jl`: Generates fitting parameters constraints.
*   `src/unitcommitment_model_modules/constraints_lib/constraints.jl`: Includes constraint definitions.
*   `src/unitcommitment_model_modules/objectives_lib/_objective_econimic.jl`: Defines the economic objective.
*   `src/unitcommitment_model_modules/objectives_lib/objections.jl`: Includes objective definitions.
*   `src/unitcommitment_model_modules/tests_lib/_validata_input.jl`: Validates input data.
*   `src/unitcommitment_model_modules/tests_lib/tests.jl`: Includes test functions.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_define_decision_variables.jl`: Defines decision variables.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_export_res_to_txtfiles.jl`: Exports results to text files.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_linearization.jl`: Implements linearization techniques.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/utilities.jl`: Includes utility functions.
*   `src/visualization_modules/casesploting.jl`: Plots the cases.
*   `src/visualization_modules/draw_addditionalpower.jl`: Draws additional power.
*   `src/visualization_modules/draw_onlineactivepowerbalance.jl`: Draws online active power balance.

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
