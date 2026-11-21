"""
统一 PCM 批量运行配置。

所有开关均可由同名环境变量覆盖；这样入口文件本身保持稳定，Windows、Linux
和 macOS 均可用同一条 `julia --project=pkg tools/pcm/run_pcm_suite.jl` 命令。
"""
module PCMSuiteConfig

using Dates

const PROJECT_ROOT = dirname(dirname(dirname(@__DIR__)))

env_bool(name, default=false) = lowercase(strip(get(ENV, name, string(default)))) in ("1", "true", "yes", "on")
env_list(name, default) = filter(!isempty, strip.(split(get(ENV, name, default), ',')))

function load_config()
    intervals = parse(Int, get(ENV, "PCM_INTERVALS", "3"))
    window_hours = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
    stamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    profile_names = env_list("PCM_BENCHMARK_PROFILES", "baseline,smooth,extreme_ramp")
    return (;
        project_root = PROJECT_ROOT,
        julia_project = abspath(get(ENV, "PCM_JULIA_PROJECT", joinpath(PROJECT_ROOT, "pkg"))),
        input_file = abspath(get(ENV, "PCM_INPUT_XLSX", joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm.xlsx"))),
        output_root = abspath(get(ENV, "PCM_SUITE_OUTPUT", joinpath(PROJECT_ROOT, "output", "pcm_com4_loadall_h$(intervals * window_hours)_$stamp"))),
        profiles = profile_names,
        methods = env_list("PCM_BENCHMARK_METHODS", "standard,clustered_pcm,adaptive_overlap,clustered_adaptive_overlap"),
        runs = parse(Int, get(ENV, "PCM_BENCHMARK_RUNS", "1")),
        intervals,
        window_hours,
        network_constraints = get(ENV, "PCM_NETWORK_CONSTRAINTS", "0"),
        random_seed = get(ENV, "PCM_RANDOM_SEED", "20260809"),
        overlap_mode = get(ENV, "PCM_OVERLAP_MODE", "ml_prediction"),
        solver = get(ENV, "PCM_SOLVER", "gurobi"),
        export_results = env_bool("PCM_EXPORT_RESULT_CATALOG", true),
        resume = env_bool("PCM_BENCHMARK_RESUME", true),
    )
end

"""
打印影响建模与结果输出的 flag，便于日志审计。
"""
function print_config(c)
    println("\nPCM suite configuration")
    for key in propertynames(c)
        println("  ", key, " = ", getproperty(c, key))
    end
    println("  固定窗 PCM 求解策略 = 由 method 入口显式注入")
    println("  PCM_OVERLAP_MODE = ml_prediction（交叠窗方法强制使用 ML）")
end

end
