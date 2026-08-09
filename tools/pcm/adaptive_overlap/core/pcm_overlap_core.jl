# PCM 自适应交叠窗正式入口；组件顺序即算法依赖顺序。
if !isdefined(@__MODULE__, :_PCM_OVERLAP_CORE_INCLUDED)
    const _PCM_OVERLAP_CORE_INCLUDED = true
    include("pcm_dependencies.jl")
    include("training_data_cache.jl")
    include("overlap_predictor.jl")
    using .OverlapPredictor
    using LinearAlgebra, Statistics

    # 必须使用显式 include：Julia Language Server 依靠静态 include 图解析
    # 跨文件类型和函数；动态循环加载会产生错误的 Missing reference 提示。
    include("generator_operating_features.jl")
    include("accuracy_loss_models.jl")
    include("boundary_reference_policy.jl")
    include("accuracy_model_calibration.jl")
    include("overlap_window_policy.jl")
    include("rolling_state_commit.jl")
end
