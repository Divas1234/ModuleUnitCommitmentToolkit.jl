"""
	data_center_workload_profile(data_centers, time_count, data_center_count; scale)

Return a `data_center_count x time_count` workload matrix. The current Excel
case provides one shared `time_count x 1` curve, while the reference model also
supports center-specific matrices.
"""
function data_center_workload_profile(DataCentras, time_count::Int, data_center_count::Int; scale::Float64 = 10.0)
    tasks = Matrix{Float64}(DataCentras.computational_power_tasks)
    if size(tasks) == (time_count, data_center_count)
        return tasks' .* scale
    elseif size(tasks) == (data_center_count, time_count)
        return tasks .* scale
    elseif size(tasks) == (time_count, 1)
        return repeat(reshape(vec(tasks), 1, time_count), data_center_count, 1) .* scale
    elseif size(tasks) == (1, time_count)
        return repeat(tasks, data_center_count, 1) .* scale
    elseif length(tasks) == time_count && data_center_count == 1
        return reshape(vec(tasks), 1, time_count) .* scale
    else
        error(
            "Data center computational_power_tasks must be time x center or center x time; got $(size(tasks)), time_count=$time_count, data_center_count=$data_center_count",
        )
    end
end

"""
	validate_data_center_configuration(data_centers, time_count, data_center_count)

Normalize workload inputs and warn when raw data is tighter than the nominal
non-responsive workload. This is diagnostic only; feasibility is still governed
by the optimization constraints.
"""
function validate_data_center_configuration(DataCentras, time_count::Int, data_center_count::Int)
    workload = data_center_workload_profile(DataCentras, time_count, data_center_count)
    estimated_power = zeros(Float64, data_center_count, time_count)
    for t in 1:time_count
        estimated_power[:, t] = DataCentras.idale .+ DataCentras.sv_constant ./ DataCentras.μ .* workload[:, t]
    end
    required_peak = vec(maximum(estimated_power; dims = 2))
    if any(DataCentras.p_max .< required_peak)
        @warn "Some data center p_max values are below the nominal workload peak" p_max = DataCentras.p_max required_peak = required_peak
    end
    return workload
end

function data_center_time_blocks(time_count::Int; block_count::Int = 6)
    block_count = min(block_count, time_count)
    block_size = Int(ceil(time_count / block_count))
    return [
        (first = (i - 1) * block_size + 1, last = min(i * block_size, time_count)) for i in 1:block_count if (i - 1) * block_size + 1 <= time_count
    ]
end
