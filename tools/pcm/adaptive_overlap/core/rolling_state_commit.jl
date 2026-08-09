# PCM 滚动状态传递、结果提交与成本统计
# 更新相邻窗口边界条件，并仅提交实际执行时段的结果。

"""
    update_adaptive_boundary_conditions(
    	interval_scheduling_id::Int64,
    	NG::Int64,
    	exec_NT::Int64,
    	total_NT::Int64,
    	start_time::Int64,
    	units::unit,
    	loads::load,
    	winds::wind,
    	results::Union{Dict{String, Array{Float64}}, Nothing}
    )

Update initial boundary conditions and slice time-series inputs for an adaptive window simulation.
Boundary conditions (x_0, p_0, t_0, t_1) are extracted from time step `exec_NT` of previous results.
"""
function update_adaptive_boundary_conditions(interval_scheduling_id::Int64, NG::Int64, exec_NT::Int64, total_NT::Int64, start_time::Int64,
        units::unit, loads::load, winds::wind, results::Union{Dict{String, Array{Float64}}, Nothing})
    mini_units = deepcopy(units)

    if interval_scheduling_id != 1 && results !== nothing
        # Extract initial state from end of committed execution window (exec_NT) of prior interval
        mini_units.x_0 = results["x₀"][:, exec_NT]
        mini_units.p_0 = results["p₀"][:, exec_NT]

        # Calculate remaining dwell times up to step exec_NT
        u_sub = results["u₀"][:, 1:exec_NT]
        v_sub = results["v₀"][:, 1:exec_NT]
        res_up, res_down = get_generators_upoff_durations(units, u_sub, v_sub, NG)
        mini_units.t_0 = res_up[:, 1]
        mini_units.t_1 = res_down[:, 1]
    end

    to_time = start_time + total_NT - 1

    mini_loads = deepcopy(loads)
    mini_loads.load_curve = loads.load_curve[:, start_time:to_time]

    mini_winds = deepcopy(winds)
    mini_winds.scenarios_curve = winds.scenarios_curve[:, start_time:to_time]

    return mini_units, mini_loads, mini_winds
end

"""
    truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)

Extract and return only the committed execution period (1:exec_NT) from total window results.
"""
function truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)
    committed_results = Dict{String, Array{Float64}}()
    for (k, v) ∈ results
        if ndims(v) == 2 && size(v, 2) >= exec_NT
            committed_results[k] = v[:, 1:exec_NT]
        elseif ndims(v) == 3 && size(v, 2) >= exec_NT
            committed_results[k] = v[:, 1:exec_NT, :]
        elseif ndims(v) == 1
            committed_results[k] = v
        else
            committed_results[k] = v
        end
    end
    return committed_results
end

"""
    compute_committed_cost(
    	committed_results::Dict{String, Array{Float64}},
    	exec_NT::Int64,
    	units::unit,
    	loads::load,
    	winds::wind,
    	lines::transmissionline,
    	DataCentras::data_centra,
    	config_param::config,
    	interval_scheduling_id::Int64,
    	hydros::hydro,
    	scenarios_prob::Float64
    )

Compute 1x7 scheduling cost vector for the committed execution period (1:exec_NT).
"""
function compute_committed_cost(
        committed_results::Dict{String, Array{Float64}}, exec_NT::Int64, units::unit, loads::load, winds::wind, lines::transmissionline,
        DataCentras::data_centra, config_param::config, interval_scheduling_id::Int64, hydros::hydro, scenarios_prob::Float64)
    NS = winds.scenarios_nums
    NW = length(winds.index)
    NG = length(units.index)
    NB = length(units.locatebus)
    ND = length(loads.locatebus)
    NC = 0
    ND2 = length(DataCentras.locatebus)
    NH = length(hydros.locatebus)

    refcost, eachslope = linearizationfuelcurve(units, NG)

    committed_winds = deepcopy(winds)
    committed_winds.scenarios_curve = winds.scenarios_curve[:, 1:exec_NT]

    su_cost = committed_results["su_cost"]
    sd_cost = committed_results["sd_cost"]
    pgₖ = committed_results["pₖ"]
    pg₀ = committed_results["p₀"]
    x₀ = committed_results["x₀"]
    seq_sr⁺ = committed_results["seq_sr⁺"]
    seq_sr⁻ = committed_results["seq_sr⁻"]
    pᵨ = committed_results["pᵨ"]
    pᵩ = committed_results["pᵩ"]

    # Set global scenarios_prob if required by exported_scheduling_cost
    global scenarios_prob = scenarios_prob

    str = exported_scheduling_cost(NS, exec_NT, NB, NG, ND, NC, ND2, NH, units, loads, committed_winds, lines, DataCentras, config_param,
        interval_scheduling_id, su_cost, sd_cost, pgₖ, pg₀, x₀, seq_sr⁺, seq_sr⁻, pᵨ, pᵩ, eachslope, refcost)
    return str
end
