__precompile__(false)

module ModuleUnitCommitmentToolkit

# Environment config and utilities
include("environment_config.jl")
include("runtime_config.jl")
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

# Public package-level entry points. Algorithm drivers under `tools/` remain the
# implementation and compatibility layer behind the unified entry point.
export SUC_scucmodel, load_runtime_config!, runtime_config_entries, UCInputSpec, UCSolveRequest, UCSolveResult, BendersSetup, print_uc_result,
       solve_uc, ClusteredDisaggregation, ClusterSpec, InitialUnitState, PhysicalUnitData, NetworkData, ClusterSchedule, AnonymousUnitPath,
       TrajectoryCheckResult, DisaggregationFeedback, UnitDisaggregationResult, check_cluster_trajectory_feasibility, decompose_state_flow_to_paths,
       assign_paths_to_physical_units, solve_unit_disaggregation, run_cluster_disaggregation, validate_disaggregation

# Include PCM tools in a submodule to enable LSP indexing and definition navigation (gd)
module SequentialPCM
    using ..ModuleUnitCommitmentToolkit: config, unit, transmissionline, load, data_centra, wind
    const hydro = Any

    include("../tools/pcm/standard/period_scuc.jl")
    include("../tools/pcm/adaptive_overlap/core/pcm_overlap_core.jl")
end

export SequentialPCM

end
