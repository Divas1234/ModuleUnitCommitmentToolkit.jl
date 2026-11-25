"""
    get_batch_scuc_subproblems_for_scenario(NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, data_centers, psses, scenarios_prob, config_param)

Build independent per-scenario LP recourse subproblems for multi-cut Benders decomposition.
"""
function get_batch_scuc_subproblems_for_scenario(
    NT::Int64,
    NB::Int64,
    NL::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NW::Int64,
    units::unit,
    winds::wind,
    loads::load,
    lines::transmissionline,
    data_centers::DataCenters,
    psses::pss,
    scenarios_prob::Float64,
    config_param::config,
)
    config_param.consider_multi_cuts == 1 ||
        throw(ArgumentError("Batch scenario subproblems require config_param.consider_multi_cuts == 1; got $(config_param.consider_multi_cuts)"))

    batch_scuc_model_structure_dic = OrderedDict{Int64, SCUC_Model}()
    for s in 1:Int64(winds.scenarios_nums)
        scenario_winds = build_single_scenario_wind(winds, s, scenarios_prob)
        _, scenario_subproblem_struct = bd_subfunction(
            NT,
            NB,
            NL,
            NG,
            ND,
            NC,
            ND2,
            Int64(1),
            NW,
            units,
            scenario_winds,
            loads,
            lines,
            data_centers,
            psses,
            scenarios_prob,
            config_param,
        )
        batch_scuc_model_structure_dic[s] = scenario_subproblem_struct
    end

    return batch_scuc_model_structure_dic
end

"""
`modify_winds_constr_rhs!(...)`

Updates the normalized RHS of wind curtailment constraints based on a specific
scenario realization. This avoids rebuilding the model from scratch for each scenario.
"""
function modify_winds_constr_rhs!(scuc_subproblem, winds, scenarios_curve, NT::Int64, NW::Int64)

    # Retrieve the constraint reference for wind curtailment
    modified_constr = scuc_subproblem[:winds_curt_constr_for_eachscenario]

    # Batch update normalized RHS using vectorized operations: p_wind <= Capacity * Scalar realization
    wind_rhs = vec([scenarios_curve[t] * winds.p_max[w, 1] for t in 1:NT, w in 1:NW])
    set_normalized_rhs.(vec([modified_constr[1, t][w] for t in 1:NT, w in 1:NW]), wind_rhs)

    # Return the flattened constraint vector for easier tracking
    modified_constr = vec(collect(Iterators.flatten(modified_constr)))
    return scuc_subproblem, modified_constr
end

function build_mean_scenario_wind(winds::wind, scenarios_prob::Float64 = 1.0)
    mean_curve = vec(sum(winds.scenarios_curve; dims = 1)) ./ size(winds.scenarios_curve, 1)
    return wind(
        winds.index,
        winds.locatebus,
        winds.p_max,
        scenarios_prob,
        Int64(1),
        reshape(mean_curve, 1, length(mean_curve)),
        winds.Fcmode,
        winds.Kw,
        winds.Rw,
        winds.Mw,
        winds.Dw,
        winds.Tw,
    )
end

function build_single_scenario_wind(winds::wind, scenario_index::Int64, scenarios_prob::Float64)
    return wind(
        winds.index,
        winds.locatebus,
        winds.p_max,
        scenarios_prob,
        Int64(1),
        reshape(winds.scenarios_curve[scenario_index, :], 1, size(winds.scenarios_curve, 2)),
        winds.Fcmode,
        winds.Kw,
        winds.Rw,
        winds.Mw,
        winds.Dw,
        winds.Tw,
    )
end

function build_scenario_group_wind(winds::wind, scenario_indices::Vector{Int}, group_prob::Float64)
    mean_curve = reshape(vec(mean(winds.scenarios_curve[scenario_indices, :]; dims = 1)), 1, size(winds.scenarios_curve, 2))
    return wind(
        winds.index,
        winds.locatebus,
        winds.p_max,
        group_prob,
        Int64(1),
        mean_curve,
        winds.Fcmode,
        winds.Kw,
        winds.Rw,
        winds.Mw,
        winds.Dw,
        winds.Tw;
        area = winds.area,
    )
end

"""
    build_jensen_subproblem_groups(...) -> Vector{NamedTuple{(:scenarios, :subproblem), Tuple{Vector{Int}, SCUC_Model}}}

Build Jensen-inequality subproblems covering every scenario:
1. Global mean scenario over `1:NS` (weight `1.0`): `sum(θ[1:NS]) >= Q(x, E[ξ])`.
2. When `NS >= 4`, disjoint quantile groups `G_1, ..., G_K` ordered by total wind availability
   (each `|G_k| >= 2`, weight `|G_k| / NS`): `sum(θ[s] for s in G_k) >= (|G_k|/NS) * Q(x, E[ξ | G_k])`.
"""
function build_jensen_subproblem_groups(
    NT::Int64,
    NB::Int64,
    NL::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NW::Int64,
    units::unit,
    winds::wind,
    loads::load,
    lines::transmissionline,
    data_centers::DataCenters,
    psses::pss,
    config_param::config;
    max_groups::Int = parse(Int, get(ENV, "BENDERS_JENSEN_MAX_GROUPS", "4")),
)
    NS = Int(winds.scenarios_nums)
    NS < 2 && return NamedTuple{(:scenarios, :subproblem), Tuple{Vector{Int}, SCUC_Model}}[]
    groups = NamedTuple{(:scenarios, :subproblem), Tuple{Vector{Int}, SCUC_Model}}[]

    # 1. Global mean Jensen subproblem
    all_scenarios = collect(1:NS)
    global_sub = build_jensen_subproblem_for_mean_scenario(
        NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, data_centers, psses, config_param,
    )
    push!(groups, (scenarios = all_scenarios, subproblem = global_sub))

    # 2. Quantile-partitioned group Jensen subproblems (every scenario belongs to one local group)
    n_groups = min(fld(NS, 2), max(1, max_groups))
    if NS >= 4 && n_groups >= 2
        order = sortperm([sum(@view winds.scenarios_curve[s, :]) for s in 1:NS])
        base_size, rem = divrem(NS, n_groups)
        cursor = 1
        for k in 1:n_groups
            g_size = base_size + (k <= rem ? 1 : 0)
            g_scenarios = sort!(order[cursor:(cursor + g_size - 1)])
            cursor += g_size
            group_prob = Float64(length(g_scenarios)) / Float64(NS)
            group_winds = build_scenario_group_wind(winds, g_scenarios, group_prob)
            _, group_sub = bd_subfunction(
                NT, NB, NL, NG, ND, NC, ND2, Int64(1), NW, units, group_winds, loads, lines, data_centers, psses, group_prob, config_param,
            )
            push!(groups, (scenarios = g_scenarios, subproblem = group_sub))
        end
    end
    return groups
end

function build_jensen_subproblem_for_mean_scenario(
    NT::Int64,
    NB::Int64,
    NL::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NW::Int64,
    units::unit,
    winds::wind,
    loads::load,
    lines::transmissionline,
    data_centers::DataCenters,
    psses::pss,
    config_param::config,
)
    mean_winds = build_mean_scenario_wind(winds, 1.0)
    _, jensen_subproblem_struct =
        bd_subfunction(NT, NB, NL, NG, ND, NC, ND2, Int64(1), NW, units, mean_winds, loads, lines, data_centers, psses, 1.0, config_param)
    return jensen_subproblem_struct
end
