"""Run the same PCM benchmark independently for the 108-unit and 1080-unit cases."""

include("benchmark_three_methods.jl")

module PCMTwoScaleBenchmark

using Dates
using CSV
using DataFrames
using Printf
using ..PCMThreeMethodBenchmark

export scale_label, case_output_root, report_filename, run_scale, refresh_report, main

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DEFAULT_CASES = [
    ("108_units", joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm.xlsx")),
    ("1080_units", joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm_10x.xlsx")),
]

function scale_label(input_file::AbstractString)
    occursin("_10x", basename(input_file)) ? "1080_units" : "108_units"
end

case_output_root(output_root::AbstractString, label::AbstractString) = joinpath(output_root, label)
report_filename(case_root::AbstractString) = joinpath(case_root, "analysis_report.md")

function _write_analysis_report(path::AbstractString, comparison_path::AbstractString; label, input_file, profiles, methods, runs, intervals, window_hours, network_constraints)
    comparison = CSV.read(joinpath(dirname(comparison_path), "comparison.csv"), DataFrame)
    standard_rows = comparison[(comparison.method .== "standard"), :]
    open(path, "w") do io
        println(io, "# PCM $(label) 规模算例分析报告\n")
        println(io, "- 规模标签：`$(label)`（数据文件中的物理机组规模）")
        println(io, "- 输入文件：`$(input_file)`")
        println(io, "- 网络母线：118；本报告中的 108/1080 指物理机组数量，不是母线数量。")
        println(io, "- 负荷模式：$(join(profiles, ", "))")
        println(io, "- PCM 方法：$(join(methods, ", "))")
        println(io, "- 重复次数：$(runs)；滚动范围：$(intervals) × $(window_hours) h；网络约束：$(network_constraints)\n")
        println(io, "> 下方内容由统一 benchmark 运行结果生成；原始计量、中间过程和日志保存在同一目录。\n")
        println(io, "## 核心结论\n")
        if nrow(standard_rows) == 1
            standard = standard_rows[1, :]
            println(io, @sprintf("- standard 基准：总成本 %.4e，耗时 %.2f s，峰值 RSS %.2f MB，物理机组 %d 台。",
                standard.median_total_cost, standard.median_wall_time_sec, standard.median_peak_rss_mb,
                round(Int, standard.physical_units)))
            for row in eachrow(comparison[comparison.method .!= "standard", :])
                println(io, @sprintf("- %s：总成本 %.4e（相对 standard %+.3f%%），耗时 %.2f s（相对 %+.2f%%），峰值 RSS %.2f MB（相对 %+.2f%%），整数变量缩减 %.2f%%。",
                    row.method, row.median_total_cost, row.cost_delta_pct, row.median_wall_time_sec,
                    row.wall_time_delta_pct, row.median_peak_rss_mb, row.peak_rss_delta_pct,
                    row.integer_reduction_pct))
                if row.method == "clustered_pcm"
                    pure_status = row.cluster_fallbacks == 0 ? "本次聚类区间全部通过后验校核" :
                        @sprintf("发生 %.0f 次回退，不能按纯聚类结果解读", row.cluster_fallbacks)
                    println(io, "  - 聚类过程：$(pure_status)；等效机组 $(round(Int, row.equivalent_units)) 台，状态缩减 $(round(row.state_reduction_pct; digits=2))%。")
                end
            end
        end
        println(io, "\n## 结果解读\n")
        println(io, "本次 108/1080 规模指物理机组数量；两套输入的网络母线均为 118。成本、耗时和内存均来自独立 Julia 进程，聚类回退次数与中间校核结果保留在 `cluster_intermediate.csv` 和对应 `run.log` 中。")
        println(io, "")
        print(io, read(comparison_path, String))
    end
end

function refresh_report(; case_root, label, input_file, profiles, methods, runs, intervals, window_hours, network_constraints)
    comparison_path = joinpath(case_root, "comparison.md")
    isfile(comparison_path) || error("Generated comparison report not found: $comparison_path")
    _write_analysis_report(report_filename(case_root), comparison_path; label, input_file = abspath(input_file),
        profiles, methods, runs, intervals, window_hours, network_constraints)
    report_filename(case_root)
end

function _write_combined_report(path::AbstractString, output_root::AbstractString; profiles, methods, runs, intervals,
        window_hours, network_constraints, solver)
    open(path, "w") do io
        println(io, "# 三套 PCM 方法双规模综合分析报告\n")
        println(io, "- 算例规模：108 / 1080 台物理机组；两套输入均为 118 母线。")
        println(io, "- 负荷模式：$(join(profiles, ", "))")
        println(io, "- PCM 方法：$(join(methods, ", "))")
        println(io, "- 求解器：`$(solver)`；重复次数：$(runs)；滚动区间：$(intervals) × $(window_hours) h；网络约束：$(network_constraints)")
        println(io, "- 自适应交叠窗：统一使用 `ml_prediction`；训练模式：`PCM_TRAINING_MODE=fast_max_overlap`。\n")
        println(io, "> 本报告由 `tools/pcm/benchmark_two_scales.jl` 生成。每个规模的完整计量、中间过程和日志分别保存在 `108_units/` 与 `1080_units/`。\n")
        println(io, "## 综合结果\n")
        println(io, "| 规模 | 负荷模式 | 方法 | 成本 | 耗时(s) | 峰值RSS(MB) | 成本变化 | 时间变化 | 平均交叠(h) | 聚类回退 | 整数变量缩减 | 成功率 |")
        println(io, "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for label in ("108_units", "1080_units")
            comparison_path = joinpath(output_root, label, "comparison.csv")
            isfile(comparison_path) || continue
            comparison = CSV.read(comparison_path, DataFrame)
            for row in eachrow(comparison)
                println(io, @sprintf("| %s | %s | %s | %.4e | %.2f | %.2f | %+.3f%% | %+.2f%% | %.1f | %.0f | %.2f%% | %.1f%% |",
                    label, row.profile, row.method, row.median_total_cost, row.median_wall_time_sec,
                    row.median_peak_rss_mb, row.cost_delta_pct, row.wall_time_delta_pct,
                    row.mean_overlap_hours, row.cluster_fallbacks, row.integer_reduction_pct, row.success_rate_pct))
            end
        end
        println(io, "\n## 关键判断\n")
        println(io, "1. 成本统计采用各方法最终提交的执行区间；adaptive 的交叠预测区间只用于扩展优化视野，不会把交叠小时再次计入总调度成本。")
        println(io, "2. `fast_max_overlap` 为大规模训练加速模式：每个 case/profile 使用 4 个当前 case 扰动样本，标签取该区间允许的最大交叠。它保留了 ML 缓存命中链路，但不等同于完整 0–12 h 成本扫描；若需要严格标定，应切回 `PCM_TRAINING_MODE=sweep` 单独训练。")
        println(io, "3. clustered PCM 的主问题只保留聚类机组开停、停机和数量一致性约束，单机解群可行性在主问题完成后校核；因此回退次数是聚类精度的重要判据。")
        println(io, "4. 每个规模目录中的 `adaptive_intermediate.csv` 保留稳态判据、驻留约束、爬坡事件、最终交叠长度和实际求解时域；`cluster_intermediate.csv` 保留聚类与解群校核过程。")
        println(io, "\n## 输出结构\n")
        println(io, "- `108_units/analysis_report.md`、`1080_units/analysis_report.md`：分规模报告。")
        println(io, "- 各规模目录的 `metrics.csv`、`summary.csv`、`comparison.csv`：原始计量、聚合指标和相对 standard 对比。")
        println(io, "- `output/pcm_training_cache/overlap_training_cache/`：按 case 内容哈希、规模、负荷模式和训练配置隔离的可复用训练数据。")
    end
    path
end

function run_scale(; output_root, label, input_file, julia_project, profiles, methods, runs, intervals,
        window_hours, network_constraints, random_seed, overlap_mode, solver)
    isfile(input_file) || error("PCM input file not found: $input_file")
    case_root = case_output_root(output_root, label)
    mkpath(case_root)
    PCMThreeMethodBenchmark.main(; project_root = PROJECT_ROOT, julia_project, input_file = abspath(input_file),
        output_root = case_root, profiles, methods, runs, intervals, window_hours, network_constraints,
        random_seed, overlap_mode, solver)
    comparison_path = joinpath(case_root, "comparison.md")
    isfile(comparison_path) || error("Generated comparison report not found: $comparison_path")
    refresh_report(; case_root, label, input_file, profiles, methods, runs, intervals, window_hours, network_constraints)
    println("Analysis report: $(report_filename(case_root))")
    case_root
end

function main(; project_root = PROJECT_ROOT,
        output_root = abspath(get(ENV, "PCM_TWO_SCALE_OUTPUT", joinpath(project_root, "output", "pcm_benchmark", "two_scale_$(Dates.format(now(), "yyyymmdd_HHMMSS"))"))),
        julia_project = get(ENV, "PCM_JULIA_PROJECT", joinpath(project_root, "pkg")),
        profiles = PCMThreeMethodBenchmark.parse_list(get(ENV, "PCM_BENCHMARK_PROFILES", "baseline,smooth,extreme_ramp")),
        methods = PCMThreeMethodBenchmark.parse_list(get(ENV, "PCM_BENCHMARK_METHODS", "standard,clustered_pcm,adaptive_overlap")),
        runs = parse(Int, get(ENV, "PCM_BENCHMARK_RUNS", "1")),
        intervals = parse(Int, get(ENV, "PCM_INTERVALS", "1")),
        window_hours = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24")),
        network_constraints = get(ENV, "PCM_NETWORK_CONSTRAINTS", "0"),
        random_seed = get(ENV, "PCM_RANDOM_SEED", "20260809"),
        overlap_mode = get(ENV, "PCM_OVERLAP_MODE", "ml_prediction"),
        solver = PCMThreeMethodBenchmark.normalize_solver(get(ENV, "PCM_SOLVER", "gurobi")))
    isempty(profiles) && error("PCM_BENCHMARK_PROFILES is empty")
    isempty(methods) && error("PCM_BENCHMARK_METHODS is empty")
    mkpath(output_root)
    println("Two-scale PCM benchmark output root: $output_root")
    for (label, input_file) in DEFAULT_CASES
        println("\n===== $(label): $(input_file) =====")
        run_scale(; output_root, label, input_file, julia_project, profiles, methods, runs, intervals,
            window_hours, network_constraints, random_seed, overlap_mode, solver)
    end
    combined_report = joinpath(output_root, "analysis_report.md")
    _write_combined_report(combined_report, output_root; profiles, methods, runs, intervals,
        window_hours, network_constraints, solver)
    println("Combined analysis report: $combined_report")
    output_root
end

end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    PCMTwoScaleBenchmark.main()
end
