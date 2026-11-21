"""
    src/pcm/rolling_engine.jl

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
    t0 = time()
    is_clustered = formulation isa ClusteredFormulation
    method_label = isempty(label) ? (is_clustered ? "clustered_overlap" : "adaptive_overlap") : label
    perf = cfg.performance_mode
    perf in ("fast", "balanced") || throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced; got '$perf'"))

    env_overrides = Pair{String, String}[
        "PCM_USE_CLUSTERED_UC" => (is_clustered ? "true" : "false"),
        "PCM_LOAD_PROFILE" => cfg.load_profile,
        "PCM_WINDOW_HOURS" => string(policy.window_hours),
        "PCM_INTERVALS" => string(policy.intervals),
        "PCM_NETWORK_CONSTRAINTS" => (cfg.network_constraints ? "1" : "0"),
        "PCM_RANDOM_SEED" => string(cfg.random_seed),
    ]
    cfg.data_file !== nothing && push!(env_overrides, "MODULE_UC_DATA_FILE" => cfg.data_file)
    haskey(ENV, "PCM_OVERLAP_MODE") || push!(env_overrides, "PCM_OVERLAP_MODE" => policy.overlap_mode)
    if perf == "fast"
        haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "load_following")
        haskey(ENV, "PCM_MIP_GAP") || push!(env_overrides, "PCM_MIP_GAP" => "0.03")
        if is_clustered
            haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS") || push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "5")
            haskey(ENV, "PCM_CLUSTER_REFERENCE_REPAIR") || push!(env_overrides, "PCM_CLUSTER_REFERENCE_REPAIR" => "false")
        end
    else
        haskey(ENV, "PCM_OVERLAP_REFERENCE_MODE") || push!(env_overrides, "PCM_OVERLAP_REFERENCE_MODE" => "economic_solve")
        if is_clustered && !haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS")
            push!(env_overrides, "PCM_CLUSTER_OUTPUT_BINS" => "9")
        end
    end

    project_root = normpath(joinpath(@__DIR__, "..", ".."))
    runner_rel = is_clustered ?
        joinpath("tools", "pcm", "experiments", "runners", "clustered_overlap_runner.jl") :
        joinpath("tools", "pcm", "experiments", "runners", "overlap_stats_exporter.jl")
    runner_path = joinpath(project_root, runner_rel)

    res = withenv(env_overrides...) do
        Base.include(Main, runner_path)
    end
    elapsed = time() - t0
    cost_val = if res isa NamedTuple && haskey(res, :total_cost)
        Float64(res.total_cost)
    elseif res isa AbstractDict && haskey(res, "total_cost")
        Float64(res["total_cost"])
    else
        NaN
    end
    return (
        method = method_label,
        formulation = is_clustered ? :clustered : :standard,
        overlap = true,
        status = "COMPLETED",
        total_cost = cost_val,
        runtime_seconds = elapsed,
        intervals = policy.intervals,
        window_hours = policy.window_hours,
        total_hours = policy.intervals * policy.window_hours,
        raw = res,
    )
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
