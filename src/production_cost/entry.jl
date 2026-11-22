# Central entry point for the Production Cost Modeling (PCM) core library.
# Organized along two orthogonal axes + full-horizon Benchmark:
#   - formulations/single_unit/      : Physical single-unit window SCUC
#   - formulations/clustered/        : Homogeneous clustering, PTDF, disaggregation, costs
#   - horizons/fixed_rolling.jl      : Non-overlapping fixed rolling horizon
#   - horizons/adaptive_overlap/     : Adaptive overlapping rolling horizon
#   - rolling_engine.jl              : Unified `run_pcm` & `run_pcm_benchmark`
#   - benchmark_comparison.jl        : 4-method PCM vs Benchmark comparison

if !isdefined(@__MODULE__, :_PCM_CORE_INCLUDED)
    const _PCM_CORE_INCLUDED = true

    include("configuration.jl")
    include("formulations/clustered/unit_disaggregation.jl")
    include("formulations/clustered/cluster_adapter.jl")
    include("formulations/clustered/network_dispatch.jl")
    include("formulations/clustered/economic_costs.jl")
    include("formulations/clustered/master_solver.jl")
    include("formulations/single_unit/window_scuc.jl")

    include("horizons/adaptive_overlap/training_cache.jl")
    include("horizons/adaptive_overlap/ml_predictor.jl")
    using .OverlapPredictor
    using LinearAlgebra, Statistics
    include("horizons/adaptive_overlap/operating_features.jl")
    include("horizons/adaptive_overlap/loss_models.jl")
    include("horizons/adaptive_overlap/boundary_reference.jl")
    include("horizons/adaptive_overlap/model_calibration.jl")
    include("horizons/adaptive_overlap/window_selector.jl")
    include("horizons/adaptive_overlap/state_commit.jl")
    include("horizons/adaptive_overlap/adaptive_rolling.jl")

    include("horizons/fixed_rolling.jl")
    include("rolling_engine.jl")
    include("benchmark_comparison.jl")
end
