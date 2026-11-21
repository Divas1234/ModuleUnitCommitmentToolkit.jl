module ModuleUnitCommitmentToolkit

# Environment config and utilities
include("environment_config.jl")
include("runtime_config.jl")
include("optimizer_config.jl")
include("api_types.jl")
include("output_reporting.jl")

# Renewable simulation
include("renewables/stochastic_simulation.jl")

# Input data loaders and bridges
include("input_data/readers.jl")

# Unit commitment models and constraints
include("unit_commitment/unit_commitment_model.jl")
include("unit_commitment/clustered_pcm/clustered_pcm.jl")
using .ClusteredDisaggregation

# Unified data/algorithm orchestration entry point. Heavy algorithm implementation
# modules are loaded lazily on the first `solve_uc` call.
include("solver_interface.jl")

# Include PCM tools in a submodule for package-level access and LSP indexing
module SequentialPCM
    using ..ModuleUnitCommitmentToolkit: config, unit, transmissionline, load, data_centra, wind
    const hydro = Any

    include("../tools/pcm/standard/period_scuc.jl")
    include("../tools/pcm/clustered_overlap/core/pcm_overlap_core.jl")
end

# Public package-level entry points. Algorithm drivers under `tools/` remain the
# implementation and compatibility layer behind the unified entry point.
export SUC_scucmodel,
    load_uc_data,
    config_from_env,
    load_runtime_config!,
    runtime_config_entries,
    uc_env_bool,
    uc_env_int,
    uc_env_float,
    uc_load_curtailment_penalty,
    uc_wind_curtailment_penalty,
    known_uc_calibration_keys,
    default_uc_optimizer,
    set_default_uc_optimizer!,
    with_uc_optimizer,
    build_uc_model,
    uc_has_feasible_solution,
    uc_require_feasible_solution!,
    UCConfig,
    ThermalUnits,
    TransmissionLines,
    Loads,
    StorageUnits,
    DataCenters,
    WindUnits,
    UCInputSpec,
    UCSolveRequest,
    UCSolveResult,
    BendersSetup,
    print_uc_result,
    solve_uc,
    register_uc_algorithm!,
    unregister_uc_algorithm!,
    registered_uc_algorithms,
    register_uc_data_loader!,
    unregister_uc_data_loader!,
    registered_uc_data_loaders,
    register_uc_exporter!,
    unregister_uc_exporter!,
    registered_uc_exporters,
    run_uc_exporters,
    register_uc_constraint_hook!,
    registered_uc_constraint_hooks,
    clear_uc_constraint_hooks!,
    register_uc_variable_hook!,
    registered_uc_variable_hooks,
    clear_uc_variable_hooks!,
    register_uc_objective_hook!,
    registered_uc_objective_hooks,
    clear_uc_objective_hooks!,
    clear_all_uc_hooks!,
    ClusteredDisaggregation,
    ClusterSpec,
    InitialUnitState,
    PhysicalUnitData,
    NetworkData,
    ClusterSchedule,
    AnonymousUnitPath,
    TrajectoryCheckResult,
    DisaggregationFeedback,
    UnitDisaggregationResult,
    check_cluster_trajectory_feasibility,
    decompose_state_flow_to_paths,
    assign_paths_to_physical_units,
    solve_unit_disaggregation,
    run_cluster_disaggregation,
    validate_disaggregation,
    SequentialPCM

end
