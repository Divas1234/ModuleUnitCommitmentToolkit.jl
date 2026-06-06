# Testing Guide

The project includes a lightweight Julia test suite in `test/`.

## Run All Tests

From the repository root:

```bash
julia test/runtests.jl
```

The tests use the currently active Julia environment by default. To force activation of `.pkg/Project.toml`, run:

```bash
MODULE_UC_TEST_ACTIVATE_LOCAL_PROJECT=1 julia test/runtests.jl
```

## Test Coverage

| File | Purpose |
|---|---|
| `test/test_renewables.jl` | Renewable scenario generation smoke tests. |
| `test/test_data_pipeline.jl` | Excel reader and formatted input data checks. |
| `test/test_model_utilities.jl` | Cost linearization and utility checks. |
| `test/test_dro_uncertainty.jl` | Wasserstein DRO validation and error-path tests. |
| `test/test_src_modules.jl` | Base `src` data structures and decision variables. |
| `test/test_benders.jl` | Benders helper structures and wind scenario helpers. |
| `test/test_ccg_algorithm.jl` | CCG scenario selection and subset helpers. |

## Design Notes

The default suite intentionally avoids full-size Benders or CCG optimization runs. It focuses on fast unit and smoke tests that catch:

- Broken include paths.
- Invalid data dimensions.
- Probability and distance-matrix errors.
- Benders helper structure regressions.
- CCG scenario selection regressions.

Use the algorithm drivers for full optimization validation:

```bash
julia tools/benders/driver.jl
julia tools/ccg/driver.jl
```

## Expected Runtime

On the current development setup, the full light suite runs in a few seconds and reports a single top-level summary such as:

```text
Test Summary:         | Pass  Total
module_unitcommitment |   94     94
```
