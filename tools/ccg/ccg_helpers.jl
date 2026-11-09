function choose_initial_ccg_scenarios(data, initial_count::Int64)
    initial_count > 0 || throw(ArgumentError("initial_count must be positive; got $initial_count"))
    initial_count <= data.NS || throw(ArgumentError("initial_count ($initial_count) cannot exceed scenario count ($(data.NS))"))

    policy = lowercase(strip(get(ENV, "CCG_INITIAL_POLICY", "netload")))
    if policy == "first"
        return collect(1:initial_count)
    end

    wind_capacity = sum(data.winds.p_max)
    load_by_time = vec(sum(data.loads.load_curve; dims = 1))
    scores = [
        (
            maximum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity) +
            0.05 * sum(load_by_time .- data.winds.scenarios_curve[s, :] .* wind_capacity),
            s,
        ) for s in 1:data.NS
    ]
    sort!(scores; by = item -> item[1], rev = true)
    selected = [s for (_, s) in first(scores, initial_count)]
    sort!(selected)
    return selected
end

function choose_ccg_scenarios_to_add(
    evaluation,
    inactive_scenarios::Vector{Int64},
    scenarios_per_iteration::Int64,
    worst_probability::Vector{Float64},
)
    scenarios_per_iteration > 0 || throw(ArgumentError("scenarios_per_iteration must be positive; got $scenarios_per_iteration"))
    isempty(inactive_scenarios) && return Int64[]
    all(1 .<= inactive_scenarios .<= length(worst_probability)) ||
        throw(ArgumentError("inactive_scenarios must be valid indices for worst_probability"))
    all(haskey(evaluation, s) for s in inactive_scenarios) || throw(ArgumentError("evaluation is missing one or more inactive scenarios"))

    candidates = [(worst_probability[s], evaluation[s].recourse_cost, s) for s in inactive_scenarios]
    sort!(candidates; by = item -> (item[1], item[2]), rev = true)
    return [s for (_, _, s) in first(candidates, min(scenarios_per_iteration, length(candidates)))]
end

function build_ccg_subset_wind(winds::wind, selected_scenarios::Vector{Int64}, scenarios_prob::Float64)
    validate_selected_scenarios(selected_scenarios, Int64(winds.scenarios_nums))
    return wind(
        winds.index,
        winds.locatebus,
        winds.p_max,
        scenarios_prob,
        length(selected_scenarios),
        winds.scenarios_curve[selected_scenarios, :],
        winds.Fcmode,
        winds.Kw,
        winds.Rw,
        winds.Mw,
        winds.Dw,
        winds.Tw,
    )
end
