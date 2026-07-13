# Column-and-Constraint Generation (C&CG) driver for finite-scenario SCUC.
#
# The master solves an extensive-form UC over a dynamically selected scenario
# subset. The separation step fixes the first-stage unit commitment and solves
# single-scenario recourse MIPs over the candidate scenario pool, then adds the
# worst uncovered scenarios to the master.

include(joinpath(@__DIR__, "..", "benders", "setup.jl"))
include("dro_uncertainty.jl")
include("ccg_helpers.jl")

#%%%
"""
	solve_ccg_unit_commitment(; scenario_limit = 20)

Solve stochastic SCUC with column-and-constraint generation.

The master starts with a small active scenario set. Each iteration fixes the
first-stage commitment, evaluates every candidate scenario through recourse,
and appends the worst uncovered scenarios. When DRO is enabled, the upper bound
uses the Wasserstein worst-case probability vector instead of the nominal
empirical distribution.
"""
function solve_ccg_unit_commitment(;
    input::Union{Symbol, AbstractString} = :excel,
    scenario_limit::Int64 = 20,
    use_powersystems::Union{Nothing, Bool} = nothing,
    sys = nothing,
    case_name = nothing,
    case_category = MatpowerTestSystems,
    case_dir::String = "",
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    data = load_ccg_data(
        scenario_limit;
        input = input,
        use_powersystems = use_powersystems,
        sys = sys,
        case_name = case_name,
        case_category = case_category,
        case_dir = case_dir,
        data_center_buses = data_center_buses,
        data_center_pmax = data_center_pmax,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
    )
    initial_count = clamp(parse(Int64, get(ENV, "CCG_INITIAL_SCENARIOS", string(min(3, data.NS)))), 1, data.NS)
    scenarios_per_iteration = max(1, parse(Int64, get(ENV, "CCG_SCENARIOS_PER_ITERATION", "2")))
    max_iterations = parse(Int64, get(ENV, "CCG_MAX_ITERATIONS", "50"))
    gap_tolerance = parse(Float64, get(ENV, "CCG_GAP_TOL", "1e-3"))
    numerical_tolerance = 1e-6

    selected = choose_initial_ccg_scenarios(data, initial_count)
    best_upper_bound = Inf
    best_lower_bound = -Inf
    best_model = nothing
    best_evaluation = nothing
    best_data = data
    best_active_scenarios = Int64[]
    history = NamedTuple[]

    println("Starting C&CG unit commitment solver")
    println("candidate scenarios: ", data.NS)
    println("initial scenarios:   ", selected)
    println("DRO enabled:         ", data.dro.enabled, " (", data.dro.metric, " radius: ", data.dro.radius, ")")
    println("parallel recourse:   ", ccg_parallel_recourse_enabled(), " (Julia threads: ", Threads.nthreads(), ")")
    println("====================================================")
    println("ITER \t ACTIVE \t LOWER_bound \t UPPER_bound \t GAP \t ADDED")
    println("----------------------------------------------------")

    for iteration in 1:max_iterations
        master_model = solve_ccg_master(data, selected)
        first_stage = extract_first_stage_solution(master_model)
        evaluation = evaluate_ccg_recourse_pool(data, first_stage)

        current_lower_bound = objective_bound(master_model)
        recourse_costs = [evaluation[s].recourse_cost for s in 1:data.NS]
        worst_recourse_cost, worst_probability = worst_case_expected_value(
            recourse_costs,
            data.dro.nominal_probability,
            data.dro.enabled ? data.dro.radius : 0.0,
            data.dro.distance_matrix,
        )
        current_upper_bound = first_stage.cost + worst_recourse_cost
        best_lower_bound = max(best_lower_bound, current_lower_bound)
        if current_upper_bound < best_upper_bound
            best_upper_bound = current_upper_bound
            best_model = master_model
            best_evaluation = evaluation
            best_active_scenarios = copy(selected)
        end

        gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance)
        inactive_scenarios = setdiff(collect(1:data.NS), selected)
        scenarios_to_add = choose_ccg_scenarios_to_add(evaluation, inactive_scenarios, scenarios_per_iteration, worst_probability)
        push!(
            history,
            (
                iteration = iteration,
                active_scenarios = length(selected),
                lower_bound = best_lower_bound,
                upper_bound = best_upper_bound,
                gap = gap,
                added_scenarios = copy(scenarios_to_add),
                memory_mb = process_memory_mb(),
            ),
        )
        print_ccg_iteration(iteration, length(selected), best_lower_bound, best_upper_bound, gap, scenarios_to_add)

        if gap <= gap_tolerance || isempty(scenarios_to_add)
            exported_active_scenarios = isempty(best_active_scenarios) ? selected : best_active_scenarios
            cost_summary = export_ccg_schedule_results(best_model, data, exported_active_scenarios)
            println("\n====================================================")
            println("C&CG convergence achieved")
            println("FINAL ACTIVE SCENARIOS: ", selected)
            println("FINAL UPPER BOUND:      ", best_upper_bound)
            println("FINAL LOWER BOUND:      ", best_lower_bound)
            println("FINAL GAP:              ", gap)
            println("====================================================")
            return (
                status = "converged",
                model = best_model,
                evaluation = best_evaluation,
                data = best_data,
                history = history,
                active_scenarios = exported_active_scenarios,
                upper_bound = best_upper_bound,
                lower_bound = best_lower_bound,
                gap = gap,
                cost_summary = cost_summary,
            )
        end

        append!(selected, scenarios_to_add)
        sort!(unique!(selected))
    end

    println("====================================================")
    println("C&CG stopped at maximum iterations")
    println("FINAL ACTIVE SCENARIOS: ", selected)
    println("FINAL UPPER BOUND:      ", best_upper_bound)
    println("FINAL LOWER BOUND:      ", best_lower_bound)
    println("FINAL GAP:              ", abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance))
    println("====================================================")
    exported_active_scenarios = isempty(best_active_scenarios) ? selected : best_active_scenarios
    cost_summary = export_ccg_schedule_results(best_model, data, exported_active_scenarios)
    return (
        status = "maximum_iterations",
        model = best_model,
        evaluation = best_evaluation,
        data = best_data,
        history = history,
        active_scenarios = exported_active_scenarios,
        upper_bound = best_upper_bound,
        lower_bound = best_lower_bound,
        gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + numerical_tolerance),
        cost_summary = cost_summary,
    )
end

#%%%
function export_ccg_schedule_results(model, data, active_scenarios::Vector{Int64})
    if model === nothing
        return nothing
    end
    active_winds = build_ccg_subset_wind(data.winds, active_scenarios, data.full_scenario_probability)
    return export_solved_uc_model_results(
        model,
        data;
        output_dir = uc_scheduling_output_dir("ccg"),
        winds = active_winds,
        NS = length(active_scenarios),
        scenarios_prob = data.full_scenario_probability,
        file_prefix = uc_schedule_file_prefix("ccg", data.NS),
    )
end

function ccg_env_bool(name::String, default::Bool)
    # Accept common boolean spellings because these values often come from shell,
    # CI variables, or TOML booleans converted by the runtime loader.
    value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    return value in ("1", "true", "yes", "y", "on")
end

function ccg_parallel_recourse_enabled()
    return ccg_env_bool("CCG_PARALLEL_RECOURSE", Threads.nthreads() > 1)
end

function ccg_optimizer_threads(env_name::String, default_value::Int64)
    return parse(Int64, get(ENV, env_name, string(default_value)))
end

function load_ccg_data(
    scenario_limit::Int64;
    input::Union{Symbol, AbstractString} = :excel,
    use_powersystems::Union{Nothing, Bool} = nothing,
    sys = nothing,
    case_name = nothing,
    case_category = MatpowerTestSystems,
    case_dir::String = "",
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    # CCG reuses the same data ingestion pipeline as Benders so that topology,
    # model flags, wind scenarios, and boundary diagnostics stay identical across
    # algorithm comparisons.
    data = load_uc_data(;
        scenario_limit = scenario_limit,
        input = input,
        use_powersystems = use_powersystems,
        sys = sys,
        case_name = case_name,
        case_category = case_category,
        case_dir = case_dir,
        data_center_buses = data_center_buses,
        data_center_pmax = data_center_pmax,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
    )
    maybe_print_boundarycondition(
        data.NB,
        data.NL,
        data.NG,
        data.NT,
        data.ND,
        data.units,
        data.loads,
        data.lines,
        data.winds,
        data.psses,
        data.config_param,
    )
    return (
        config_param = data.config_param,
        units = data.units,
        lines = data.lines,
        loads = data.loads,
        winds = data.winds,
        psses = data.psses,
        DataCentras = data.DataCentras,
        NB = data.NB,
        NG = data.NG,
        NL = data.NL,
        ND = data.ND,
        NT = data.NT,
        NC = data.NC,
        ND2 = data.ND2,
        NW = data.NW,
        NS = data.NS,
        full_scenario_probability = data.full_scenario_probability,
        dro = build_renewable_dro_model(data.winds),
    )
end

function solve_ccg_master(data, selected_scenarios::Vector{Int64})
    # Build the extensive-form master over only the active scenario subset. The
    # DRO distance/probability objects are sliced to the same active set so the
    # objective remains dimensionally consistent.
    active_winds = build_ccg_subset_wind(data.winds, selected_scenarios, data.full_scenario_probability)
    active_probability = active_nominal_probability(data.dro, selected_scenarios)
    active_distance = active_wasserstein_distance(data.dro, selected_scenarios)
    model = build_ccg_extensive_model(
        data,
        active_winds,
        length(selected_scenarios),
        data.full_scenario_probability;
        nominal_probability = active_probability,
        dro_radius = data.dro.enabled ? data.dro.radius : 0.0,
        dro_distance_matrix = active_distance,
        use_dro_objective = data.dro.enabled,
    )
    optimize!(model)
    assert_is_solved_and_feasible(model)
    return model
end

function build_ccg_extensive_model(
    data,
    winds_subset::wind,
    NS_active::Int64,
    scenarios_prob::Float64;
    nominal_probability::Vector{Float64} = fill(1.0 / NS_active, NS_active),
    dro_radius::Float64 = 0.0,
    dro_distance_matrix::Matrix{Float64} = zeros(Float64, NS_active, NS_active),
    use_dro_objective::Bool = false,
)
    # This model is intentionally assembled from the same constraint builders used
    # by Benders. Keeping the algebra shared makes Benders-vs-CCG comparisons about
    # algorithm strategy rather than hidden formulation differences.
    gsdf = calculate_gsdf(data.config_param, data.NL, data.units, data.lines, data.loads, data.NG, data.NB, data.ND)
    refcost, eachslope = linearizationfuelcurve(data.units, data.NG)
    onoffinit = calculate_initial_unit_status(data.units, data.NG)
    contingency_size = define_contingency_size(data.units, data.NG)

    model = Model(Gurobi.Optimizer)
    set_silent(model)
    set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "CCG_MASTER_MIP_GAP", "1e-4")))
    set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "CCG_NUMERIC_FOCUS", "1")))
    set_optimizer_attribute(model, "Threads", ccg_optimizer_threads("CCG_MASTER_THREADS", 0))

    define_decision_variables!(model, data.NT, data.NG, data.ND, data.NC, data.ND2, NS_active, data.NW, data.config_param)
    if use_dro_objective
        set_dro_ccg_master_objective!(model, data, NS_active, nominal_probability, dro_radius, dro_distance_matrix)
    else
        set_objective!(model, data.NT, data.NG, data.ND, data.NW, NS_active, data.units, data.config_param, scenarios_prob, refcost, eachslope)
    end
    apply_scuc_constraints!(
        model,
        data.NT,
        data.NB,
        data.NL,
        data.NG,
        data.ND,
        data.NC,
        data.ND2,
        NS_active,
        data.NW,
        data.units,
        data.loads,
        winds_subset,
        data.lines,
        data.DataCentras,
        data.psses,
        data.config_param,
        onoffinit,
        gsdf,
        contingency_size,
    )
    return model
end

function evaluate_ccg_recourse_pool(data, first_stage)
    # Recourse evaluations are scenario-independent after first-stage commitment is
    # fixed, so they can be parallelized safely. Solver thread counts should be
    # kept small when Julia-level parallelism is enabled.
    if !ccg_parallel_recourse_enabled() || data.NS == 1
        results = OrderedDict{Int64, Any}()
        for scenario_id in 1:data.NS
            results[scenario_id] = solve_ccg_single_scenario_recourse(data, first_stage, scenario_id)
        end
        return results
    end

    result_vector = Vector{Any}(undef, data.NS)
    Threads.@threads for scenario_id in 1:data.NS
        result_vector[scenario_id] = solve_ccg_single_scenario_recourse(data, first_stage, scenario_id)
    end
    return OrderedDict(scenario_id => result_vector[scenario_id] for scenario_id in 1:data.NS)
end

function solve_ccg_single_scenario_recourse(data, first_stage, scenario_id::Int64)
    # Each recourse model receives a one-scenario wind object and fixed first-stage
    # binaries. Its objective is used by separation to identify scenarios that the
    # current active master has not yet internalized.
    scenario_winds = build_single_scenario_wind(data.winds, scenario_id, data.full_scenario_probability)
    model = build_ccg_recourse_model(data, scenario_winds, 1.0)
    fix_first_stage_commitment!(model, first_stage)
    optimize!(model)
    assert_is_solved_and_feasible(model)
    return (recourse_cost = objective_value(model), objective_bound = objective_bound(model), status = termination_status(model))
end

function build_ccg_recourse_model(data, scenario_winds::wind, scenarios_prob::Float64)
    gsdf = calculate_gsdf(data.config_param, data.NL, data.units, data.lines, data.loads, data.NG, data.NB, data.ND)
    onoffinit = calculate_initial_unit_status(data.units, data.NG)
    contingency_size = define_contingency_size(data.units, data.NG)

    model = Model(Gurobi.Optimizer)
    set_silent(model)
    set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "CCG_RECOURSE_MIP_GAP", "1e-4")))
    set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "CCG_NUMERIC_FOCUS", "1")))
    set_optimizer_attribute(model, "Threads", ccg_optimizer_threads("CCG_RECOURSE_THREADS", ccg_parallel_recourse_enabled() ? 1 : 0))

    define_decision_variables!(model, data.NT, data.NG, data.ND, data.NC, data.ND2, Int64(1), data.NW, data.config_param)
    set_ccg_recourse_objective!(model, data, Int64(1), scenarios_prob)
    add_curtailment_constraints!(model, data.NT, data.ND, data.NW, Int64(1), data.loads, scenario_winds)
    add_generator_power_constraints!(model, data.NT, data.NG, Int64(1), data.units)
    add_reserve_constraints!(model, data.NT, data.NG, data.NC, Int64(1), data.units, data.loads, scenario_winds, data.config_param)
    add_power_balance_constraints!(
        model,
        data.NT,
        data.NG,
        data.ND,
        data.NC,
        data.NW,
        Int64(1),
        data.loads,
        scenario_winds,
        data.config_param,
        data.ND2,
    )
    add_ramp_constraints!(model, data.NT, data.NG, Int64(1), data.units, onoffinit)
    add_pwl_constraints!(model, data.NT, data.NG, Int64(1), data.units)
    add_transmission_constraints!(
        model,
        data.NT,
        data.NG,
        data.ND,
        data.NC,
        data.NW,
        data.NL,
        Int64(1),
        data.units,
        data.loads,
        scenario_winds,
        data.lines,
        data.psses,
        gsdf,
        data.config_param,
        data.ND2,
        data.DataCentras,
    )
    add_storage_constraints!(model, data.NT, data.NC, Int64(1), data.config_param, data.psses)
    add_datacentra_constraints!(model, data.NT, Int64(1), data.config_param, data.ND2, data.DataCentras)
    add_frequency_constraints!(
        model,
        data.NT,
        data.NG,
        data.NC,
        Int64(1),
        data.units,
        data.psses,
        data.config_param,
        contingency_size;
        winds = scenario_winds,
    )
    return model
end

function set_ccg_recourse_objective!(model::Model, data, NS::Int64, scenarios_prob::Float64)
    c0 = data.config_param.is_CoalPrice
    load_curtailment_penalty = data.config_param.is_LoadsCuttingCoefficient * 1e10
    wind_curtailment_penalty = data.config_param.is_WindsCuttingCoefficient * 1e0
    reserve_cost_positive = 2 * c0
    reserve_cost_negative = 2 * c0
    refcost, eachslope = linearizationfuelcurve(data.units, data.NG)

    x = model[:x]
    pgk = model[:pgₖ]
    sr_pos = model[:sr⁺]
    sr_neg = model[:sr⁻]
    delta_pd = model[:Δpd]
    delta_pw = model[:Δpw]

    @objective(
        model,
        Min,
        scenarios_prob *
        c0 *
        (
            sum(sum(sum(sum(pgk[i + (s - 1) * data.NG, t, :] .* eachslope[:, i] for t in 1:data.NT)) for s in 1:NS) for i in 1:data.NG) +
            sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:data.NT)) for s in 1:NS) +
            sum(
                sum(
                    sum(
                        reserve_cost_positive * sr_pos[i + (s - 1) * data.NG, t] + reserve_cost_negative * sr_neg[i + (s - 1) * data.NG, t] for
                        i in 1:data.NG
                    ) for t in 1:data.NT
                ) for s in 1:NS
            )
        ) +
        scenarios_prob *
        load_curtailment_penalty *
        sum(sum(sum(delta_pd[(1 + (s - 1) * data.ND):(s * data.ND), t]) for t in 1:data.NT) for s in 1:NS) +
        scenarios_prob * wind_curtailment_penalty * sum(sum(sum(delta_pw[(1 + (s - 1) * data.NW):(s * data.NW), t]) for t in 1:data.NT) for s in 1:NS)
    )
    return model
end

function extract_first_stage_solution(model::Model)
    x = value.(model[:x])
    u = value.(model[:u])
    v = value.(model[:v])
    su = value.(model[:su₀])
    sd = value.(model[:sd₀])
    return (x = x, u = u, v = v, cost = sum(su) + sum(sd))
end

function fix_first_stage_commitment!(model::Model, first_stage)
    fix.(model[:x], first_stage.x; force = true)
    fix.(model[:u], first_stage.u; force = true)
    fix.(model[:v], first_stage.v; force = true)
    return model
end

function print_ccg_iteration(iteration, active_count, lower_bound, upper_bound, gap, scenarios_to_add)
    println(
        rpad(iteration, 8),
        rpad(active_count, 9),
        rpad(@sprintf("%.6g", lower_bound), 16),
        rpad(@sprintf("%.6g", upper_bound), 15),
        rpad(@sprintf("%.6g", gap), 10),
        scenarios_to_add,
    )
    return nothing
end
