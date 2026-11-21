"""
自适应交叠窗 PCM 的统一方法入口。

`tools/pcm/main.jl` 通过 `PCM_OVERLAP_FORMULATION` 注入 `:standard` 或
`:clustered`。直接执行本文件时默认运行聚类交叠窗方法，以保持原有行为。
"""

overlap_formulation = isdefined(@__MODULE__, :PCM_OVERLAP_FORMULATION) ?
    PCM_OVERLAP_FORMULATION : :clustered
overlap_formulation in (:standard, :clustered) ||
    throw(ArgumentError("Unsupported overlap formulation: $overlap_formulation"))

performance_mode = lowercase(get(ENV, "PCM_PERFORMANCE_MODE", "fast"))
performance_mode in ("fast", "balanced") ||
    throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced"))

env_overrides = Pair{String, String}[
    "PCM_USE_CLUSTERED_UC" => (overlap_formulation === :clustered ? "true" : "false"),
]
haskey(ENV, "PCM_OVERLAP_MODE") || push!(env_overrides, "PCM_OVERLAP_MODE" => "ml_prediction")
if performance_mode == "fast"
    haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "load_following")
    haskey(ENV, "PCM_MIP_GAP") || push!(env_overrides, "PCM_MIP_GAP" => "0.03")
    if overlap_formulation === :clustered
        # 118 系统实测 3 分箱会削弱松弛并显著拖慢分支定界；5 分箱在
        # 模型规模和松弛强度之间表现最佳。
        haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS") || push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "5")
        haskey(ENV, "PCM_CLUSTER_REFERENCE_REPAIR") || push!(env_overrides, "PCM_CLUSTER_REFERENCE_REPAIR" => "false")
    end
else
    haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "economic_solve")
    if overlap_formulation === :clustered && !haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS")
        push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "9")
    end
end

runner = overlap_formulation === :clustered ?
    joinpath(@__DIR__, "runners", "run_clustered_adaptive_overlap.jl") :
    joinpath(@__DIR__, "runners", "export_overlap_stats.jl")
withenv(env_overrides...) do
    include(runner)
end
