"""
    src/production_cost/benchmark_comparison.jl

4-Method PCM vs Benchmark comparison engine.
Runs the 2x2 PCM method matrix (`standard`, `adaptive_overlap`, `clustered`,
`clustered_overlap`) alongside the full-horizon `benchmark` reference, computes
cost error (%) and speedup (x) relative to Benchmark, prints a structured
DataFrame summary, and optionally exports CSV results.
"""

using CSV
using DataFrames
using Printf

const PCM_MATRIX_METHODS = (:standard, :adaptive_overlap, :clustered, :clustered_overlap)

"""
    compare_pcm_methods(; methods = PCM_MATRIX_METHODS, include_benchmark = true, cfg = PCMConfig(), output_dir = nothing)

Execute the selected PCM methods and (optionally) the full-horizon `benchmark`
reference under identical `PCMConfig`, returning `(summary_df, results, csv_path)`.
"""
function compare_pcm_methods(;
    methods = PCM_MATRIX_METHODS,
    include_benchmark::Bool = true,
    cfg::PCMConfig = PCMConfig(),
    output_dir::Union{Nothing, AbstractString} = nothing,
)
    results = OrderedDict{Symbol, Any}()

    bench_cost = NaN
    bench_time = NaN
    if include_benchmark
        println("\n[PCM Benchmark] Solving full-horizon reference ($(cfg.intervals * cfg.window_hours)h)...")
        bench_res = run_pcm_benchmark(; cfg = cfg)
        results[:benchmark] = bench_res
        bench_cost = bench_res.total_cost
        bench_time = bench_res.runtime_seconds
    end

    for m in methods
        canon, _, _, _ = pcm_method_spec(m; cfg = cfg)
        println("\n[PCM Method] Running $(canon) (profile=$(cfg.load_profile), $(cfg.intervals)x$(cfg.window_hours)h)...")
        results[canon] = run_pcm(canon; cfg = cfg)
    end

    rows_method = String[]
    rows_formulation = String[]
    rows_overlap = String[]
    rows_status = String[]
    rows_cost = Float64[]
    rows_cost_err = Float64[]
    rows_time = Float64[]
    rows_speedup = Float64[]

    for (key, r) in results
        push!(rows_method, String(key))
        push!(rows_formulation, String(r.formulation))
        push!(rows_overlap, key === :benchmark ? "full_horizon" : (r.overlap ? "adaptive_overlap" : "fixed_horizon"))
        push!(rows_status, String(r.status))
        push!(rows_cost, round(Float64(r.total_cost); digits = 4))
        err_pct = (isfinite(bench_cost) && abs(bench_cost) > eps(Float64) && isfinite(r.total_cost)) ?
            round(100.0 * (r.total_cost - bench_cost) / abs(bench_cost); digits = 4) : NaN
        push!(rows_cost_err, err_pct)
        push!(rows_time, round(Float64(r.runtime_seconds); digits = 4))
        spd = (isfinite(bench_time) && r.runtime_seconds > eps(Float64)) ?
            round(bench_time / r.runtime_seconds; digits = 2) : NaN
        push!(rows_speedup, spd)
    end

    summary_df = DataFrame(
        method = rows_method,
        formulation = rows_formulation,
        horizon_policy = rows_overlap,
        status = rows_status,
        total_cost = rows_cost,
        cost_error_pct = rows_cost_err,
        runtime_s = rows_time,
        speedup_vs_bench = rows_speedup,
    )

    println("\n" * "="^88)
    println("PCM 2x2 Method Matrix vs Full-Horizon Benchmark Summary")
    println("="^88)
    io = IOContext(stdout, :displaysize => (100, 140), :compact => true)
    show(io, summary_df; allrows = true, allcols = true, eltypes = false)
    println()

    csv_path = nothing
    if output_dir !== nothing
        mkpath(output_dir)
        csv_path = joinpath(output_dir, "pcm_2x2_vs_benchmark_summary.csv")
        CSV.write(csv_path, summary_df)
        println("PCM comparison summary saved to: ", csv_path)
    end

    return (summary_df = summary_df, results = results, csv_path = csv_path)
end
