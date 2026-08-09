# PCM 唯一程序入口。
# 通过 PCM_METHOD 选择 standard、clustered_pcm 或 adaptive_overlap。
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
else
    error("Unsupported PCM_METHOD='$method'. Use standard, clustered_pcm, or adaptive_overlap.")
end
