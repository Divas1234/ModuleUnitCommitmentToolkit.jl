# PCM 唯一程序入口。
# 通过 PCM_METHOD 选择 standard、clustered_pcm、adaptive_overlap 或 clustered_adaptive_overlap。
method=lowercase(get(ENV, "PCM_METHOD", "standard"))

if method in ("standard", "single", "single_unit", "integrated_uc", "uc_reference")
	include("standard_pcm/main.jl")

elseif method in ("clustered_pcm", "clustered", "cluster")
	include("clustered_pcm/main.jl")

elseif method in ("adaptive_overlap", "adaptive", "overlap",
		"clustered_adaptive_overlap", "clustered_overlap", "adaptive_clustered", "clustered_adaptive")
	# 两类交叠窗共用同一入口，只在这里注入是否启用聚类的策略。
	PCM_OVERLAP_FORMULATION = method in ("adaptive_overlap", "adaptive", "overlap") ?
		:standard : :clustered
	include("clustered_overlap_pcm/main.jl")
else
	error("Unsupported PCM_METHOD='$method'. Use standard, clustered_pcm, adaptive_overlap, or clustered_adaptive_overlap.")
end
