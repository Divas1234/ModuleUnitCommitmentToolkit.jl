"""
Benchmark extensive-form SCUC solver.

This module builds one full scenario model and solves it directly. It is used as
the reference UC baseline when comparing decomposition methods:
- Benders: first-stage master plus scenario subproblems;
- CCG: active-scenario master plus separation;
- Benchmark UC: all scenarios in a single extensive-form model.

The formulation reuses the same data loader and constraint builders as CCG, so
differences in reports reflect algorithm strategy rather than algebra drift.
"""

function benchmark_uc_use_dro()
    return ccg_env_bool("BENCHMARK_UC_USE_DRO", ccg_dro_enabled())
end

function solve_benchmark_uc(; scenario_limit::Int64 = 20)
    data = load_ccg_data(scenario_limit)
    full_scenarios = collect(1:data.NS)
    active_winds = build_ccg_subset_wind(data.winds, full_scenarios, data.full_scenario_probability)
    use_dro = benchmark_uc_use_dro()
    model = build_ccg_extensive_model(
        data,
        active_winds,
        data.NS,
        data.full_scenario_probability;
        nominal_probability = data.dro.nominal_probability,
        dro_radius = use_dro && data.dro.enabled ? data.dro.radius : 0.0,
        dro_distance_matrix = data.dro.distance_matrix,
        use_dro_objective = use_dro && data.dro.enabled,
    )
    optimize!(model)
    assert_is_solved_and_feasible(model)
    cost_summary = export_solved_uc_model_results(
        model,
        data;
        output_dir = uc_scheduling_output_dir("benchmark_uc"),
        winds = active_winds,
        NS = data.NS,
        scenarios_prob = data.full_scenario_probability,
        file_prefix = uc_schedule_file_prefix("benchmark_uc", data.NS),
    )
    objective = objective_value(model)
    best_bound = objective_bound(model)
    gap = relative_gap(model)
    return (
        status = string(termination_status(model)),
        model = model,
        data = data,
        history = [(
            iteration = 1,
            active_scenarios = data.NS,
            lower_bound = best_bound,
            upper_bound = objective,
            gap = gap,
            added_scenarios = Int64[],
            memory_mb = process_memory_mb(),
        ),],
        active_scenarios = full_scenarios,
        upper_bound = objective,
        lower_bound = best_bound,
        gap = gap,
        dro_enabled = use_dro && data.dro.enabled,
        cost_summary = cost_summary,
    )
end

using PowerSystems

function solve_benchmark_uc_powersystems(
    sys::System,
    case_dir::String = "";
    scenario_limit::Int64 = 20,
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    data = load_ccg_data(
        scenario_limit;
        use_powersystems = true,
        sys = sys,
        case_dir = case_dir,
        data_center_buses = data_center_buses,
        data_center_pmax = data_center_pmax,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
    )
    full_scenarios = collect(1:data.NS)
    active_winds = build_ccg_subset_wind(data.winds, full_scenarios, data.full_scenario_probability)
    use_dro = benchmark_uc_use_dro()
    model = build_ccg_extensive_model(
        data,
        active_winds,
        data.NS,
        data.full_scenario_probability;
        nominal_probability = data.dro.nominal_probability,
        dro_radius = use_dro && data.dro.enabled ? data.dro.radius : 0.0,
        dro_distance_matrix = data.dro.distance_matrix,
        use_dro_objective = use_dro && data.dro.enabled,
    )
    optimize!(model)
    assert_is_solved_and_feasible(model)
    cost_summary = export_solved_uc_model_results(
        model,
        data;
        output_dir = uc_scheduling_output_dir("benchmark_uc"),
        winds = active_winds,
        NS = data.NS,
        scenarios_prob = data.full_scenario_probability,
        file_prefix = uc_schedule_file_prefix("benchmark_uc", data.NS),
    )
    objective = objective_value(model)
    best_bound = objective_bound(model)
    gap = relative_gap(model)
    return (
        status = string(termination_status(model)),
        model = model,
        data = data,
        history = [(
            iteration = 1,
            active_scenarios = data.NS,
            lower_bound = best_bound,
            upper_bound = objective,
            gap = gap,
            added_scenarios = Int64[],
            memory_mb = process_memory_mb(),
        ),],
        active_scenarios = full_scenarios,
        upper_bound = objective,
        lower_bound = best_bound,
        gap = gap,
        dro_enabled = use_dro && data.dro.enabled,
        cost_summary = cost_summary,
    )
end

"""
    solve_benchmark_uc_powersystems(case_name; case_category, ...)

Run the extensive-form benchmark directly from a `PowerSystemCaseBuilder` case.
Frequency parameters and data-center specifications use the same format as
`load_native_powersystems_case`.
"""
function solve_benchmark_uc_powersystems(
    case_name::AbstractString;
    case_category = MatpowerTestSystems,
    scenario_limit::Int64 = 20,
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    data = load_ccg_data(
        scenario_limit;
        use_powersystems = true,
        case_name = case_name,
        case_category = case_category,
        data_center_buses = data_center_buses,
        data_center_pmax = data_center_pmax,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
    )
    full_scenarios = collect(1:data.NS)
    active_winds = build_ccg_subset_wind(data.winds, full_scenarios, data.full_scenario_probability)
    use_dro = benchmark_uc_use_dro()
    model = build_ccg_extensive_model(
        data,
        active_winds,
        data.NS,
        data.full_scenario_probability;
        nominal_probability = data.dro.nominal_probability,
        dro_radius = use_dro && data.dro.enabled ? data.dro.radius : 0.0,
        dro_distance_matrix = data.dro.distance_matrix,
        use_dro_objective = use_dro && data.dro.enabled,
    )
    optimize!(model)
    assert_is_solved_and_feasible(model)
    cost_summary = export_solved_uc_model_results(
        model,
        data;
        output_dir = uc_scheduling_output_dir("benchmark_uc"),
        winds = active_winds,
        NS = data.NS,
        scenarios_prob = data.full_scenario_probability,
        file_prefix = uc_schedule_file_prefix("benchmark_uc", data.NS),
    )
    objective = objective_value(model)
    best_bound = objective_bound(model)
    gap = relative_gap(model)
    return (
        status = string(termination_status(model)),
        model = model,
        data = data,
        history = [(
            iteration = 1,
            active_scenarios = data.NS,
            lower_bound = best_bound,
            upper_bound = objective,
            gap = gap,
            added_scenarios = Int64[],
            memory_mb = process_memory_mb(),
        ),],
        active_scenarios = full_scenarios,
        upper_bound = objective,
        lower_bound = best_bound,
        gap = gap,
        dro_enabled = use_dro && data.dro.enabled,
        cost_summary = cost_summary,
    )
end
