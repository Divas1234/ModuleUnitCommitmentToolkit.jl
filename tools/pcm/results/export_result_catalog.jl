"""
PCM 结果清单与全时段结果导出器。

求解器仍按窗口保存原始结果；本文件只做无损后处理：每个窗口仅提取正式执行
时段（不含交叠尾部），拼接成全时域机组组合、出力和储能计划，并生成文件清单。
"""
module PCMResultCatalog

using CSV
using DataFrames
using DelimitedFiles
using Dates

const MATRIX_OUTPUTS = Dict(
    "details_thermalunits_statues.csv" => "full_horizon_unit_commitment.csv",
    "details_thermalunits_output.csv" => "full_horizon_thermal_dispatch.csv",
    "details_windunits_output.csv" => "full_horizon_wind_dispatch.csv",
    "details_windunits_wasted_output.csv" => "full_horizon_wind_curtailment.csv",
    "details_forced_load_curtailment.csv" => "full_horizon_load_curtailment.csv",
    "details_bess_charging_output.csv" => "full_horizon_storage_charging.csv",
    "details_bess_discharging_output.csv" => "full_horizon_storage_discharging.csv",
    "details_bess_soc.csv" => "full_horizon_storage_state_of_charge.csv",
)

interval_id(path) = something(tryparse(Int, something(match(r"intervels_\[(\d+)\]", path), match(r"intervals_\[(\d+)\]", path)).captures[1]), 0)

function interval_directories(run_dir)
    roots = filter(isdir, [
        joinpath(run_dir, "output", "details_schedule_results", "pcm_simulation_results"),
        joinpath(run_dir, "output", "details_schedule_results", "adaptive_pcm_simulation_results", "pcm_simulation_results"),
    ])
    dirs = String[]
    for root in roots, entry in readdir(root; join=true)
        isdir(entry) && occursin(r"inter(?:ve|va)ls_\[\d+\]", entry) && push!(dirs, entry)
    end
    sort!(unique!(dirs); by=interval_id)
end

read_matrix(path) = Matrix{Float64}(readdlm(path, ',', Float64))

const LEGACY_SECTION = Dict(
    "details_thermalunits_statues.csv" => 1,
    "details_thermalunits_output.csv" => 2,
    "details_windunits_wasted_output.csv" => 3,
    "details_forced_load_curtailment.csv" => 4,
    "details_bess_charging_output.csv" => 7,
    "details_bess_discharging_output.csv" => 8,
    "details_bess_soc.csv" => 9,
)

function read_legacy_section(path, section_id)
    rows = Vector{Vector{Float64}}()
    active = false
    for line in eachline(path)
        marker = match(r"^list\s+(\d+):", strip(line))
        if marker !== nothing
            active = parse(Int, marker.captures[1]) == section_id
            !active && !isempty(rows) && break
            continue
        end
        active || continue
        values = tryparse.(Float64, split(strip(line)))
        !isempty(values) && all(!isnothing, values) && push!(rows, Float64[something(v) for v in values])
    end
    isempty(rows) && return nothing
    width = minimum(length.(rows))
    reduce(vcat, permutedims.(getindex.(rows, Ref(1:width))))
end

function stitch_matrix(interval_dirs, source_name, execution_hours)
    pieces = Matrix{Float64}[]
    for dir in interval_dirs
        path = joinpath(dir, source_name)
        matrix = if isfile(path)
            read_matrix(path)
        else
            legacy = joinpath(dir, "res_schedule_commitment_result.txt")
            haskey(LEGACY_SECTION, source_name) && isfile(legacy) ?
                read_legacy_section(legacy, LEGACY_SECTION[source_name]) : nothing
        end
        matrix === nothing && continue
        # 机组/储能维度在行，时间在列；只提交正式执行窗，严格截断交叠尾部。
        push!(pieces, matrix[:, 1:min(execution_hours, size(matrix, 2))])
    end
    isempty(pieces) ? nothing : hcat(pieces...)
end

function write_boundary_dwell_state(path, commitment, execution_hours)
    rows = DataFrame(Interval_ID=Int[], Boundary_Hour=Int[], Unit_ID=Int[],
        On_Status=Int[], Consecutive_State_Hours=Int[])
    for boundary in execution_hours:execution_hours:size(commitment, 2)
        for unit in axes(commitment, 1)
            state = commitment[unit, boundary] >= 0.5
            duration = 1
            t = boundary - 1
            while t >= 1 && (commitment[unit, t] >= 0.5) == state
                duration += 1
                t -= 1
            end
            push!(rows, (boundary ÷ execution_hours, boundary, unit, Int(state), duration))
        end
    end
    CSV.write(path, rows)
end

function find_overlap_stats(run_dir)
    candidates = String[]
    for (root, _, files) in walkdir(run_dir)
        "overlap_window_statistics.csv" in files && push!(candidates, joinpath(root, "overlap_window_statistics.csv"))
    end
    isempty(candidates) ? nothing : first(candidates)
end

function export_run_catalog(run_dir; execution_hours=24)
    result_dir = joinpath(run_dir, "result_catalog")
    mkpath(result_dir)
    intervals = interval_directories(run_dir)
    produced = String[]
    commitment = nothing
    for (source, target) in MATRIX_OUTPUTS
        matrix = stitch_matrix(intervals, source, execution_hours)
        matrix === nothing && continue
        target_path = joinpath(result_dir, target)
        writedlm(target_path, matrix, ',')
        push!(produced, target_path)
        source == "details_thermalunits_statues.csv" && (commitment = matrix)
    end
    if commitment !== nothing
        dwell_path = joinpath(result_dir, "interval_boundary_unit_state.csv")
        write_boundary_dwell_state(dwell_path, commitment, execution_hours)
        push!(produced, dwell_path)
    end

    overlap = find_overlap_stats(run_dir)
    if overlap !== nothing
        df = CSV.read(overlap, DataFrame)
        # 保留 T-steady、ramp、unit-dwell、最终交叠长度和每窗耗时的完整原始字段。
        overlap_path = joinpath(result_dir, "overlap_window_details.csv")
        CSV.write(overlap_path, df)
        push!(produced, overlap_path)
    end

    cost_candidates = filter(isfile, [
        joinpath(run_dir, "output", "details_schedule_results", "adaptive_pcm_simulation_results", "total_scheduled_results.csv"),
        joinpath(run_dir, "output", "details_schedule_results", "clustered_adaptive_pcm_simulation_results", "total_scheduled_results.csv"),
        joinpath(run_dir, "output", "details_schedule_results", "pcm_simulation_results", "summary_scheduling_report", "total_scheduled_results.csv"),
    ])
    if !isempty(cost_candidates)
        cp(first(cost_candidates), joinpath(result_dir, "scheduling_cost_by_interval_and_total.csv"); force=true)
        push!(produced, joinpath(result_dir, "scheduling_cost_by_interval_and_total.csv"))
    end

    inventory = DataFrame(Category=String[], File=String[], Exists=Bool[], Description=String[])
    descriptions = Dict(
        "full_horizon_unit_commitment.csv" => "全时段逐机组开停机决策",
        "full_horizon_thermal_dispatch.csv" => "全时段逐机组出力计划",
        "full_horizon_storage_charging.csv" => "全时段储能充电功率（启用储能时）",
        "full_horizon_storage_discharging.csv" => "全时段储能放电功率（启用储能时）",
        "full_horizon_storage_state_of_charge.csv" => "全时段储能荷电状态（模型提供 SOC 时）",
        "overlap_window_details.csv" => "逐窗 T-steady、unit-dwell、ramp-overlap 与最终交叠时长",
        "interval_boundary_unit_state.csv" => "窗口边界剩余机组开停状态及连续状态时长",
        "scheduling_cost_by_interval_and_total.csv" => "逐窗与全时段调度成本",
    )
    for (name, desc) in sort!(collect(descriptions); by=first)
        path = joinpath(result_dir, name)
        push!(inventory, ("result", name, isfile(path), desc))
    end
    for (i, dir) in enumerate(intervals)
        push!(inventory, ("process", relpath(dir, run_dir), true, "第 $i 个 PCM 子问题原始计算结果"))
    end
    isfile(joinpath(run_dir, "run.log")) && push!(inventory, ("process", "run.log", true, "完整计算过程日志"))
    isfile(joinpath(run_dir, "metrics.csv")) && push!(inventory, ("performance", "metrics.csv", true, "耗时、内存、成本与状态指标"))
    CSV.write(joinpath(result_dir, "result_inventory.csv"), inventory)
    open(joinpath(result_dir, "README.md"), "w") do io
        println(io, "# PCM 结果清单\n")
        println(io, "生成时间：$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))  \n正式执行窗：$execution_hours h\n")
        println(io, "全时段文件由各子问题的前 `$execution_hours` 小时拼接，交叠尾部不会重复计入。")
        println(io, "储能文件仅在模型启用并实际输出相应变量时存在；未启用时清单中的 Exists 为 false。")
    end
    result_dir
end

function export_suite_catalog(output_root; execution_hours=24)
    runs = String[]
    for (root, _, files) in walkdir(output_root)
        "metrics.csv" in files && "run.log" in files && push!(runs, root)
    end
    for run in sort!(unique!(runs))
        export_run_catalog(run; execution_hours)
    end
    println("Result catalogs exported for $(length(runs)) runs under: $output_root")
    output_root
end

end
