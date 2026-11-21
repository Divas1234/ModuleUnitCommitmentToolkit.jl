"""
Centralized compatibility and deprecation registry for ModuleUnitCommitmentToolkit.jl.

Canonical naming conventions for new code:
- Domain structs: `UCConfig`, `ThermalUnits`, `TransmissionLines`, `Loads`,
  `StorageUnits`, `DataCenters`, `WindUnits`, `UCProblemData`
- Parameter names: `storages` (replaces `psses` / `stroges`),
  `data_centers` (replaces `DataCentras` / `data_centra`),
  `startup_ramp` / `min_up_time` (replaces `shut_up` / `min_shutup_time`)
- Functions: `boundary_condition` (replaces `boundrycondition` / `boundarycondition`)
- JuMP variables: access via `uc_variable(model, :p_gen)` etc. instead of raw Unicode symbols.

Legacy aliases remain active for backward compatibility and are tracked here for
scheduled removal in a future major release.
"""

const LEGACY_NAMING_MIGRATION = Dict{Symbol, Symbol}(
    :config => :UCConfig,
    :unit => :ThermalUnits,
    :transmissionline => :TransmissionLines,
    :load => :Loads,
    :pss => :StorageUnits,
    :psses => :storages,
    :stroges => :storages,
    :data_centra => :DataCenters,
    :DataCentras => :data_centers,
    :wind => :WindUnits,
    :boundrycondition => :boundary_condition,
    :shut_up => :startup_ramp,
    :min_shutup_time => :min_up_time,
)
