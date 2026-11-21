using CSV, DataFrames, Printf, Dates, Statistics
include("../paths.jl")

const ROOT = ADAPTIVE_PCM_PROJECT_ROOT
const ARCHIVE_ROOT = joinpath(ROOT, "output", "archive")

function find_files(root::String, filename::String)
    matches = String[]
    if !isdir(root)
        return matches
    end
    for (dirpath, _, files) ∈ walkdir(root)
        if filename in files
            push!(matches, joinpath(dirpath, filename))
        end
    end
    return sort(matches)
end

function experiment_dir(perf_path::String)
    marker = joinpath("output", "details_schedule_results", "adaptive_pcm_simulation_results", "criteria_combination_performance.csv")
    if endswith(perf_path, marker)
        return perf_path[1:(lastindex(perf_path) - lastindex(marker) - 1)]
    end
    return dirname(perf_path)
end

function experiment_label(exp_dir::String)
    return basename(normpath(exp_dir))
end

function scenario_type(label::String)
    occursin("extreme_ramp", lowercase(label)) && return "extreme_ramp"
    occursin("ieee118", lowercase(label)) && return "ieee118_reconstructed_load"
    occursin("ieee6", lowercase(label)) && return "ieee6"
    return "unknown"
end

function safe_col(df::DataFrame, name::Symbol, default)
    return name in propertynames(df) ? df[!, name] : fill(default, nrow(df))
end

function fmt_float(x; digits = 2)
    if x isa Missing || !isfinite(Float64(x))
        return "NA"
    end
    return string(round(Float64(x); digits = digits))
end

function write_experiment_summary(exp_dir::String, perf_path::String)
    df = CSV.read(perf_path, DataFrame)
    label = experiment_label(exp_dir)
    scenario = scenario_type(label)

    out_dir = dirname(perf_path)
    summary_csv = joinpath(out_dir, "criteria_performance_summary.csv")
    summary_md = joinpath(out_dir, "criteria_performance_summary.md")

    baseline_idx = findfirst(==("Steady+Unit+Ramp"), df.Mode)
    if baseline_idx === nothing
        baseline_idx = argmin(df.TotalCost_USD)
    end
    baseline_cost = df.TotalCost_USD[baseline_idx]
    no_overlap_idx = findfirst(==("NoOverlap"), df.Mode)
    baseline_time = no_overlap_idx === nothing ? minimum(df.SubproblemSolveTime_sec) : df.SubproblemSolveTime_sec[no_overlap_idx]
    min_cost = minimum(df.TotalCost_USD)
    min_time = minimum(df.SubproblemSolveTime_sec)
    min_memory = minimum(df.JuliaAllocated_MB)

    out = DataFrame(; Experiment = fill(label, nrow(df)), Scenario = fill(scenario, nrow(df)), Mode = df.Mode, TotalCost_USD = df.TotalCost_USD,
        CostGap_vs_All_pct = safe_col(df, :CostGap_vs_All_pct, 100.0 .* (df.TotalCost_USD .- baseline_cost) ./ baseline_cost),
        CostGap_vs_Best_pct = 100.0 .* (df.TotalCost_USD .- min_cost) ./ min_cost, SubproblemSolveTime_sec = df.SubproblemSolveTime_sec,
        SolveTimeDelta_vs_NoOverlap_sec = safe_col(df, :SolveTimeDelta_vs_NoOverlap_sec, df.SubproblemSolveTime_sec .- baseline_time),
        SolveTimeGap_vs_Fastest_pct = 100.0 .* (df.SubproblemSolveTime_sec .- min_time) ./ min_time,
        JuliaAllocated_MB = df.JuliaAllocated_MB, MemoryGap_vs_Lowest_pct = 100.0 .* (df.JuliaAllocated_MB .- min_memory) ./ min_memory,
        AvgOverlap_h = df.AvgOverlap_h, MaxOverlap_h = df.MaxOverlap_h, MinOverlap_h = df.MinOverlap_h,
        LoadShedding_MWh = df.LoadShedding_MWh, WindCurtailment_MWh = df.WindCurtailment_MWh,
        LimitingFactorCounts = df.LimitingFactorCounts, CalibrationTime_excluded_sec = safe_col(df, :CalibrationTime_excluded_sec, missing),
        ReferenceTime_excluded_sec = safe_col(df, :ReferenceTime_excluded_sec, missing))
    CSV.write(summary_csv, out)

    # 使用显式列索引，避免静态分析器把 DataFrame 动态属性误判为缺失引用。
    best_cost_row = out[Base.argmin(out[!, :TotalCost_USD]), :]
    fastest_row = out[Base.argmin(out[!, :SubproblemSolveTime_sec]), :]
    lowest_memory_row = out[Base.argmin(out[!, :JuliaAllocated_MB]), :]

    open(summary_md, "w") do io
        println(io, "# Criteria Combination Performance Summary")
        println(io)
        println(io, "- Experiment: `$label`")
        println(io, "- Scenario: `$scenario`")
        println(io, "- Source: `$perf_path`")
        println(io, "- Generated: `$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))`")
        println(io)
        println(io, "## Key Findings")
        println(io)
        println(io, "- Lowest total cost: `$(best_cost_row.Mode)` at `$(fmt_float(best_cost_row.TotalCost_USD; digits=2))` USD.")
        println(io, "- Fastest rolling simulation: `$(fastest_row.Mode)` at `$(fmt_float(fastest_row.SubproblemSolveTime_sec; digits=2))` s.")
        println(io, "- Lowest Julia allocation: `$(lowest_memory_row.Mode)` at `$(fmt_float(lowest_memory_row.JuliaAllocated_MB; digits=2))` MB.")
        println(io, "- Calibration time is excluded from operational runtime; reference no-boundary solve time is also reported separately when available.")
        println(io)
        println(io, "## Results")
        println(io)
        println(io, "| Mode | Cost USD | Gap vs All % | Gap vs Best % | Solve s | Delta vs NoOverlap s | Memory MB | Avg Overlap h | Load Shed | Wind Curtail |")
        println(io, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for r ∈ eachrow(out)
            println(io,
                "| $(r.Mode) | $(fmt_float(r.TotalCost_USD; digits=2)) | $(fmt_float(r.CostGap_vs_All_pct; digits=4)) | $(fmt_float(r.CostGap_vs_Best_pct; digits=4)) | $(fmt_float(r.SubproblemSolveTime_sec; digits=2)) | $(fmt_float(r.SolveTimeDelta_vs_NoOverlap_sec; digits=2)) | $(fmt_float(r.JuliaAllocated_MB; digits=2)) | $(fmt_float(r.AvgOverlap_h; digits=2)) | $(fmt_float(r.LoadShedding_MWh; digits=2)) | $(fmt_float(r.WindCurtailment_MWh; digits=2)) |")
        end
    end

    return out, summary_csv, summary_md
end

function main()
    perf_files = find_files(ARCHIVE_ROOT, "criteria_combination_performance.csv")
    if isempty(perf_files)
        error("No criteria_combination_performance.csv files found under $ARCHIVE_ROOT")
    end

    all_rows = DataFrame()
    generated_files = String[]
    for perf_path ∈ perf_files
        exp_dir = experiment_dir(perf_path)
        summary, summary_csv, summary_md = write_experiment_summary(exp_dir, perf_path)
        append!(all_rows, summary; cols = :union)
        push!(generated_files, summary_csv)
        push!(generated_files, summary_md)
    end

    cross_csv = joinpath(ARCHIVE_ROOT, "criteria_combinations_cross_archive_summary.csv")
    cross_md = joinpath(ARCHIVE_ROOT, "criteria_combinations_cross_archive_summary.md")
    CSV.write(cross_csv, all_rows)

    open(cross_md, "w") do io
        println(io, "# Cross-Archive Criteria Combination Summary")
        println(io)
        println(io, "- Archive root: `$ARCHIVE_ROOT`")
        println(io, "- Generated: `$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))`")
        println(io, "- Experiments summarized: `$(length(unique(all_rows.Experiment)))`")
        println(io)
        println(io, "## Consolidated Results")
        println(io)
        println(io, "| Experiment | Scenario | Mode | Cost USD | Gap vs All % | Solve s | Memory MB | Avg Overlap h | Load Shed | Wind Curtail |")
        println(io, "|---|---|---|---:|---:|---:|---:|---:|---:|---:|")
        for r ∈ eachrow(all_rows)
            println(io,
                "| $(r.Experiment) | $(r.Scenario) | $(r.Mode) | $(fmt_float(r.TotalCost_USD; digits=2)) | $(fmt_float(r.CostGap_vs_All_pct; digits=4)) | $(fmt_float(r.SubproblemSolveTime_sec; digits=2)) | $(fmt_float(r.JuliaAllocated_MB; digits=2)) | $(fmt_float(r.AvgOverlap_h; digits=2)) | $(fmt_float(r.LoadShedding_MWh; digits=2)) | $(fmt_float(r.WindCurtailment_MWh; digits=2)) |")
        end
        println(io)
        println(io, "## Generated Per-Experiment Files")
        println(io)
        for f ∈ generated_files
            println(io, "- `$f`")
        end
    end

    println("Generated cross-archive summary:")
    println(cross_csv)
    println(cross_md)
    println("Generated per-experiment summaries:")
    for f ∈ generated_files
        println(f)
    end
end

main()
