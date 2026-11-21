#!/usr/bin/env julia
"""
    tools/pcm/example_run.jl

Production Cost Modeling (PCM) 统一示例入口：支持手动挑选 4 类正交 PCM 方法中的任意一种，
或与全时段一体 UC Benchmark 进行对照对比。

2×2 正交方法矩阵 + Benchmark 对照：
  [1] standard          : 不聚类（单机） + 不含交叠（固定滚动窗口）
  [2] adaptive_overlap  : 不聚类（单机） + 含交叠（自适应交叠窗）
  [3] clustered         : 聚类（簇+解聚）+ 不含交叠（固定滚动窗口）
  [4] clustered_overlap : 聚类（簇+解聚）+ 含交叠（自适应交叠窗）
  [5] benchmark         : 全时段一体 UC 对照基准（Full-Horizon Integrated UC）
  [6] compare_all       : 一键运行全部 4 类 PCM vs Benchmark 对比

使用方式：
  1) 直接修改下方「用户手动选择区」常量并运行本文件；
  2) 命令行直接传入方法名或编号：
       julia --project=. tools/pcm/example_run.jl standard
       julia --project=. tools/pcm/example_run.jl clustered
       julia --project=. tools/pcm/example_run.jl 3 --intervals=2 --window=24
  3) 终端交互式菜单手动挑选：
       julia --project=. tools/pcm/example_run.jl -i
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..")))

using ModuleUnitCommitmentToolkit

# =========================================================================
# 用户手动选择区（改这里即可直接运行；命令行参数优先级更高）
# 可选值: :standard | :adaptive_overlap | :clustered | :clustered_overlap
#         :benchmark | :compare_fixed | :compare_all | :interactive
# =========================================================================
const SELECTED_METHOD       = :standard
const SELECTED_INTERVALS    = 2            # 滚动窗口段数
const SELECTED_WINDOW_HOURS = 24           # 单窗口时长 (h)
const SELECTED_LOAD_PROFILE = "baseline"   # "baseline" | "smooth" | "extreme_ramp"
const SELECTED_PERF_MODE    = "fast"       # "fast" | "balanced"

const _MENU_CHOICES = Dict{String, Symbol}(
    "1" => :standard,
    "2" => :adaptive_overlap,
    "3" => :clustered,
    "4" => :clustered_overlap,
    "5" => :benchmark,
    "6" => :compare_all,
    "7" => :compare_fixed,
)

function _prompt_pcm_method()
    println("\n" * "="^72)
    println("请选择要运行的 PCM 方法（2×2 正交矩阵 + Benchmark）：")
    println("="^72)
    println("  [1] standard          — 不聚类（单机） + 不含交叠（固定窗）")
    println("  [2] adaptive_overlap  — 不聚类（单机） + 含交叠（自适应交叠窗）")
    println("  [3] clustered         — 聚类（簇+解聚）+ 不含交叠（固定窗）")
    println("  [4] clustered_overlap — 聚类（簇+解聚）+ 含交叠（自适应交叠窗）")
    println("  [5] benchmark         — 全时段一体 UC 对照基准")
    println("  [6] compare_all       — 全部 4 类 PCM vs Benchmark 完整对比")
    println("  [7] compare_fixed     — 固定窗 2 类 PCM (standard + clustered) vs Benchmark")
    println("-"^72)
    print("请输入编号 [1-7] 或方法名（直接回车默认 $(SELECTED_METHOD)）: ")
    flush(stdout)
    line = strip(readline())
    isempty(line) && return SELECTED_METHOD
    return get(_MENU_CHOICES, line, Symbol(lowercase(line)))
end

function main(args = ARGS;
    method::Symbol = SELECTED_METHOD,
    intervals::Int = SELECTED_INTERVALS,
    window_hours::Int = SELECTED_WINDOW_HOURS,
    load_profile::String = SELECTED_LOAD_PROFILE,
    performance_mode::String = SELECTED_PERF_MODE,
)
    chosen = method
    interactive = (chosen === :interactive)

    for arg in args
        if arg in ("-h", "--help")
            println(
                """
                Usage:
                  julia --project=. tools/pcm/example_run.jl [METHOD|1-7] [OPTIONS]

                Methods (2x2 PCM Matrix + Benchmark):
                  1 | standard               Single-Unit + Fixed Horizon (no cluster, no overlap)
                  2 | adaptive_overlap       Single-Unit + Adaptive Overlap
                  3 | clustered              Clustered   + Fixed Horizon
                  4 | clustered_overlap      Clustered   + Adaptive Overlap
                  5 | benchmark              Full-Horizon Integrated UC Reference
                  6 | --compare-all          Run all 4 PCM methods vs Full-Horizon Benchmark
                  7 | --compare-fixed        Run Fixed-Horizon (standard + clustered) vs Benchmark

                Options:
                  -i, --interactive          Interactive menu to pick a PCM method
                  --intervals=N              Number of rolling intervals (default: $(SELECTED_INTERVALS))
                  --window=H                 Window hours per interval (default: $(SELECTED_WINDOW_HOURS))
                  --profile=NAME             Load profile: baseline, smooth, extreme_ramp
                  --performance=MODE         fast or balanced
                """,
            )
            return nothing
        elseif arg in ("-i", "--interactive")
            interactive = true
        elseif arg == "--compare-all"
            chosen = :compare_all
        elseif arg == "--compare-fixed"
            chosen = :compare_fixed
        elseif startswith(arg, "--method=")
            val = strip(split(arg, "="; limit = 2)[2])
            chosen = get(_MENU_CHOICES, val, Symbol(lowercase(val)))
        elseif startswith(arg, "--intervals=")
            intervals = parse(Int, split(arg, "="; limit = 2)[2])
        elseif startswith(arg, "--window=")
            window_hours = parse(Int, split(arg, "="; limit = 2)[2])
        elseif startswith(arg, "--profile=")
            load_profile = split(arg, "="; limit = 2)[2]
        elseif startswith(arg, "--performance=")
            performance_mode = split(arg, "="; limit = 2)[2]
        elseif !startswith(arg, "-")
            chosen = get(_MENU_CHOICES, arg, Symbol(lowercase(arg)))
        else
            throw(ArgumentError("Unknown option: $arg"))
        end
    end

    if interactive
        chosen = _prompt_pcm_method()
    end

    cfg = PCMConfig(
        window_hours = window_hours,
        intervals = intervals,
        load_profile = load_profile,
        performance_mode = performance_mode,
    )

    out_dir = joinpath(normpath(joinpath(@__DIR__, "..", "..")), "output", "pcm_comparison")
    if chosen === :compare_all
        return compare_pcm_methods(; methods = PCM_MATRIX_METHODS, include_benchmark = true, cfg = cfg, output_dir = out_dir)
    elseif chosen === :compare_fixed
        return compare_pcm_methods(; methods = (:standard, :clustered), include_benchmark = true, cfg = cfg, output_dir = out_dir)
    else
        res = run_pcm(chosen; cfg = cfg)
        println("\n" * "="^72)
        println("PCM Run Summary :: $(res.method)")
        println("  Formulation : $(res.formulation) | Overlap : $(res.overlap)")
        println("  Horizon     : $(res.intervals) x $(res.window_hours)h = $(res.total_hours)h (profile=$(cfg.load_profile))")
        println("  Status      : $(res.status)")
        println("  Total Cost  : $(round(res.total_cost; digits=4))")
        println("  Runtime     : $(round(res.runtime_seconds; digits=3)) s")
        println("="^72)
        return res
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
