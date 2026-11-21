"""聚类 PCM 入口：向公共滚动驱动注入聚类主问题与物理解群策略。"""

cluster_performance_mode = lowercase(get(ENV, "PCM_PERFORMANCE_MODE", "fast"))
cluster_performance_mode in ("fast", "balanced") ||
    throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced"))
if cluster_performance_mode == "fast"
    # 118 系统实测 5 分箱比 3 分箱具有更强松弛，综合求解更快。
    get!(ENV, "PCM_CLUSTER_OUTPUT_BINS", "5")
    get!(ENV, "PCM_MIP_GAP", "0.03")
else
    get!(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")
    get!(ENV, "PCM_MIP_GAP", "0.015")
end

clustered_pcm_window_solver(args...) =
    each_period_scucmodel_modules(args...; formulation = :clustered)

PCM_WINDOW_SOLVER = clustered_pcm_window_solver
PCM_FORMULATION_NAME = "clustered"

include(joinpath(@__DIR__, "..", "rolling_pcm_driver.jl"))
