# PCM 交叠窗核心的静态依赖契约。
#
# 正常包入口和仿真入口会预先提供这些类型与求解函数；条件 include 仅在
# 独立加载 core 时补齐依赖，同时为 Julia Language Server 提供可追踪的定义路径。
const _PCM_REQUIRED_DATA_TYPES = (:config, :unit, :transmissionline, :load, :data_centra)

if !all(name -> isdefined(@__MODULE__, name), _PCM_REQUIRED_DATA_TYPES)
    include("../../../../src/input_data/formatted_data.jl")
end

if !isdefined(@__MODULE__, :hydro)
    const hydro = Any
end

if !isdefined(@__MODULE__, :wind)
    include("../../../../src/renewables/renewables.jl")
end

if !isdefined(@__MODULE__, :each_period_scucmodel_modules)
    include("../../standard_pcm/period_scuc.jl")
end
