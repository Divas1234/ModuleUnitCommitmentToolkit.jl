# 单个 PCM 基准实验进程：记录壁钟时间、Julia 分配量和进程峰值 RSS。
using Dates, CSV, DataFrames

const BENCHMARK_ROOT=dirname(dirname(dirname(@__DIR__)))
const METHOD=lowercase(get(ENV, "PCM_METHOD", "standard"))
const PROFILE=lowercase(get(ENV, "PCM_LOAD_PROFILE", "baseline"))
const METRICS_PATH=get(ENV, "PCM_BENCHMARK_METRICS", joinpath(BENCHMARK_ROOT, "output", "pcm_benchmark_metrics.csv"))
const INPUT_FILE=get(ENV, "PCM_INPUT_XLSX", get(ENV, "MODULE_UC_DATA_FILE", ""))
const WINDOW_HOURS=parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
const INTERVALS=parse(Int, get(ENV, "PCM_INTERVALS", "7"))

status="OK"
failure=""
timed=nothing
try
    global timed=@timed include(joinpath(@__DIR__, "..", "main.jl"))
catch err
    global status="FAILED"
    global failure=sprint(showerror, err)
end

physical_units=isdefined(@__MODULE__, :NG) ? NG : missing
virtual_units=isdefined(@__MODULE__, :units) && isdefined(@__MODULE__, :build_similar_pcm_clusters) ? length(build_similar_pcm_clusters(units)) :
              missing
integer_variables=physical_units === missing || virtual_units === missing ? missing :
                  3 * WINDOW_HOURS *
                  (METHOD in ("clustered_pcm", "clustered", "cluster", "clustered_adaptive_overlap") ? virtual_units : physical_units)
total_cost=isdefined(@__MODULE__, :PCM_TOTAL_SCHEDULED_COST) ? sum(PCM_TOTAL_SCHEDULED_COST[end, :]) :
           isdefined(@__MODULE__, :total_scheduled_cost) ? sum(total_scheduled_cost[end, :]) : missing
solver=try
    isdefined(@__MODULE__, :pcm_solver_name) ? pcm_solver_name() : get(ENV, "PCM_SOLVER", "unknown")
catch
    get(ENV, "PCM_SOLVER", "unknown")
end
cluster_attempts=isdefined(@__MODULE__, :PCM_CLUSTER_ATTEMPTS) ? PCM_CLUSTER_ATTEMPTS[] : 0
cluster_successes=isdefined(@__MODULE__, :PCM_CLUSTER_SUCCESSES) ? PCM_CLUSTER_SUCCESSES[] : 0
cluster_fallbacks=isdefined(@__MODULE__, :PCM_CLUSTER_FALLBACKS) ? PCM_CLUSTER_FALLBACKS[] : 0
extended_integer_variables=isdefined(@__MODULE__, :PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES) ?
                           PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES[] : missing
simulation_time=isdefined(@__MODULE__, :PCM_SIMULATION_TIME_SEC) ? PCM_SIMULATION_TIME_SEC : (timed === nothing ? missing : timed.time)
training_time=isdefined(@__MODULE__, :PCM_ML_TRAINING_TIME_SEC) ? PCM_ML_TRAINING_TIME_SEC : 0.0
preprocess_time=isdefined(@__MODULE__, :PCM_OFFLINE_PREPROCESS_TIME_SEC) ? PCM_OFFLINE_PREPROCESS_TIME_SEC : 0.0

row=DataFrame(; timestamp = [string(now())], method = [METHOD], load_profile = [PROFILE], status = [status],
    solver = [solver],
    wall_time_sec = [timed === nothing ? missing : timed.time], allocated_mb = [timed === nothing ? missing : timed.bytes/1024^2],
    simulation_time_sec = [simulation_time], offline_training_time_sec = [training_time], offline_preprocess_time_sec = [preprocess_time],
    gc_time_sec = [timed === nothing ? missing : timed.gctime], peak_rss_mb = [Sys.maxrss()/1024^2], input_file = [INPUT_FILE],
    window_hours = [WINDOW_HOURS], intervals = [INTERVALS], physical_units = [physical_units], virtual_units = [virtual_units],
    commitment_integer_variables = [integer_variables], cluster_attempts = [cluster_attempts], cluster_successes = [cluster_successes],
    extended_integer_variables = [extended_integer_variables],
    cluster_fallbacks = [cluster_fallbacks], total_cost = [total_cost], failure = [failure])
mkpath(dirname(METRICS_PATH))
CSV.write(METRICS_PATH, row; append = isfile(METRICS_PATH), writeheader = !isfile(METRICS_PATH))
status=="OK" || error(failure)
