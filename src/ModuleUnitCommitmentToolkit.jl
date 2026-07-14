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

# Unified data/algorithm orchestration entry point. Heavy algorithm implementation
# modules are loaded lazily on the first `solve_uc` call.
include("solver_interface.jl")

# Public package-level entry points. Algorithm drivers under `tools/` remain the
# implementation and compatibility layer behind the unified entry point.
export SUC_scucmodel,
    load_runtime_config!, runtime_config_entries, UCInputSpec, UCSolveRequest, UCSolveResult, BendersSetup, print_uc_result, solve_uc

end
