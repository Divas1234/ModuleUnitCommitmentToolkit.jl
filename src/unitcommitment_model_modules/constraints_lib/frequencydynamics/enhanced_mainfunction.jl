include("_automatic_workflow.jl")

# =============================
# 频率动态模块主入口（增强版）
# =============================
# 说明：
# 1) 该文件作为“单一主流程实现”；
# 2) mainfunction.jl 仅做兼容入口，避免双份逻辑漂移；
# 3) 通过关键字参数控制保存路径、是否展示图像等行为。

const FLAG_CONVERTER = Int64(0)
const DEFAULT_FIG_DIR = "fig"
const DEFAULT_FIG_BASENAME = "output_plot"

"""
	validate_control_configuration(controller_config)

Validate converter controller configuration and return `(vsm_params, droop_params)`.
"""
function validate_control_configuration(controller_config::Dict)
	if !haskey(controller_config, "VSM") || !haskey(controller_config, "Droop")
		error("Error: 'VSM' or 'Droop' keys are missing in the controller configuration.")
	end

	if !haskey(controller_config["VSM"], "control_parameters") || !haskey(controller_config["Droop"], "control_parameters")
		error("Error: 'control_parameters' key is missing in 'VSM' or 'Droop' configuration.")
	end

	vsm_params = controller_config["VSM"]["control_parameters"]
	droop_params = controller_config["Droop"]["control_parameters"]

	return vsm_params, droop_params
end

"""
	validate_parameters(params, param_names)

Validate that required parameters exist, are numeric, and are positive (except `droop`).
"""
function validate_parameters(params::Dict, param_names::Vector{String})
	for name in param_names
		if !haskey(params, name)
			error("Error: Missing parameter '$name' in configuration.")
		elseif !isa(params[name], Number)
			error("Error: Parameter '$name' must be a number.")
		elseif params[name] <= 0 && name != "droop"
			error("Error: Parameter '$name' must be positive.")
		end
	end
end

"""
	validate_boundary_parameters(params)

Validate outputs from `get_parmeters`.
"""
function validate_boundary_parameters(params::Tuple)
	param_names = ["initial_inertia", "factorial_coefficient", "time_constant", "droop", "ROCOF_threshold", "NADIR_threshold", "power_deviation"]
	for (i, param) in enumerate(params)
		if !isa(param, Number)
			error("Error: Parameter '$(param_names[i])' from get_parmeters must be a number.")
		end
		if param <= 0 && param_names[i] != "droop"
			error("Error: Parameter '$(param_names[i])' from get_parmeters must be positive.")
		end
	end
end

"""
	validate_inertia_limits(min_inertia, max_inertia)

Validate outputs from `estimate_inertia_limits`.
"""
function validate_inertia_limits(min_inertia, max_inertia)
	if !isa(min_inertia, Number) || !isa(max_inertia, AbstractArray)
		error("Error: min_inertia must be a number and max_inertia must be an array.")
	end

	if isempty(max_inertia)
		error("Error: max_inertia cannot be empty.")
	end

	if min_inertia >= maximum(max_inertia)
		error("Error: min_inertia must be less than max_inertia")
	end
end

"""
    ensure_output_directory(output_dir::AbstractString)

确保输出目录存在，若不存在则自动创建。
"""
function ensure_output_directory(output_dir::AbstractString)
	if !isdir(output_dir)
		mkpath(output_dir)
	end
	return output_dir
end

"""
    run_frequency_dynamics_workflow(; kwargs...)

统一主流程入口（推荐外部调用该函数）。

# 关键字参数
- `flag_converter::Int = FLAG_CONVERTER`
- `show_plot::Bool = true`              是否显示主图
- `save_plot::Bool = true`              是否保存图像
- `output_dir::AbstractString = joinpath(pwd(), DEFAULT_FIG_DIR)`
- `output_basename::AbstractString = DEFAULT_FIG_BASENAME`

# 返回
返回一个 `NamedTuple`，便于上层脚本按需复用中间结果。
"""
function run_frequency_dynamics_workflow(; flag_converter::Int = FLAG_CONVERTER, show_plot::Bool = true, save_plot::Bool = true, output_dir::AbstractString = joinpath(pwd(), DEFAULT_FIG_DIR), output_basename::AbstractString = DEFAULT_FIG_BASENAME)
	# 1) 读取并校验控制器配置
	controller_config = converter_formming_configuations()
	converter_vsm_parameters, converter_droop_parameters = validate_control_configuration(controller_config)
	println("Controller configuration loaded and validated successfully.")

	# 2) 校验 converter 参数
	validate_parameters(converter_vsm_parameters, ["inertia", "damping", "time_constant"])
	validate_parameters(converter_droop_parameters, ["droop", "time_constant"])
	println("Converter parameters validated successfully.")

	# 3) 获取并校验边界参数
	initial_inertia, factorial_coefficient, time_constant, droop, rocof_threshold, nadir_threshold, power_deviation = get_parmeters(flag_converter)
	validate_boundary_parameters((initial_inertia, factorial_coefficient, time_constant, droop, rocof_threshold, nadir_threshold, power_deviation))
	println("Boundary parameters validated successfully.")

	# 4) 计算惯量边界曲线
	inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids = calculate_inertia_parameters(
		initial_inertia,
		factorial_coefficient,
		time_constant,
		droop,
		power_deviation,
		DAMPING_RANGE,
		converter_vsm_parameters,
		converter_droop_parameters,
		flag_converter,
	)
	println("Output from calculate_inertia_parameters validated successfully.")

	# 5) 估计惯量极值并校验
	min_inertia, max_inertia = estimate_inertia_limits(rocof_threshold, power_deviation, DAMPING_RANGE, factorial_coefficient, time_constant, droop)
	validate_inertia_limits(min_inertia, max_inertia)
	println("Output from estimate_inertia_limits validated successfully.")

	# 6) 可视化
	p1, sy1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids, max_inertia, min_inertia)

	if show_plot
		show(p1)
		Plots.plot(sy1; size = (400, 400))
	end

	if save_plot
		ensure_output_directory(output_dir)
		Plots.savefig(joinpath(output_dir, "$(output_basename).png"))
		Plots.savefig(joinpath(output_dir, "$(output_basename).pdf"))
	end

	println("Calculations complete. Plot generated.")

	return (
		plot = p1,
		sub_plot = sy1,
		inertia_updown_bindings = inertia_updown_bindings,
		extreme_inertia = extreme_inertia,
		nadir_vector = nadir_vector,
		inertia_vector = inertia_vector,
		selected_ids = selected_ids,
		min_inertia = min_inertia,
		max_inertia = max_inertia,
	)
end

"""
    run_main_entrypoint()

对外统一入口（语义更清晰，便于其他脚本调用）。
"""
function run_main_entrypoint()
	return run_frequency_dynamics_workflow()
end

# Execute only when run as the main script, not when included by other files.
if abspath(PROGRAM_FILE) == @__FILE__
	run_main_entrypoint()
end
