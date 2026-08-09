# 单个 PCM 基准实验进程：记录壁钟时间、Julia 分配量和进程峰值 RSS。
using Dates, CSV, DataFrames

const BENCHMARK_ROOT=normpath(joinpath(@__DIR__, "..", ".."))
const METHOD=lowercase(get(ENV, "PCM_METHOD", "standard"))
const PROFILE=lowercase(get(ENV, "PCM_LOAD_PROFILE", "baseline"))
const METRICS_PATH=get(ENV, "PCM_BENCHMARK_METRICS", joinpath(BENCHMARK_ROOT, "output", "pcm_benchmark_metrics.csv"))

status="OK"
failure=""
timed=nothing
try
    global timed=@timed include("main.jl")
catch err
    global status="FAILED"
    global failure=sprint(showerror, err)
end

row=DataFrame(; timestamp = [string(now())], method = [METHOD], load_profile = [PROFILE], status = [status],
    wall_time_sec = [timed === nothing ? missing : timed.time], allocated_mb = [timed === nothing ? missing : timed.bytes/1024^2],
    gc_time_sec = [timed === nothing ? missing : timed.gctime], peak_rss_mb = [Sys.maxrss()/1024^2], failure = [failure])
mkpath(dirname(METRICS_PATH))
CSV.write(METRICS_PATH, row; append = isfile(METRICS_PATH), writeheader = !isfile(METRICS_PATH))
status=="OK" || error(failure)
