"""
自适应交叠窗 PCM 的统一方法入口。

`tools/pcm/main.jl` 通过 `PCM_OVERLAP_FORMULATION` 注入 `:standard` 或
`:clustered`。直接执行本文件时默认运行聚类交叠窗方法，以保持原有行为。
"""

overlap_formulation = isdefined(@__MODULE__, :PCM_OVERLAP_FORMULATION) ?
    PCM_OVERLAP_FORMULATION : :clustered
overlap_formulation in (:standard, :clustered) ||
    throw(ArgumentError("Unsupported overlap formulation: $overlap_formulation"))

ENV["PCM_USE_CLUSTERED_UC"] = overlap_formulation === :clustered ? "true" : "false"
ENV["PCM_OVERLAP_MODE"] = "ml_prediction"
# 交叠窗会放大时域；较少的出力状态分箱显著压缩扩展凸包。用户仍可用
# PCM_CLUSTER_OUTPUT_BINS 覆盖，固定窗 clustered_pcm 的默认精度不受影响。
performance_mode = lowercase(get(ENV, "PCM_PERFORMANCE_MODE", "fast"))
performance_mode in ("fast", "balanced") ||
    throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced"))
if performance_mode == "fast"
    get!(ENV, "PCM_OVERLAP_REFERENCE_MODE", "load_following")
    get!(ENV, "PCM_MIP_GAP", "0.03")
    if overlap_formulation === :clustered
        # 118 系统实测 3 分箱会削弱松弛并显著拖慢分支定界；5 分箱在
        # 模型规模和松弛强度之间表现最佳。
        get!(ENV, "PCM_CLUSTER_OUTPUT_BINS", "5")
        get!(ENV, "PCM_CLUSTER_REFERENCE_REPAIR", "false")
    end
else
    get!(ENV, "PCM_OVERLAP_REFERENCE_MODE", "economic_solve")
    overlap_formulation === :clustered && get!(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")
end

runner = overlap_formulation === :clustered ?
    joinpath(@__DIR__, "runners", "run_clustered_adaptive_overlap.jl") :
    joinpath(@__DIR__, "runners", "export_overlap_stats.jl")
include(runner)
