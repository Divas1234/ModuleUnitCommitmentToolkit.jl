# PCM 聚类扩展的统一入口，外部代码只需 include 本文件。
#
# 文件分工：
# - adapter.jl：旧 PCM 数据/结果与聚类数据结构之间的适配层；
# - clustered_solver.jl：同质化聚类以及聚合 U/Y/Z/P/R 求解器；
# - network_dispatch.jl：固定启停状态后的物理单机网络再调度。
include("adapter.jl")
include("network_dispatch.jl")
include("costs.jl")
include("clustered_solver.jl")
