"""
一体化 PCM/UC 参考入口。

将原计划的 `PCM_INTERVALS × PCM_WINDOW_HOURS` 合并成单个完整时域问题，
因此不存在滚动截断和交叠窗。大规模系统可能很难求解，基准脚本可按规模选择跳过。
"""
original_intervals = parse(Int, get(ENV, "PCM_INTERVALS", "1"))
original_window = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
full_horizon = parse(Int, get(ENV, "PCM_INTEGRATED_HORIZON_HOURS",
    string(original_intervals * original_window)))
ENV["PCM_INTERVALS"] = "1"
ENV["PCM_WINDOW_HOURS"] = string(full_horizon)
println("Integrated PCM reference horizon: $full_horizon h (single optimization problem)")

integrated_pcm_window_solver(args...) =
    each_period_scucmodel_modules(args...; formulation = :standard)

PCM_WINDOW_SOLVER = integrated_pcm_window_solver
PCM_FORMULATION_NAME = "integrated"

include(joinpath(@__DIR__, "..", "rolling_pcm_driver.jl"))
