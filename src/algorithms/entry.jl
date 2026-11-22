# Precompiled core UC algorithms: Benders Decomposition, C&CG, and Extensive-Form Benchmark.
if !isdefined(@__MODULE__, :_UC_ALGORITHMS_INCLUDED)
    const _UC_ALGORITHMS_INCLUDED = true

    include("benders/models/construct_models.jl")
    include("benders/cuts/construct_cuts.jl")
    include("benders/decomposition.jl")
    include("benders/setup.jl")

    include("ccg/dro_uncertainty.jl")
    include("ccg/helpers.jl")
    include("ccg/solver.jl")

    include("benchmark/extensive_uc.jl")
end
