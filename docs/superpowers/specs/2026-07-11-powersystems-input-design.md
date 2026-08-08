# PowerSystems.jl Input Adapter Design

## Goal

Add a PowerSystems.jl-compatible input path that imports a standard Sienna system and project-specific CSV extensions into the existing UC data structures, while retaining the legacy Excel workflow.

## Scope

- Read a `PowerSystems.System` directly and construct one from a PowerSystems CSV case directory.
- Map thermal generators, branches, loads, storage, and renewable generators.
- Read UC, frequency-control, storage, renewable-profile, and data-center extension CSV files.
- Validate component-name joins, required columns, duplicate keys, time horizons, and units.
- Preserve `readxlssheet` and `forminputdata` behavior.

## Architecture

`powersystems_reader.jl` will define a public case-directory reader and a `PowerSystems.System` conversion entry point. It will use public PowerSystems accessors and component iteration, never component fields. A small extension loader will read CSV tables and join them to PowerSystems components by unique name. The adapter will assemble the existing `unit`, `transmissionline`, `load`, `pss`, wind, and `data_centra` inputs so that the optimization layer remains unchanged.

Power values from PowerSystems will be normalized by the System base power. Time-series row count will define `NT`; no fixed 24-period assumption will be introduced for the new path.

## Case Layout

The case directory contains the regular PowerSystems CSV files and these additional files:

| File | Key | Purpose |
| --- | --- | --- |
| `thermal_uc.csv` | `generator_name` | UC operating limits, costs, initial state |
| `frequency_parameters.csv` | `device_name` | `H`, `D`, `K`, `F`, `T`, `R` response values |
| `storage_uc.csv` | `storage_name` | SOC, charge/discharge, efficiency, and self-discharge values |
| `renewable_profiles.csv` | `generator_name`, `time` | Available renewable generation by period |
| `data_centers.csv` | `data_center_name` | Bus association and data-center operating parameters |
| `data_center_workloads.csv` | `data_center_name`, `time` | Computational workload by period |

All component names must be unique within the corresponding PowerSystems component category. `time` is one-based and contiguous for each profile.

## Error Handling

The adapter throws descriptive `ArgumentError`s for missing files/columns, unknown or duplicate component names, incomplete required mappings, invalid numeric limits, non-contiguous time indices, and mismatched profile horizons. Optional feature tables may be absent only when the associated feature is disabled; otherwise the error names the missing file and feature.

## Testing

Tests will build a minimal PowerSystems system with thermal, renewable, storage, branch, and load components, materialize extension CSVs in a temporary directory, and verify every mapped field, per-unit conversion, and inferred horizon. Negative tests will cover bad joins and time-series mismatch. Existing Excel-pipeline tests remain unchanged and must still pass.

## Compatibility

PowerSystems.jl will be added as a direct dependency with a bounded compatible version. The new APIs will be exported alongside the Excel reader; no existing callers are changed.
