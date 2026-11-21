"""标准无交叠 PCM 入口：向公共滚动驱动注入物理单机求解策略。"""

standard_performance_mode = lowercase(get(ENV, "PCM_PERFORMANCE_MODE", "fast"))
standard_performance_mode in ("fast", "balanced") ||
    throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced"))
get!(ENV, "PCM_MIP_GAP", standard_performance_mode == "fast" ? "0.03" : "0.015")

standard_pcm_window_solver(args...) =
    each_period_scucmodel_modules(args...; formulation = :standard)

PCM_WINDOW_SOLVER = standard_pcm_window_solver
PCM_FORMULATION_NAME = "standard"

include(joinpath(@__DIR__, "..", "rolling_pcm_driver.jl"))
