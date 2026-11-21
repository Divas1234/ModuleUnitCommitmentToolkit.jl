# 自适应交叠窗工具的统一路径定义，避免脚本绑定某台机器的绝对路径。
if !isdefined(@__MODULE__, :ADAPTIVE_PCM_PROJECT_ROOT)
    const ADAPTIVE_PCM_PROJECT_ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
end
