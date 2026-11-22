"""
    src/production_cost/rolling_engine.jl

Unified PCM execution engine dispatching over the 2x2 orthogonal method matrix
(SingleUnit / Clustered × FixedHorizon / AdaptiveOverlap) plus the full-horizon
Integrated UC Benchmark.
"""

"""
    run_pcm(formulation::AbstractPCMFormulation, policy::AbstractPCMHorizonPolicy; cfg = PCMConfig())

Run one of the 4 orthogonal PCM methods:
1. `(SingleUnitFormulation(), FixedHorizonPolicy())`      — standard (no cluster, no overlap)
2. `(SingleUnitFormulation(), AdaptiveOverlapPolicy())`   — adaptive_overlap (no cluster, with overlap)
3. `(ClusteredFormulation(), FixedHorizonPolicy())`       — clustered (cluster, no overlap)
4. `(ClusteredFormulation(), AdaptiveOverlapPolicy())`    — clustered_overlap (cluster, with overlap)
"""
function run_pcm(
    formulation::AbstractPCMFormulation,
    policy::FixedHorizonPolicy;
    cfg::PCMConfig = PCMConfig(),
    label::String = "",
)
    return execute_fixed_horizon_pcm(formulation, policy; cfg = cfg, label = label)
end

function run_pcm(
    formulation::AbstractPCMFormulation,
    policy::AdaptiveOverlapPolicy;
    cfg::PCMConfig = PCMConfig(),
    label::String = "",
)
    return execute_adaptive_overlap_pcm(formulation, policy; cfg = cfg, label = label)
end

"""
    run_pcm(method::Union{Symbol, AbstractString}; cfg = PCMConfig())

Convenience dispatch by canonical method name (`:standard`, `:adaptive_overlap`,
`:clustered`, `:clustered_overlap`, or `:benchmark`).
"""
function run_pcm(method::Union{Symbol, AbstractString}; cfg::PCMConfig = PCMConfig())
    name, formulation, policy, is_bench = pcm_method_spec(method; cfg = cfg)
    if is_bench
        return run_pcm_benchmark(; cfg = cfg, horizon_hours = policy.window_hours)
    end
    return run_pcm(formulation, policy; cfg = cfg, label = String(name))
end

"""
    run_pcm_benchmark(; cfg = PCMConfig(), horizon_hours = nothing)

Solve the full-horizon Integrated UC Benchmark (`intervals = 1`, `window_hours = total_horizon`)
as the exact reference baseline for comparing all 4 PCM methods.
"""
function run_pcm_benchmark(; cfg::PCMConfig = PCMConfig(), horizon_hours::Union{Nothing, Int} = nothing)
    total_h = horizon_hours === nothing ? (cfg.intervals * cfg.window_hours) : horizon_hours
    policy = FixedHorizonPolicy(window_hours = total_h, intervals = 1)
    return execute_fixed_horizon_pcm(SingleUnitFormulation(), policy; cfg = cfg, label = "benchmark")
end
