# ==============================================================================
# Core UC Algorithms Entrypoint (核心机组组合算法统一入口)
#
# Precompiled solver families (预编译核心求解算法族):
#   1. Benders Decomposition (强化多割 Benders 分解: 分组 Jensen 割 + 频率单调逻辑割)
#      models/entry.jl -> cuts/entry.jl -> decomposition.jl -> setup.jl
#   2. Column-and-Constraint Generation (C&CG + Wasserstein DRO 分布鲁棒优化)
#      ccg/dro_uncertainty.jl -> ccg/helpers.jl -> ccg/solver.jl
#   3. Extensive-Form Benchmark (全场景扩展型基准求解器)
#      benchmark/extensive_uc.jl
# ==============================================================================
if !isdefined(@__MODULE__, :_UC_ALGORITHMS_INCLUDED)
    const _UC_ALGORITHMS_INCLUDED = true

    include("benders/models/entry.jl")
    include("benders/cuts/entry.jl")
    include("benders/decomposition.jl")
    include("benders/setup.jl")

    include("ccg/dro_uncertainty.jl")
    include("ccg/helpers.jl")
    include("ccg/solver.jl")

    include("benchmark/extensive_uc.jl")
end
