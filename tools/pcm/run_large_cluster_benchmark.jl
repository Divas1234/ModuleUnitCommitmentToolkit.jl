# 大规模同质机组 PCM 基准：在独立 Julia 进程中公平比较单机与聚类建模。
using Dates, CSV, DataFrames, Statistics

const ROOT=normpath(joinpath(@__DIR__, "..", ".."))
const INPUT=abspath(get(ENV, "PCM_LARGE_INPUT", joinpath(ROOT, "data", "data_118_clustered_pcm_10x.xlsx")))
const RUNS=parse(Int, get(ENV, "PCM_BENCHMARK_RUNS", "3"))
const INTERVALS=parse(Int, get(ENV, "PCM_INTERVALS", "1"))
const WINDOW_HOURS=parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
const STAMP=get(ENV, "PCM_BENCHMARK_ID", Dates.format(now(), "yyyymmdd_HHMMSS"))
const OUTDIR=abspath(get(ENV, "PCM_BENCHMARK_OUTPUT", joinpath(ROOT, "output", "pcm_benchmark", "large_cluster_10x_$(STAMP)")))
const METRICS=joinpath(OUTDIR, "metrics.csv")

isfile(INPUT)||error("Large-scale PCM input not found: $INPUT")
mkpath(OUTDIR)

base_env=Dict(
    "PCM_INPUT_XLSX"=>INPUT,
    "MODULE_UC_DATA_FILE"=>INPUT,
    "PCM_NETWORK_CONSTRAINTS"=>get(ENV, "PCM_NETWORK_CONSTRAINTS", "0"),
    "PCM_LOAD_PROFILE"=>get(ENV, "PCM_LOAD_PROFILE", "baseline"),
    "PCM_RANDOM_SEED"=>get(ENV, "PCM_RANDOM_SEED", "20260809"),
    "PCM_WINDOW_HOURS"=>string(WINDOW_HOURS),
    "PCM_INTERVALS"=>string(INTERVALS),
    "PCM_BENCHMARK_METRICS"=>METRICS,
)

for repetition ∈ 1:RUNS, method ∈ ("standard", "clustered_pcm")
    log_path=joinpath(OUTDIR, "$(method)_run$(repetition).log")
    command=`$(Base.julia_cmd()) --project=$(ROOT) $(joinpath(@__DIR__, "benchmark_method.jl"))`
    env=merge(base_env, Dict("PCM_METHOD"=>method))
    println("[$(now())] run=$repetition method=$method log=$log_path")
    open(log_path, "w") do io
        process=run(pipeline(addenv(command, env), stdout = io, stderr = io); wait = false)
        wait(process)
        success(process)||println("  run failed; inspect $log_path")
    end
end

metrics=CSV.read(METRICS, DataFrame)
runs_recorded=minimum(combine(groupby(metrics, :method), nrow=>:runs).runs)
summary=combine(groupby(metrics, :method),
    :status=>(x->count(==("OK"), x))=>:successful_runs,
    :wall_time_sec=>median∘skipmissing=>:median_wall_time_sec,
    :allocated_mb=>median∘skipmissing=>:median_allocated_mb,
    :peak_rss_mb=>median∘skipmissing=>:median_peak_rss_mb,
    :physical_units=>first=>:physical_units,
    :virtual_units=>first=>:virtual_units,
    :commitment_integer_variables=>first=>:commitment_integer_variables,
    :cluster_attempts=>sum=>:cluster_attempts,
    :cluster_successes=>sum=>:cluster_successes,
    :cluster_fallbacks=>sum=>:cluster_fallbacks,
    :total_cost=>median∘skipmissing=>:median_total_cost)
standard=only(eachrow(summary[summary.method .== "standard", :]))
clustered=only(eachrow(summary[summary.method .== "clustered_pcm", :]))
summary.speedup_vs_standard=map(eachrow(summary)) do row
    row.method=="clustered_pcm" ? standard.median_wall_time_sec/row.median_wall_time_sec : 1.0
end
summary.integer_variable_reduction=map(eachrow(summary)) do row
    1-row.commitment_integer_variables/standard.commitment_integer_variables
end
summary.cost_delta_vs_standard=map(eachrow(summary)) do row
    row.median_total_cost/standard.median_total_cost-1
end
CSV.write(joinpath(OUTDIR, "summary.csv"), summary)

open(joinpath(OUTDIR, "README.md"), "w") do io
    network_constraints=base_env["PCM_NETWORK_CONSTRAINTS"]
    println(io, "# 10x homogeneous-unit PCM benchmark\n")
    println(io, "- Input: `$(relpath(INPUT, ROOT))`")
    println(io, "- Runs per method: $runs_recorded")
    println(io, "- Horizon: $(INTERVALS*WINDOW_HOURS) h ($(INTERVALS) × $(WINDOW_HOURS) h)")
    println(io, "- Network constraints: $network_constraints\n")
    show(io, MIME("text/plain"), summary)
end
println("Benchmark complete: $OUTDIR")
