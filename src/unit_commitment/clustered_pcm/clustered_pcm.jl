# 聚类机组组合（Clustered UC）核心算法统一入口。
#
# 本目录只放与 PCM 无关的通用算法和数据结构，不负责读取 Excel、滚动窗口
# 或结果落盘。因此合并到主分支后，也可以被其他 UC 工作流复用。
if !isdefined(@__MODULE__, :ClusteredDisaggregation)
    include("disaggregation.jl")
end
