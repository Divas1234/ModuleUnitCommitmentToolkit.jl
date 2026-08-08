using CSV
using DataFrames
using Dates
using Printf
using Statistics
using XLSX

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))

const MODE_ORDER = [
    "NoOverlap",
    "SteadyOnly",
    "UnitOnly",
    "RampOnly",
    "Steady+Unit",
    "Steady+Ramp",
    "Unit+Ramp",
    "Steady+Unit+Ramp",
]

function arg_value(flag::String, default::Union{Nothing, String} = nothing)
    idx = findfirst(==(flag), ARGS)
    if idx === nothing || idx == length(ARGS)
        return default
    end
    return ARGS[idx + 1]
end

function scenario_dirs(batch_dir::String)
    dirs = String[]
    for entry in readdir(batch_dir; join = true)
        if isdir(entry) && isfile(joinpath(entry, "criteria_combination_performance.csv"))
            push!(dirs, entry)
        end
    end
    return sort(dirs)
end

function read_load_curve_xlsx(path::String)
    xf = XLSX.readxlsx(path)
    sh = xf["load_curve"]
    rows = size(sh[:], 1)
    hours = Float64[]
    loads = Float64[]
    for r in 2:rows
        h = sh[r, 1]
        v = sh[r, 2]
        if !ismissing(v)
            push!(hours, ismissing(h) ? length(hours) + 1 : Float64(h))
            push!(loads, Float64(v))
        end
    end
    return DataFrame(Hour = hours, Load = loads)
end

function fmt(x; digits::Int = 2)
    if x isa Missing || x === nothing
        return ""
    end
    if x isa Integer
        return string(x)
    end
    return @sprintf("%.*f", digits, Float64(x))
end

function safe_col(df::DataFrame, name::Symbol, default)
    return name in propertynames(df) ? df[!, name] : fill(default, nrow(df))
end

function ordered!(df::DataFrame)
    order = Dict(mode => i for (i, mode) in enumerate(MODE_ORDER))
    sort!(df, [:Mode], by = mode -> get(order, string(mode), length(MODE_ORDER) + 1))
    return df
end

function svg_escape(s)
    return replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

function nice_range(values)
    vals = collect(skipmissing(Float64.(values)))
    if isempty(vals)
        return 0.0, 1.0
    end
    lo, hi = minimum(vals), maximum(vals)
    if lo == hi
        pad = max(abs(lo) * 0.1, 1.0)
        return lo - pad, hi + pad
    end
    pad = 0.08 * (hi - lo)
    return lo - pad, hi + pad
end

function write_bar_svg(path::String, title::String, labels::Vector{String}, values::Vector{Float64}, ylabel::String; color = "#2f6f73")
    width, height = 1120, 620
    left, right, top, bottom = 92, 36, 58, 145
    plot_w = width - left - right
    plot_h = height - top - bottom
    lo, hi = nice_range(values)
    lo = min(lo, 0.0)
    scale_y(v) = top + (hi - v) / (hi - lo) * plot_h
    zero_y = scale_y(0.0)
    bar_gap = 12
    bar_w = max(18, (plot_w - bar_gap * (length(labels) + 1)) / length(labels))

    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(io, """<text x="$(width/2)" y="30" text-anchor="middle" font-family="Arial" font-size="22" font-weight="700">$(svg_escape(title))</text>""")
        println(io, """<text x="22" y="$(top + plot_h/2)" transform="rotate(-90 22 $(top + plot_h/2))" text-anchor="middle" font-family="Arial" font-size="14">$(svg_escape(ylabel))</text>""")
        println(io, """<line x1="$left" y1="$zero_y" x2="$(width-right)" y2="$zero_y" stroke="#455a64" stroke-width="1"/>""")
        for i in 0:5
            yv = lo + (hi - lo) * i / 5
            y = scale_y(yv)
            println(io, """<line x1="$left" y1="$y" x2="$(width-right)" y2="$y" stroke="#d8dee3" stroke-width="1"/>""")
            println(io, """<text x="$(left-10)" y="$(y+4)" text-anchor="end" font-family="Arial" font-size="12" fill="#37474f">$(fmt(yv; digits=2))</text>""")
        end
        for (i, (label, value)) in enumerate(zip(labels, values))
            x = left + bar_gap + (i - 1) * (bar_w + bar_gap)
            y = min(scale_y(value), zero_y)
            h = max(abs(zero_y - scale_y(value)), 1.0)
            println(io, """<rect x="$x" y="$y" width="$bar_w" height="$h" rx="3" fill="$color"/>""")
            println(io, """<text x="$(x + bar_w/2)" y="$(y - 6)" text-anchor="middle" font-family="Arial" font-size="12" fill="#263238">$(fmt(value; digits=2))</text>""")
            println(io, """<text x="$(x + bar_w/2)" y="$(height-84)" text-anchor="end" transform="rotate(-35 $(x + bar_w/2) $(height-84))" font-family="Arial" font-size="12" fill="#263238">$(svg_escape(label))</text>""")
        end
        println(io, "</svg>")
    end
end

function write_grouped_bar_svg(path::String, title::String, labels::Vector{String}, normal::Vector{Float64}, extreme::Vector{Float64}, ylabel::String)
    width, height = 1160, 660
    left, right, top, bottom = 92, 50, 64, 150
    plot_w = width - left - right
    plot_h = height - top - bottom
    lo, hi = nice_range(vcat(normal, extreme))
    lo = min(lo, 0.0)
    scale_y(v) = top + (hi - v) / (hi - lo) * plot_h
    zero_y = scale_y(0.0)
    group_gap = 18
    group_w = (plot_w - group_gap * (length(labels) + 1)) / length(labels)
    bar_w = max(12, (group_w - 8) / 2)
    colors = ("#2f6f73", "#c45a3d")

    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(io, """<text x="$(width/2)" y="32" text-anchor="middle" font-family="Arial" font-size="22" font-weight="700">$(svg_escape(title))</text>""")
        println(io, """<text x="22" y="$(top + plot_h/2)" transform="rotate(-90 22 $(top + plot_h/2))" text-anchor="middle" font-family="Arial" font-size="14">$(svg_escape(ylabel))</text>""")
        println(io, """<rect x="$(width-265)" y="48" width="14" height="14" fill="$(colors[1])"/><text x="$(width-244)" y="60" font-family="Arial" font-size="13">普通 118</text>""")
        println(io, """<rect x="$(width-160)" y="48" width="14" height="14" fill="$(colors[2])"/><text x="$(width-139)" y="60" font-family="Arial" font-size="13">极端爬坡</text>""")
        for i in 0:5
            yv = lo + (hi - lo) * i / 5
            y = scale_y(yv)
            println(io, """<line x1="$left" y1="$y" x2="$(width-right)" y2="$y" stroke="#d8dee3" stroke-width="1"/>""")
            println(io, """<text x="$(left-10)" y="$(y+4)" text-anchor="end" font-family="Arial" font-size="12" fill="#37474f">$(fmt(yv; digits=2))</text>""")
        end
        println(io, """<line x1="$left" y1="$zero_y" x2="$(width-right)" y2="$zero_y" stroke="#455a64" stroke-width="1"/>""")
        for (i, label) in enumerate(labels)
            gx = left + group_gap + (i - 1) * (group_w + group_gap)
            for (j, value) in enumerate((normal[i], extreme[i]))
                x = gx + (j - 1) * (bar_w + 8)
                y = min(scale_y(value), zero_y)
                h = max(abs(zero_y - scale_y(value)), 1.0)
                println(io, """<rect x="$x" y="$y" width="$bar_w" height="$h" rx="3" fill="$(colors[j])"/>""")
            end
            println(io, """<text x="$(gx + group_w/2)" y="$(height-88)" text-anchor="end" transform="rotate(-35 $(gx + group_w/2) $(height-88))" font-family="Arial" font-size="12" fill="#263238">$(svg_escape(label))</text>""")
        end
        println(io, "</svg>")
    end
end

function write_line_svg(path::String, title::String, x::Vector{Float64}, series::Vector{Tuple{String, Vector{Float64}, String}}, ylabel::String)
    width, height = 1160, 560
    left, right, top, bottom = 82, 42, 58, 70
    plot_w = width - left - right
    plot_h = height - top - bottom
    all_y = reduce(vcat, [s[2] for s in series])
    ylo, yhi = nice_range(all_y)
    xlo, xhi = minimum(x), maximum(x)
    sx(v) = left + (v - xlo) / max(xhi - xlo, 1.0) * plot_w
    sy(v) = top + (yhi - v) / (yhi - ylo) * plot_h

    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(io, """<text x="$(width/2)" y="30" text-anchor="middle" font-family="Arial" font-size="22" font-weight="700">$(svg_escape(title))</text>""")
        println(io, """<text x="22" y="$(top + plot_h/2)" transform="rotate(-90 22 $(top + plot_h/2))" text-anchor="middle" font-family="Arial" font-size="14">$(svg_escape(ylabel))</text>""")
        for i in 0:5
            yv = ylo + (yhi - ylo) * i / 5
            y = sy(yv)
            println(io, """<line x1="$left" y1="$y" x2="$(width-right)" y2="$y" stroke="#d8dee3" stroke-width="1"/>""")
            println(io, """<text x="$(left-10)" y="$(y+4)" text-anchor="end" font-family="Arial" font-size="12" fill="#37474f">$(fmt(yv; digits=2))</text>""")
        end
        println(io, """<line x1="$left" y1="$(top+plot_h)" x2="$(width-right)" y2="$(top+plot_h)" stroke="#455a64"/>""")
        for (idx, (name, yvals, color)) in enumerate(series)
            points = join(["$(sx(x[i])),$(sy(yvals[i]))" for i in eachindex(x)], " ")
            println(io, """<polyline points="$points" fill="none" stroke="$color" stroke-width="2.5"/>""")
            for i in eachindex(x)
                println(io, """<circle cx="$(sx(x[i]))" cy="$(sy(yvals[i]))" r="3" fill="$color"/>""")
            end
            lx = width - 270 + 120 * ((idx - 1) % 2)
            ly = 50 + 18 * div(idx - 1, 2)
            println(io, """<line x1="$lx" y1="$ly" x2="$(lx+18)" y2="$ly" stroke="$color" stroke-width="3"/><text x="$(lx+24)" y="$(ly+4)" font-family="Arial" font-size="12">$(svg_escape(name))</text>""")
        end
        for xv in x
            println(io, """<text x="$(sx(xv))" y="$(height-34)" text-anchor="middle" font-family="Arial" font-size="12" fill="#263238">$(Int(xv))</text>""")
        end
        println(io, """<text x="$(left + plot_w/2)" y="$(height-10)" text-anchor="middle" font-family="Arial" font-size="13">Hour / Interval</text>""")
        println(io, "</svg>")
    end
end

function summarize_scenario(dir::String)
    scenario = basename(dir)
    perf = ordered!(CSV.read(joinpath(dir, "criteria_combination_performance.csv"), DataFrame))
    intervals = CSV.read(joinpath(dir, "criteria_combination_intervals.csv"), DataFrame)

    load_xlsx = joinpath(dir, "input_data_118.xlsx")
    if isfile(load_xlsx)
        load_df = read_load_curve_xlsx(load_xlsx)
        CSV.write(joinpath(dir, "load_curve_168h.csv"), load_df)
        load_summary = DataFrame(
            Metric = ["hours", "min_load", "max_load", "mean_load", "std_load", "max_abs_hourly_ramp"],
            Value = [
                nrow(load_df),
                minimum(load_df.Load),
                maximum(load_df.Load),
                mean(load_df.Load),
                std(load_df.Load),
                maximum(abs.(diff(load_df.Load))),
            ],
        )
        CSV.write(joinpath(dir, "load_curve_summary.csv"), load_summary)
        write_line_svg(joinpath(dir, "load_curve.svg"), "$scenario load curve", load_df.Hour, [("Load", load_df.Load, "#2f6f73")], "Load")
    end

    CSV.write(joinpath(dir, "criteria_performance_detailed.csv"), perf)
    CSV.write(joinpath(dir, "criteria_intervals_detailed.csv"), intervals)

    labels = String.(perf.Mode)
    write_bar_svg(joinpath(dir, "cost_gap_by_mode.svg"), "$scenario cost gap vs all criteria", labels, Float64.(perf.CostGap_vs_All_pct), "Cost gap (%)"; color = "#466a9f")
    write_bar_svg(joinpath(dir, "solve_time_by_mode.svg"), "$scenario subproblem solve time", labels, Float64.(perf.SubproblemSolveTime_sec), "Solve time (s)"; color = "#2f6f73")
    write_bar_svg(joinpath(dir, "memory_by_mode.svg"), "$scenario allocated memory", labels, Float64.(perf.JuliaAllocated_MB), "Allocated memory (MB)"; color = "#9f6b30")
    write_bar_svg(joinpath(dir, "avg_overlap_by_mode.svg"), "$scenario average overlap window", labels, Float64.(perf.AvgOverlap_h), "Avg overlap (h)"; color = "#7a5aa6")

    colors = ["#263238", "#2f6f73", "#466a9f", "#c45a3d", "#7a5aa6", "#9f6b30", "#4b8063", "#8c4f7d"]
    selected_modes = filter(m -> m in unique(intervals.Mode), MODE_ORDER)
    series = Tuple{String, Vector{Float64}, String}[]
    x = sort(unique(Float64.(intervals.Interval_ID)))
    for (i, mode) in enumerate(selected_modes)
        sub = sort(intervals[intervals.Mode .== mode, :], :Interval_ID)
        push!(series, (mode, Float64.(sub.Final_Overlap_h), colors[mod1(i, length(colors))]))
    end
    write_line_svg(joinpath(dir, "interval_overlap_by_mode.svg"), "$scenario interval overlap by mode", x, series, "Overlap (h)")

    open(joinpath(dir, "detailed_scenario_report.md"), "w") do io
        println(io, "# Criteria Combination Detailed Report")
        println(io)
        println(io, "- Scenario: `$scenario`")
        println(io, "- Generated: `$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))`")
        println(io, "- Training/calibration time is reported separately and excluded from operational simulation solve time.")
        println(io)
        println(io, "## Performance Table")
        println(io)
        println(io, "| Mode | Cost USD | Gap vs All % | Solve s | Memory MB | Avg overlap h | Load shedding | Wind curtailment |")
        println(io, "|---|---:|---:|---:|---:|---:|---:|---:|")
        for r in eachrow(perf)
            println(io, "| $(r.Mode) | $(fmt(r.TotalCost_USD; digits=2)) | $(fmt(r.CostGap_vs_All_pct; digits=4)) | $(fmt(r.SubproblemSolveTime_sec; digits=2)) | $(fmt(r.JuliaAllocated_MB; digits=2)) | $(fmt(r.AvgOverlap_h; digits=2)) | $(fmt(r.LoadShedding_MWh; digits=2)) | $(fmt(r.WindCurtailment_MWh; digits=2)) |")
        end
        println(io)
        println(io, "## Charts")
        println(io)
        for chart in ["load_curve.svg", "cost_gap_by_mode.svg", "solve_time_by_mode.svg", "memory_by_mode.svg", "avg_overlap_by_mode.svg", "interval_overlap_by_mode.svg"]
            if isfile(joinpath(dir, chart))
                println(io, "![$chart]($chart)")
                println(io)
            end
        end
    end

    perf.Scenario = fill(scenario, nrow(perf))
    return perf
end

function write_cross_report(batch_dir::String, scenario_frames::Vector{DataFrame})
    combined = vcat(scenario_frames...; cols = :union)
    select!(combined, Cols(:Scenario, :Mode, Not([:Scenario, :Mode])))
    CSV.write(joinpath(batch_dir, "criteria_comparison_all_scenarios.csv"), combined)

    scenarios = unique(String.(combined.Scenario))
    normal_candidates = filter(s -> contains(lowercase(s), "normal"), scenarios)
    extreme_candidates = filter(s -> contains(lowercase(s), "extreme"), scenarios)
    normal_name = isempty(normal_candidates) ? "" : first(normal_candidates)
    extreme_name = isempty(extreme_candidates) ? "" : first(extreme_candidates)

    if normal_name != "" && extreme_name != ""
        normal = ordered!(combined[combined.Scenario .== normal_name, :])
        extreme = ordered!(combined[combined.Scenario .== extreme_name, :])
        labels = String.(normal.Mode)
        write_grouped_bar_svg(joinpath(batch_dir, "cost_gap_compare.svg"), "Cost gap comparison", labels, Float64.(normal.CostGap_vs_All_pct), Float64.(extreme.CostGap_vs_All_pct), "Cost gap (%)")
        write_grouped_bar_svg(joinpath(batch_dir, "solve_time_compare.svg"), "Solve time comparison", labels, Float64.(normal.SubproblemSolveTime_sec), Float64.(extreme.SubproblemSolveTime_sec), "Solve time (s)")
        write_grouped_bar_svg(joinpath(batch_dir, "memory_compare.svg"), "Memory comparison", labels, Float64.(normal.JuliaAllocated_MB), Float64.(extreme.JuliaAllocated_MB), "Allocated memory (MB)")
        write_grouped_bar_svg(joinpath(batch_dir, "avg_overlap_compare.svg"), "Average overlap comparison", labels, Float64.(normal.AvgOverlap_h), Float64.(extreme.AvgOverlap_h), "Avg overlap (h)")

        delta = DataFrame(
            Mode = labels,
            CostGapDelta_pctpoint = Float64.(extreme.CostGap_vs_All_pct) .- Float64.(normal.CostGap_vs_All_pct),
            SolveTimeDelta_sec = Float64.(extreme.SubproblemSolveTime_sec) .- Float64.(normal.SubproblemSolveTime_sec),
            MemoryDelta_MB = Float64.(extreme.JuliaAllocated_MB) .- Float64.(normal.JuliaAllocated_MB),
            AvgOverlapDelta_h = Float64.(extreme.AvgOverlap_h) .- Float64.(normal.AvgOverlap_h),
            LoadSheddingDelta_MWh = Float64.(extreme.LoadShedding_MWh) .- Float64.(normal.LoadShedding_MWh),
            WindCurtailmentDelta_MWh = Float64.(extreme.WindCurtailment_MWh) .- Float64.(normal.WindCurtailment_MWh),
        )
        CSV.write(joinpath(batch_dir, "extreme_vs_normal_delta.csv"), delta)
    end

    open(joinpath(batch_dir, "detailed_comparison_report.md"), "w") do io
        println(io, "# Ordinary IEEE-118 vs Extreme-Ramp Overlap Criteria Comparison")
        println(io)
        println(io, "- Archive batch: `$batch_dir`")
        println(io, "- Generated: `$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))`")
        println(io, "- Operational solve time uses `SubproblemSolveTime_sec`; offline training/calibration and local reference solves are retained as excluded fields.")
        println(io)
        println(io, "## Consolidated Performance")
        println(io)
        println(io, "| Scenario | Mode | Cost USD | Gap vs All % | Solve s | Memory MB | Avg overlap h | Load shedding | Wind curtailment |")
        println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|")
        for r in eachrow(combined)
            println(io, "| $(r.Scenario) | $(r.Mode) | $(fmt(r.TotalCost_USD; digits=2)) | $(fmt(r.CostGap_vs_All_pct; digits=4)) | $(fmt(r.SubproblemSolveTime_sec; digits=2)) | $(fmt(r.JuliaAllocated_MB; digits=2)) | $(fmt(r.AvgOverlap_h; digits=2)) | $(fmt(r.LoadShedding_MWh; digits=2)) | $(fmt(r.WindCurtailment_MWh; digits=2)) |")
        end
        println(io)
        println(io, "## Cross-Scenario Charts")
        println(io)
        for chart in ["cost_gap_compare.svg", "solve_time_compare.svg", "memory_compare.svg", "avg_overlap_compare.svg"]
            if isfile(joinpath(batch_dir, chart))
                println(io, "![$chart]($chart)")
                println(io)
            end
        end
        println(io, "## Detailed Files")
        println(io)
        println(io, "- `criteria_comparison_all_scenarios.csv`")
        if isfile(joinpath(batch_dir, "extreme_vs_normal_delta.csv"))
            println(io, "- `extreme_vs_normal_delta.csv`")
        end
    end
end

function main()
    batch_dir = arg_value("--batch-dir")
    if batch_dir === nothing
        error("Usage: julia archive_pcm_comparison.jl --batch-dir <archive batch dir>")
    end
    dirs = scenario_dirs(batch_dir)
    isempty(dirs) && error("No scenario directories with criteria_combination_performance.csv found in $batch_dir")

    frames = DataFrame[]
    for dir in dirs
        println("Summarizing scenario archive: $dir")
        push!(frames, summarize_scenario(dir))
    end
    write_cross_report(batch_dir, frames)
    println("Generated detailed archive comparison in: $batch_dir")
end

main()
