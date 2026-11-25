# ==============================================================================
# Production Cost Modeling (PCM) Core Library Entrypoint (生产成本模拟核心入口)
#
# Organized along two orthogonal axes plus full-horizon Benchmark
# (沿“建模粒度 × 滚动时域”正交 2×2 矩阵组织，外加全时域基准):
#   - formulations/single_unit/      : Physical single-unit window SCUC (物理单机窗口建模)
#   - formulations/clustered/        : Homogeneous clustering, PTDF, disaggregation, costs (同质聚类与解聚)
#   - horizons/fixed_rolling.jl      : Non-overlapping fixed rolling horizon (固定无交叠滚动)
#   - horizons/adaptive_overlap/     : Adaptive overlapping rolling horizon + CART ML (自适应交叠滚动)
#   - rolling_engine.jl              : Unified `run_pcm` & `run_pcm_benchmark` (统一调度引擎)
#   - benchmark_comparison.jl        : 4-method PCM vs Benchmark comparison (四方法对比汇总)
# ==============================================================================

if !isdefined(@__MODULE__, :_PCM_CORE_INCLUDED)
    const _PCM_CORE_INCLUDED = true

    include("configuration.jl")
    include("formulations/clustered/unit_disaggregation.jl")
    include("formulations/clustered/cluster_adapter.jl")
    include("formulations/clustered/network_dispatch.jl")
    include("formulations/clustered/economic_costs.jl")
    include("formulations/clustered/residence_hull.jl")
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
