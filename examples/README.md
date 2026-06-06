# Examples

This folder contains small runnable examples and diagnostic scripts.

## Benders Examples

`examples/benders/` contains standalone Benders, LP dual, infeasibility, and callback examples. These are useful for understanding cut generation and Farkas-dual behavior outside the full SCUC workflow.

## CCG Examples

`examples/ccg/` contains runnable scripts for the CCG and Wasserstein DRO workflows.

Quick run:

```bash
julia examples/ccg/run_wasserstein_dro_ccg.jl
```

The quick CCG example reads `examples/ccg/runtime_config_quick.toml`. Edit that file for example-specific runs, or set `MODULE_UC_CONFIG_FILE` to point to another TOML file.

## Test Example

`examples/testing/run_light_tests.jl` runs the project test suite from a stable entry point:

```bash
julia examples/testing/run_light_tests.jl
```
