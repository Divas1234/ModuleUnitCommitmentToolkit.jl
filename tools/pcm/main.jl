# PCM 唯一程序入口。
# 通过 PCM_METHOD 选择 standard、clustered_pcm、adaptive_overlap 或 clustered_adaptive_overlap。
method=lowercase(get(ENV, "PCM_METHOD", "standard"))

if method in ("standard", "single", "single_unit")
    ENV["PCM_USE_CLUSTERED_UC"]="false"
    include("standard/pcm_main.jl")

elseif method in ("clustered_pcm", "clustered", "cluster")
    ENV["PCM_USE_CLUSTERED_UC"]="true"
    # clustered master 由 standard/period_scuc.jl 接入；仍复用同一滚动仿真驱动，
    # 确保该分支不仅加载模型定义，而且真正执行聚类 PCM。
    include("standard/pcm_main.jl")

elseif method in ("adaptive_overlap", "adaptive", "overlap")
    ENV["PCM_USE_CLUSTERED_UC"]="false"
    include("adaptive_overlap/runners/export_overlap_stats.jl")

elseif method in ("clustered_adaptive_overlap", "clustered_overlap", "adaptive_clustered", "clustered_adaptive")
    ENV["PCM_USE_CLUSTERED_UC"]="true"
    include("adaptive_overlap/runners/run_clustered_adaptive_overlap.jl")
else
    error("Unsupported PCM_METHOD='$method'. Use standard, clustered_pcm, adaptive_overlap, or clustered_adaptive_overlap.")
end

