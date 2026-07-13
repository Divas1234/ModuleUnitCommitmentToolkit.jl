# Examples

This folder contains small runnable examples and diagnostic scripts.

## Unified Public API Examples

The canonical, fully commented examples for the current package interface are in
`examples/unified_api/`. Start with its index:

```bash
julia --project=. examples/unified_api/01_excel_single_solve.jl
julia --project=. examples/unified_api/02_input_spec_and_data.jl
julia --project=. examples/unified_api/03_three_algorithm_comparison.jl
```

The detailed guide is [`examples/unified_api/README.md`](unified_api/README.md). It covers
`solve_uc`, `UCInputSpec`, `UCSolveRequest`, `UCSolveResult`, PowerSystems input, calibration
parameters, explicit output directories, and the Benders named-field migration.

`examples/unified_solver.jl` remains a short compatibility-friendly command-line example
that selects `UC_ALGORITHM` and `UC_INPUT` from environment variables. New integrations should
prefer the more detailed programs in `examples/unified_api/`.

## Benders Examples

`examples/benders/` contains standalone Benders, LP dual, infeasibility, and callback examples. These are useful for understanding cut generation and Farkas-dual behavior outside the full SCUC workflow.

## CCG Examples

`examples/ccg/` contains runnable scripts for the CCG and Wasserstein DRO workflows.

Quick run:

```bash
julia examples/ccg/run_wasserstein_dro_ccg.jl
```

The quick CCG example reads `examples/ccg/runtime_config_quick.toml`. Edit that file for example-specific runs, or set `MODULE_UC_CONFIG_FILE` to point to another TOML file.

## PowerSystems Examples

The current unified PowerSystems example is:

```bash
julia --project=. examples/unified_api/04_powersystems_native.jl
```

`examples/powersystems_algorithms_demo.jl` is retained as a low-level comparative and
formulation-debugging program. It is not the recommended public API entry point.

## Test Example

`examples/testing/run_light_tests.jl` runs the project test suite from a stable entry point:

```bash
julia examples/testing/run_light_tests.jl
```
