# Benders decomposition framework for stochastic SCUC.
#
# The master decides first-stage unit commitment and startup/shutdown variables.
# Scenario subproblems evaluate recourse dispatch, curtailment, network, storage,
# and auxiliary constraints under fixed commitment. Violated recourse estimates
# are returned as feasibility, optimality, Jensen, or logic-dominance cuts.
include("models/construct_models.jl")
include("cuts/construct_cuts.jl")

using Printf
using DataStructures

"""
`multiple_bender_decomposition_scuc(...)`

Execute the multi-cut Benders decomposition algorithm for two-stage stochastic SCUC.

The implementation prioritizes numerical robustness over aggressive cut volume:
it filters violated scenario cuts, supports conservative rollback when bounds
become inconsistent, and adds no-good or storage-logic cuts only when they guard
against cycling or dominated binary storage states.

# Arguments
- `scuc_masterproblem::Model`, `scuc_subproblem::Model`: JuMP models for the master and base subproblems.
- `master_model_struct::SCUC_Model`: Data structure associated with the master problem.
- `batch_scuc_subproblem_dic::OrderedDict`: Dictionary of scenario-specific subproblems.
- `winds::wind`: Stochastic wind scenario data.
- `config_param::config`: Configuration parameters for the algorithm.
- `NG::Int64`: Number of generators.
- `NT::Int64`: Number of time periods.
- `NW::Int64`: Number of wind units.
- `ND::Int64`: Number of loads/demand nodes.
- `NL::Int64`: Number of transmission lines.
"""

function multiple_bender_decomposition_scuc(
    scuc_masterproblem::Model,
    scuc_subproblem::Model,
    master_model_struct::SCUC_Model,
    batch_scuc_subproblem_dic::OrderedDict{Int64, SCUC_Model},
    winds::wind,
    config_param::config,
    NG::Int64,
    NT::Int64,
    NW::Int64,
    ND::Int64,
    NL::Int64,
    ;
    jensen_subproblem_struct = nothing,
)

    # Algorithm tolerances. `ABSOLUTE_OPTIMIZATION_GAP` defines convergence;
    # `NUMERICAL_TOLERANCE` only protects comparisons from solver noise.
    MAXIMUM_ITERATIONS = parse(Int64, get(ENV, "BENDERS_MAX_ITERATIONS", "10000"))
    ABSOLUTE_OPTIMIZATION_GAP = 1e-3
    NUMERICAL_TOLERANCE = 1e-6

    # Initialize bounds
    best_upper_bound = Inf
    best_lower_bound = -Inf
    best_incumbent = nothing
    last_added_cut_refs = ConstraintRef[]
    last_ret_dic = nothing
    last_iter_value = nothing
    final_ret_dic = nothing
    history = NamedTuple[]
    termination_reason = "maximum_iterations"
    NS = Int64(winds.scenarios_nums)
    scenarios_prob = 1.0 / winds.scenarios_nums

    @assert !is_mixed_integer_problem(scuc_subproblem)
    println("Starting (Strengthen) Benders decomposition algorithm")
    println("iteration start ...\n")
    println("====================================================")
    println("ITER \t LOWER_bound \t    UPPER_bound   \t GAP")
    println("----------------------------------------------------")

    for iteration in 1:MAXIMUM_ITERATIONS
        optimize!(scuc_masterproblem)

        assert_is_solved_and_feasible(scuc_masterproblem)

        # The master objective is a lower bound because recourse is represented
        # by accumulated cuts rather than the complete scenario response.
        lower_bound = objective_value(scuc_masterproblem)

        # Extract solution from master problem
        x⁽⁰⁾ = value.(scuc_masterproblem[:x])
        u⁽⁰⁾ = value.(scuc_masterproblem[:u])
        v⁽⁰⁾ = value.(scuc_masterproblem[:v])
        storage_binary_values = get_master_storage_binary_values(scuc_masterproblem)
        iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

        # Evaluate recourse under the incumbent commitment. Multi-cut mode solves
        # every scenario separately so each scenario can generate its own theta cut.
        ret_dic = if (config_param.is_ConsiderMultiCUTs == 1)
            batch_solve_subproblem_with_feasibility_cut(
                batch_scuc_subproblem_dic,
                x⁽⁰⁾,
                u⁽⁰⁾,
                v⁽⁰⁾,
                NG,
                NT,
                NS;
                storage_binary_values = storage_binary_values,
            )
        else
            batch_solve_subproblem_with_feasibility_cut(
                batch_scuc_subproblem_dic,
                x⁽⁰⁾,
                u⁽⁰⁾,
                v⁽⁰⁾,
                NG,
                NT;
                storage_binary_values = storage_binary_values,
            )
        end
        final_ret_dic = ret_dic

        # A mismatch here usually means scenario generation or model construction
        # changed without rebuilding the batch dictionary.
        batch_subproblem_nummber = length(ret_dic)
        if (
            if (config_param.is_ConsiderMultiCUTs == 1)
                batch_subproblem_nummber == NS
            else
                batch_subproblem_nummber == Int64(1)
            end
        ) == false
            println("Error: The number of batch_subproblems does not match the expected number.")
            termination_reason = "subproblem_count_mismatch"
            return (
                status = termination_reason,
                model = scuc_masterproblem,
                history = history,
                subproblem_results = final_ret_dic,
                subproblem_models = batch_scuc_subproblem_dic,
                upper_bound = best_upper_bound,
                lower_bound = best_lower_bound,
                gap = Inf,
                iterations = iteration,
                incumbent = best_incumbent,
            )
        end

        previous_best_upper_bound = best_upper_bound
        previous_best_lower_bound = best_lower_bound
        best_upper_bound, best_lower_bound, current_upper_bound, all_subproblems_feasibility_flag =
            get_upper_lower_bounds(scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound)
        if all_subproblems_feasibility_flag &&
           current_upper_bound !== missing &&
           current_upper_bound < previous_best_upper_bound - NUMERICAL_TOLERANCE
            best_incumbent =
                (x = copy(x⁽⁰⁾), u = copy(u⁽⁰⁾), v = copy(v⁽⁰⁾), storage = storage_binary_values, θ = Dict(s => ret.θ for (s, ret) in ret_dic))
        end
        if !all_subproblems_feasibility_flag
            feasible_count = count(ret -> ret.is_feasible, values(ret_dic))
            println(
                "ITER ",
                iteration,
                ": lower_bound=",
                lower_bound,
                ", feasible_subproblems=",
                feasible_count,
                "/",
                length(ret_dic),
                "; adding feasibility cuts",
            )
        end
        gap = if isfinite(best_upper_bound)
            abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + NUMERICAL_TOLERANCE)
        else
            Inf
        end
        push!(
            history,
            (
                iteration = iteration,
                lower_bound = best_lower_bound,
                upper_bound = best_upper_bound,
                current_upper_bound = current_upper_bound,
                gap = gap,
                feasible_subproblems = count(ret -> ret.is_feasible, values(ret_dic)),
                total_subproblems = length(ret_dic),
                added_cuts = 0,
                added_logic_cuts = 0,
                memory_mb = process_memory_mb(),
            ),
        )
        if all_subproblems_feasibility_flag && best_lower_bound > best_upper_bound + NUMERICAL_TOLERANCE
            # Dual cuts can become numerically unsafe when a MIP incumbent changes
            # sharply. Roll back only the most recent cut batch and replace it with
            # conservative integer cuts to preserve progress without poisoning the
            # master bound sequence.
            println("WARNING: Benders lower bound exceeded upper bound at iteration ", iteration)
            println("  LOWER_bound = ", best_lower_bound)
            println("  UPPER_bound = ", best_upper_bound)
            if isempty(last_added_cut_refs) || last_ret_dic === nothing || last_iter_value === nothing
                println("  No previous cut batch is available for rollback; stopping diagnostic run.")
                termination_reason = "bound_inconsistency"
                break
            end
            rollback_cut_batch!(scuc_masterproblem, last_added_cut_refs)
            add_conservative_integer_optimality_cuts!(scuc_masterproblem, last_ret_dic, last_iter_value)
            empty!(last_added_cut_refs)
            last_ret_dic = nothing
            last_iter_value = nothing
            best_lower_bound = previous_best_lower_bound
            println("  Rolled back the last dual cut batch and added conservative integer cuts.")
            continue
        end

        # Check for convergence
        if all_subproblems_feasibility_flag &&
           check_Bender_convergence(
            best_upper_bound,
            best_lower_bound,
            current_upper_bound,
            iteration,
            ABSOLUTE_OPTIMIZATION_GAP,
            NUMERICAL_TOLERANCE,
        ) == 1
            termination_reason = "converged"
            break
        end

        if config_param.is_ConsiderMultiCUTs == 1
            # Candidate generation separates cut discovery from cut admission. This
            # keeps cut caps, violation tolerances, and parallel evaluation localized
            # in the cut library instead of spreading policy through the loop.
            candidate_cuts = collect_scenario_cut_candidates(
                scuc_masterproblem,
                ret_dic,
                value.(scuc_masterproblem[:θ]),
                NG,
                NT,
                NW,
                ND,
                NL;
                incumbent = best_incumbent,
            )
            add_jensen_cut_if_violated!(scuc_masterproblem, jensen_subproblem_struct, iter_value, NG, NT)
            added_cuts, added_cut_refs = add_selected_scenario_optimality_cuts!(scuc_masterproblem, candidate_cuts)
            logic_cut_refs = add_storage_logic_based_dominance_cuts!(scuc_masterproblem, ret_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
            history[end] = merge(history[end], (added_cuts = added_cuts, added_logic_cuts = length(logic_cut_refs)))
            append!(added_cut_refs, logic_cut_refs)
            last_added_cut_refs = added_cut_refs
            last_ret_dic = added_cuts > 0 ? ret_dic : nothing
            last_iter_value = added_cuts > 0 ? iter_value : nothing
            if !all_subproblems_feasibility_flag
                add_no_good_cut!(scuc_masterproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
            elseif added_cuts == 0 && isempty(logic_cut_refs)
                println("No violated Benders cuts found at iteration ", iteration, "; stopping to avoid cycling.")
                termination_reason = "no_violated_cuts"
                break
            end
        else
            # Add appropriate Bender's cut based on subproblem feasibility
            for (s, ret) in ret_dic
                # Single-cut mode: use reduced-cost-based standard optimality/feasibility cuts
                if ret.is_feasible == true
                    scuc_masterproblem, _ = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
                else
                    add_no_good_cut!(scuc_masterproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
                end
            end
        end
    end
    final_gap = if isfinite(best_upper_bound)
        abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + NUMERICAL_TOLERANCE)
    else
        Inf
    end
    return (
        status = termination_reason,
        model = scuc_masterproblem,
        history = history,
        subproblem_results = final_ret_dic,
        subproblem_models = batch_scuc_subproblem_dic,
        upper_bound = best_upper_bound,
        lower_bound = best_lower_bound,
        gap = final_gap,
        iterations = length(history),
        incumbent = best_incumbent,
    )
end

function process_memory_mb()
    try
        rss_kb = parse(Float64, strip(read(`ps -o rss= -p $(getpid())`, String)))
        return rss_kb / 1024.0
    catch
        return Base.gc_live_bytes() / 1024.0^2
    end
end

function add_storage_logic_based_dominance_cuts!(
    model::Model,
    ret_dic::OrderedDict{Int64, Any},
    x_value,
    u_value,
    v_value;
    binary_tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_LOGIC_BINARY_TOL", "0.5")),
    power_tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_LOGIC_POWER_TOL", "1e-7")),
)
    # These cuts remove storage mode patterns that were active in binaries but did
    # not materially dispatch energy. They are dominance cuts, not feasibility
    # requirements, so they are bounded per iteration and can be disabled by ENV.
    if get(ENV, "BENDERS_ENABLE_STORAGE_LOGIC_CUTS", "1") == "0" || !has_master_storage_binary_variables(model)
        return ConstraintRef[]
    end
    max_cuts = parse(Int64, get(ENV, "BENDERS_MAX_STORAGE_LOGIC_CUTS_PER_ITERATION", "5"))
    max_cuts <= 0 && return ConstraintRef[]

    cut_refs = ConstraintRef[]
    for (s, ret) in ret_dic
        length(cut_refs) >= max_cuts && break
        if ret.is_feasible == true && has_storage_link_values(ret) && haskey(ret, :storage_dispatch)
            unused_charge =
                find_unused_active_storage_modes(ret.storage_values.charge, ret.storage_dispatch.charge_power, binary_tolerance, power_tolerance)
            unused_discharge = find_unused_active_storage_modes(
                ret.storage_values.discharge,
                ret.storage_dispatch.discharge_power,
                binary_tolerance,
                power_tolerance,
            )
            if !isempty(unused_charge) || !isempty(unused_discharge)
                push!(
                    cut_refs,
                    add_storage_mode_dominance_cut!(
                        model,
                        s,
                        ret,
                        x_value,
                        u_value,
                        v_value,
                        unused_charge,
                        unused_discharge;
                        tolerance = binary_tolerance,
                    ),
                )
            end
        end
    end
    if get(ENV, "BENDERS_VERBOSE_CUTS", "0") == "1" && !isempty(cut_refs)
        println("Added storage logic-based dominance cuts: ", length(cut_refs))
    end
    return cut_refs
end

function find_unused_active_storage_modes(status_values, dispatch_values, binary_tolerance::Float64, power_tolerance::Float64)
    unused = CartesianIndex{2}[]
    for idx in CartesianIndices(status_values)
        if status_values[idx] >= binary_tolerance && abs(dispatch_values[idx]) <= power_tolerance
            push!(unused, idx)
        end
    end
    return unused
end

function add_storage_mode_dominance_cut!(
    model::Model,
    scenario_id::Int64,
    ret,
    x_value,
    u_value,
    v_value,
    unused_charge,
    unused_discharge;
    tolerance::Float64 = 0.5,
)
    x = model[:x]
    u = model[:u]
    v = model[:v]
    charge = get_master_storage_variable_slice(model, :κ⁺, scenario_id, size(ret.storage_values.charge, 1))
    discharge = get_master_storage_variable_slice(model, :κ⁻, scenario_id, size(ret.storage_values.discharge, 1))
    start = get_master_storage_variable_slice(model, :α, scenario_id, size(ret.storage_values.start, 1))
    stop = get_master_storage_variable_slice(model, :β, scenario_id, size(ret.storage_values.stop, 1))

    mismatch_expr =
        sum((x_value[i] >= tolerance) ? (1 - x[i]) : x[i] for i in eachindex(x)) +
        sum((u_value[i] >= tolerance) ? (1 - u[i]) : u[i] for i in eachindex(u)) +
        sum((v_value[i] >= tolerance) ? (1 - v[i]) : v[i] for i in eachindex(v))
    mismatch_expr += storage_mismatch_expression(charge, ret.storage_values.charge, Set(unused_charge), tolerance)
    mismatch_expr += storage_mismatch_expression(discharge, ret.storage_values.discharge, Set(unused_discharge), tolerance)
    mismatch_expr += storage_mismatch_expression(start, ret.storage_values.start, Set{CartesianIndex{2}}(), tolerance)
    mismatch_expr += storage_mismatch_expression(stop, ret.storage_values.stop, Set{CartesianIndex{2}}(), tolerance)

    prune_expr = sum(1 - charge[idx] for idx in unused_charge) + sum(1 - discharge[idx] for idx in unused_discharge)
    return @constraint(model, mismatch_expr + prune_expr >= 1)
end

function storage_mismatch_expression(vars, values, excluded_indices::Set{CartesianIndex{2}}, tolerance::Float64)
    vars === nothing && return AffExpr(0.0)
    return sum(if (idx in excluded_indices)
        0.0
    else
        ((values[idx] >= tolerance) ? (1 - vars[idx]) : vars[idx])
    end for idx in CartesianIndices(values))
end

function collect_scenario_cut_candidates(
    model::Model,
    ret_dic::OrderedDict{Int64, Any},
    theta_values,
    NG::Int64,
    NT::Int64,
    NW::Int64,
    ND::Int64,
    NL::Int64;
    tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_CUT_VIOLATION_TOL", "1e-5")),
    incumbent = nothing,
)
    candidate_cuts = Tuple{Float64, Int64, AffExpr}[]
    cut_mode = get(ENV, "BENDERS_OPTIMALITY_CUT_MODE", "dual_safe")
    for s in keys(ret_dic)
        ret = ret_dic[s]
        if ret.is_feasible == true
            cut_expr = if cut_mode == "dual"
                get_reduced_cost_optimality_cut_expression(model, ret, nothing; scenario_id = s)
            elseif cut_mode == "integer"
                get_binary_integer_optimality_cut_expression(model, ret, nothing; scenario_id = s)
            elseif cut_mode == "coefficient"
                if isempty(ret.dual_coeffs)
                    get_binary_integer_optimality_cut_expression(model, ret, nothing; scenario_id = s)
                else
                    _, expr = get_benders_cumulative_multicuts_expression(model, ret.dual_coeffs, NG, NT, NW, ND, NL)
                    expr
                end
            elseif cut_mode == "dual_safe"
                dual_cut_at_incumbent = if incumbent === nothing
                    -Inf
                else
                    evaluate_reduced_cost_optimality_cut(ret, incumbent)
                end
                if incumbent !== nothing && dual_cut_at_incumbent > incumbent.θ[s] + tolerance
                    get_binary_integer_optimality_cut_expression(model, ret, nothing; scenario_id = s)
                else
                    get_reduced_cost_optimality_cut_expression(model, ret, nothing; scenario_id = s)
                end
            else
                error("Unsupported BENDERS_OPTIMALITY_CUT_MODE=$(cut_mode). Use 'integer', 'dual', 'dual_safe', or 'coefficient'.")
            end
            violation = Float64(value(cut_expr) - theta_values[s])
            if violation > tolerance
                push!(candidate_cuts, (violation, s, cut_expr))
            end
        end
    end

    sort!(candidate_cuts; by = cut -> cut[1], rev = true)
    max_cuts = max(0, parse(Int64, get(ENV, "BENDERS_MAX_SCENARIO_CUTS_PER_ITERATION", string(length(candidate_cuts)))))
    if max_cuts < length(candidate_cuts)
        resize!(candidate_cuts, max_cuts)
    end
    return candidate_cuts
end

function should_build_cut_candidates_in_parallel(candidate_count::Int64)
    return candidate_count > 1 && Threads.nthreads() > 1 && get(ENV, "BENDERS_PARALLEL_CUT_CANDIDATES", "1") != "0"
end

function add_selected_scenario_optimality_cuts!(model::Model, selected_candidates)
    added = 0
    added_cut_refs = ConstraintRef[]
    for (_, s, cut_expr) in selected_candidates
        cut_ref = @constraint(model, model[:θ][s] >= cut_expr)
        push!(added_cut_refs, cut_ref)
        added += 1
    end
    if get(ENV, "BENDERS_VERBOSE_CUTS", "0") == "1"
        println("Added scenario optimality cuts: ", added)
    end
    return added, added_cut_refs
end

function rollback_cut_batch!(model::Model, cut_refs::Vector{ConstraintRef})
    for cut_ref in cut_refs
        if is_valid(model, cut_ref)
            delete(model, cut_ref)
        end
    end
    return nothing
end

function add_conservative_integer_optimality_cuts!(model::Model, ret_dic::OrderedDict{Int64, Any}, iter_value)
    added = 0
    for (s, ret) in ret_dic
        if ret.is_feasible == true
            cut_expr = get_binary_integer_optimality_cut_expression(model, ret, iter_value; scenario_id = s)
            @constraint(model, model[:θ][s] >= cut_expr)
            added += 1
        end
    end
    return added
end

function add_violated_scenario_optimality_cuts!(
    model::Model,
    candidate_cuts;
    tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_CUT_VIOLATION_TOL", "1e-5")),
)
    if isempty(candidate_cuts)
        return 0
    end
    sort!(candidate_cuts; by = cut -> cut[1], rev = true)
    max_cuts = parse(Int64, get(ENV, "BENDERS_MAX_SCENARIO_CUTS_PER_ITERATION", string(length(candidate_cuts))))
    added = 0
    for (violation, s, cut_expr) in candidate_cuts
        if violation <= tolerance || added >= max_cuts
            break
        end
        @constraint(model, model[:θ][s] >= cut_expr)
        added += 1
    end
    return added
end

function add_jensen_cut_if_violated!(
    model::Model,
    jensen_subproblem_struct,
    iter_value,
    NG::Int64,
    NT::Int64;
    tolerance::Float64 = parse(Float64, get(ENV, "BENDERS_JENSEN_CUT_TOL", "1e-5")),
)
    if jensen_subproblem_struct === nothing
        return nothing
    end
    if has_master_storage_binary_variables(model)
        @debug "Skipping Jensen cut because storage binary decisions are carried by the master."
        return nothing
    end
    x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾ = iter_value
    ret = solve_subproblem_with_feasibility_cut(jensen_subproblem_struct, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NG, NT)
    if ret.is_feasible != true
        return nothing
    end
    jensen_cut = get_reduced_cost_optimality_cut_expression(model, ret, iter_value)
    theta_sum = sum(value.(model[:θ]))
    cut_value = value(jensen_cut)
    if cut_value - theta_sum > tolerance
        return @constraint(model, sum(model[:θ]) >= jensen_cut)
    end
    return nothing
end

function get_reduced_cost_optimality_cut_expression(model::Model, ret, iter_value; scenario_id::Int64 = 1)
    if iter_value === nothing
        x⁽⁰⁾ = value.(model[:x])
        u⁽⁰⁾ = value.(model[:u])
        v⁽⁰⁾ = value.(model[:v])
    else
        x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾ = iter_value
    end
    cut_expr =
        @expression(model, ret.θ + sum(ret.ray_x .* (model[:x] - x⁽⁰⁾)) + sum(ret.ray_u .* (model[:u] - u⁽⁰⁾)) + sum(ret.ray_v .* (model[:v] - v⁽⁰⁾)))
    add_storage_reduced_cost_terms!(cut_expr, model, ret, scenario_id)
    return cut_expr
end

function get_binary_integer_optimality_cut_expression(model::Model, ret, iter_value; scenario_id::Int64 = 1, tolerance::Float64 = 0.5)
    if iter_value === nothing
        x⁽⁰⁾ = value.(model[:x])
        u⁽⁰⁾ = value.(model[:u])
        v⁽⁰⁾ = value.(model[:v])
    else
        x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾ = iter_value
    end

    x = model[:x]
    u = model[:u]
    v = model[:v]
    matches_current_solution =
        sum((x⁽⁰⁾[i] >= tolerance) ? x[i] : (1 - x[i]) for i in eachindex(x)) +
        sum((u⁽⁰⁾[i] >= tolerance) ? u[i] : (1 - u[i]) for i in eachindex(u)) +
        sum((v⁽⁰⁾[i] >= tolerance) ? v[i] : (1 - v[i]) for i in eachindex(v))
    binary_count = length(x) + length(u) + length(v)
    storage_matches, storage_binary_count = get_storage_binary_match_expression(model, ret, scenario_id, tolerance)
    matches_current_solution += storage_matches
    binary_count += storage_binary_count
    return @expression(model, ret.θ * (matches_current_solution - binary_count + 1))
end

function evaluate_reduced_cost_optimality_cut(ret, incumbent)
    cut_value =
        ret.θ +
        sum(ret.ray_x .* (incumbent.x .- ret.x⁽⁰⁾)) +
        sum(ret.ray_u .* (incumbent.u .- ret.u⁽⁰⁾)) +
        sum(ret.ray_v .* (incumbent.v .- ret.v⁽⁰⁾))
    if incumbent.storage !== nothing && has_storage_link_values(ret)
        incumbent_storage = select_storage_binary_values_for_subproblem(incumbent.storage, ret.scenario_id, ret.storage_values)
        cut_value += sum(ret.storage_rays.charge .* (incumbent_storage.charge .- ret.storage_values.charge))
        cut_value += sum(ret.storage_rays.discharge .* (incumbent_storage.discharge .- ret.storage_values.discharge))
        cut_value += sum(ret.storage_rays.start .* (incumbent_storage.start .- ret.storage_values.start))
        cut_value += sum(ret.storage_rays.stop .* (incumbent_storage.stop .- ret.storage_values.stop))
    end
    return cut_value
end

function add_no_good_cut!(model::Model, x_value, u_value, v_value; tolerance::Float64 = 0.5)
    x = model[:x]
    u = model[:u]
    v = model[:v]
    return @constraint(
        model,
        sum((x_value[i] >= tolerance) ? (1 - x[i]) : x[i] for i in eachindex(x)) +
        sum((u_value[i] >= tolerance) ? (1 - u[i]) : u[i] for i in eachindex(u)) +
        sum((v_value[i] >= tolerance) ? (1 - v[i]) : v[i] for i in eachindex(v)) >= 1
    )
end

function has_master_storage_binary_variables(model::Model)
    object_dict = JuMP.object_dictionary(model)
    return haskey(object_dict, :κ⁺) && haskey(object_dict, :κ⁻) && haskey(object_dict, :α) && haskey(object_dict, :β) && !isempty(model[:κ⁺])
end

function get_master_storage_binary_values(model::Model)
    if !has_master_storage_binary_variables(model)
        return nothing
    end
    return (charge = value.(model[:κ⁺]), discharge = value.(model[:κ⁻]), start = value.(model[:α]), stop = value.(model[:β]))
end

function has_storage_link_values(storage_values::NamedTuple)
    if haskey(storage_values, :storage_values)
        return storage_values.storage_values !== nothing && has_storage_link_values(storage_values.storage_values)
    elseif haskey(storage_values, :charge)
        return !isempty(storage_values.charge)
    end
    return false
end

function has_storage_link_values(storage_values)
    return storage_values !== nothing
end

function select_storage_binary_values_for_subproblem(storage_values, scenario_id::Int64, subproblem_storage_values)
    storage_values === nothing && return nothing
    rows = size(subproblem_storage_values.charge, 1)
    return slice_storage_binary_values(storage_values, scenario_id, rows)
end

function select_storage_binary_values_for_subproblem(storage_values, scenario_id::Int64, subproblem_model::Model)
    storage_values === nothing && return nothing
    object_dict = JuMP.object_dictionary(subproblem_model)
    if !haskey(object_dict, :κ⁺) || isempty(subproblem_model[:κ⁺])
        return nothing
    end
    rows = size(subproblem_model[:κ⁺], 1)
    return slice_storage_binary_values(storage_values, scenario_id, rows)
end

function slice_storage_binary_values(storage_values, scenario_id::Int64, rows::Int64)
    rows == 0 && return empty_storage_link_values()
    start_idx = size(storage_values.charge, 1) == rows ? 1 : (scenario_id - 1) * rows + 1
    stop_idx = start_idx + rows - 1
    return (
        charge = storage_values.charge[start_idx:stop_idx, :],
        discharge = storage_values.discharge[start_idx:stop_idx, :],
        start = storage_values.start[start_idx:stop_idx, :],
        stop = storage_values.stop[start_idx:stop_idx, :],
    )
end

function empty_storage_link_values()
    return (charge = zeros(0, 0), discharge = zeros(0, 0), start = zeros(0, 0), stop = zeros(0, 0))
end

function get_storage_dispatch_values(model::Model)
    object_dict = JuMP.object_dictionary(model)
    if !haskey(object_dict, :pc⁺) || !haskey(object_dict, :pc⁻) || isempty(model[:pc⁺])
        return (charge_power = zeros(0, 0), discharge_power = zeros(0, 0))
    end
    return (charge_power = value.(model[:pc⁺]), discharge_power = value.(model[:pc⁻]))
end

function get_master_storage_variable_slice(model::Model, symbol::Symbol, scenario_id::Int64, rows::Int64)
    rows == 0 && return nothing
    object_dict = JuMP.object_dictionary(model)
    if !haskey(object_dict, symbol) || isempty(model[symbol])
        return nothing
    end
    vars = model[symbol]
    start_idx = size(vars, 1) == rows ? 1 : (scenario_id - 1) * rows + 1
    stop_idx = start_idx + rows - 1
    return vars[start_idx:stop_idx, :]
end

function add_storage_reduced_cost_terms!(cut_expr, model::Model, ret, scenario_id::Int64)
    has_storage_link_values(ret) || return cut_expr
    charge = get_master_storage_variable_slice(model, :κ⁺, scenario_id, size(ret.storage_values.charge, 1))
    discharge = get_master_storage_variable_slice(model, :κ⁻, scenario_id, size(ret.storage_values.discharge, 1))
    start = get_master_storage_variable_slice(model, :α, scenario_id, size(ret.storage_values.start, 1))
    stop = get_master_storage_variable_slice(model, :β, scenario_id, size(ret.storage_values.stop, 1))
    charge === nothing && return cut_expr
    cut_expr += sum(ret.storage_rays.charge .* (charge .- ret.storage_values.charge))
    cut_expr += sum(ret.storage_rays.discharge .* (discharge .- ret.storage_values.discharge))
    cut_expr += sum(ret.storage_rays.start .* (start .- ret.storage_values.start))
    cut_expr += sum(ret.storage_rays.stop .* (stop .- ret.storage_values.stop))
    return cut_expr
end

function get_storage_binary_match_expression(model::Model, ret, scenario_id::Int64, tolerance::Float64)
    has_storage_link_values(ret) || return (AffExpr(0.0), 0)
    charge = get_master_storage_variable_slice(model, :κ⁺, scenario_id, size(ret.storage_values.charge, 1))
    discharge = get_master_storage_variable_slice(model, :κ⁻, scenario_id, size(ret.storage_values.discharge, 1))
    start = get_master_storage_variable_slice(model, :α, scenario_id, size(ret.storage_values.start, 1))
    stop = get_master_storage_variable_slice(model, :β, scenario_id, size(ret.storage_values.stop, 1))
    charge === nothing && return (AffExpr(0.0), 0)
    matches =
        sum((ret.storage_values.charge[i] >= tolerance) ? charge[i] : (1 - charge[i]) for i in eachindex(charge)) +
        sum(if (ret.storage_values.discharge[i] >= tolerance)
            discharge[i]
        else
            (1 - discharge[i])
        end for i in eachindex(discharge)) +
        sum((ret.storage_values.start[i] >= tolerance) ? start[i] : (1 - start[i]) for i in eachindex(start)) +
        sum((ret.storage_values.stop[i] >= tolerance) ? stop[i] : (1 - stop[i]) for i in eachindex(stop))
    return matches, length(charge) + length(discharge) + length(start) + length(stop)
end

function add_violated_feasibility_cut!(model::Model, cut_expr, cut_value; tolerance::Float64 = 1e-7)
    if cut_value < -tolerance
        return @constraint(model, cut_expr >= 0)
    elseif cut_value > tolerance
        return @constraint(model, cut_expr <= 0)
    else
        @debug "Skipping nearly inactive feasibility cut" cut_value
        return nothing
    end
end

"""
`get_upper_lower_bounds(...)`

Calculates and updates the global upper and lower bounds for the Benders decomposition across all scenarios.

# Returns
- `best_upper_bound`, `best_lower_bound`: Updated global best bounds.
- `current_upper_bound`: The upper bound for the current iteration (missing if any subproblem is infeasible).
- `flag`: A boolean indicating if all subproblems are jointly feasible.
"""

function get_upper_lower_bounds(scuc_masterproblem::Model, ret_dic::OrderedDict{Int64, Any}, best_upper_bound, best_lower_bound, lower_bound)
    # flag = all(s -> s.is_feasible, ret_dic)
    flag = all(ret.is_feasible for ret in values(ret_dic))

    if flag == true
        expected_θ = sum(ret.θ for ret in values(ret_dic))
        theta_value = scuc_masterproblem[:θ]
        recourse_estimate = theta_value isa AbstractArray ? sum(value.(theta_value)) : value(theta_value)
        current_upper_bound = objective_value(scuc_masterproblem) - recourse_estimate + expected_θ
        best_upper_bound = min(best_upper_bound, current_upper_bound)
        best_lower_bound = max(best_lower_bound, lower_bound)
    else
        current_upper_bound = missing
    end

    return best_upper_bound, best_lower_bound, current_upper_bound, flag
end

"""
`check_Bender_convergence(...)`

Evaluates the relative gap between the best upper and lower bounds to determine if the algorithm has converged.
Returns 1 if convergence criteria are successfully met.
"""

function check_Bender_convergence(best_upper_bound, best_lower_bound, current_upper_bound, iteration, ABSOLUTE_OPTIMIZATION_GAP, NUMERICAL_TOLERANCE)
    flag = 0
    # Calculate gap with best bounds
    gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + NUMERICAL_TOLERANCE)

    # Print iteration results
    print_iteration([iteration, best_lower_bound, best_upper_bound, gap])

    # Check convergence
    if gap < ABSOLUTE_OPTIMIZATION_GAP || abs(best_upper_bound - best_lower_bound) < NUMERICAL_TOLERANCE
        println("\n")
        println("====================================================")
        println("Convergence achieved - Optimal solution found")
        println("FINAL UPPER BOUND: ", best_upper_bound)
        println("FINAL LOWER BOUND: ", best_lower_bound)
        println("FINAL GAP:         ", gap)
        println("====================================================")
        flag = 1
    end
    return flag
end

"""
`batch_solve_subproblem_with_feasibility_cut(...)`

Solves a batch of scenario subproblems iteratively with fixed first-stage variables.
Returns a dictionary containing feasibility status, objective values, and duals for each scenario.
"""
function batch_solve_subproblem_with_feasibility_cut(
    batch_scuc_subproblem_dic::OrderedDict,
    x,
    u,
    v,
    NG::Int64,
    NT::Int64,
    NS::Int64 = 1;
    storage_binary_values = nothing,
)
    ret_dic = OrderedDict{Int64, Any}()
    if should_solve_subproblems_in_parallel(NS)
        ret_vec = Vector{Any}(undef, NS)
        Threads.@threads for s in 1:NS
            scenario_storage_values = select_storage_binary_values_for_subproblem(storage_binary_values, s, batch_scuc_subproblem_dic[s].model)
            ret_vec[s] = solve_subproblem_with_feasibility_cut(
                batch_scuc_subproblem_dic[s]::SCUC_Model,
                x,
                u,
                v,
                NG,
                NT;
                scenario_id = s,
                storage_binary_values = scenario_storage_values,
            )
        end
        for s in 1:NS
            ret_dic[s] = ret_vec[s]
        end
    else
        for s in 1:NS
            scenario_storage_values = select_storage_binary_values_for_subproblem(storage_binary_values, s, batch_scuc_subproblem_dic[s].model)
            ret = solve_subproblem_with_feasibility_cut(
                batch_scuc_subproblem_dic[s]::SCUC_Model,
                x,
                u,
                v,
                NG,
                NT;
                scenario_id = s,
                storage_binary_values = scenario_storage_values,
            )
            ret_dic[s] = ret
        end
    end
    return ret_dic
end

function should_solve_subproblems_in_parallel(NS::Int64)
    return NS > 1 && Threads.nthreads() > 1 && get(ENV, "BENDERS_PARALLEL_SUBPROBLEMS", "1") != "0"
end

function should_collect_dual_coefficients()
    return get(ENV, "BENDERS_COLLECT_DUAL_COEFFS", "0") == "1"
end

function should_collect_dual_details()
    return get(ENV, "BENDERS_COLLECT_DUAL_DETAILS", "0") == "1"
end

function maybe_get_dual_coefficients(scuc_subproblem_dic::SCUC_Model, opti_termination_status::Bool, NT::Int64, NG::Int64)
    if !should_collect_dual_coefficients()
        return Dict{Symbol, dual_subprob_expr_coefficient}()
    end
    constraints = scuc_subproblem_dic.reformated_constraints
    res_smaller_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._smaller_than, opti_termination_status, NT, NG)
    res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._equal_to, opti_termination_status, NT, NG)
    res_greater_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._greater_than, opti_termination_status, NT, NG)
    return merge(res_equal_to, res_smaller_than, res_greater_than)
end

function maybe_get_dual_detail_dictionaries(scuc_subproblem_dic::SCUC_Model, opti_termination_status::Bool)
    if !should_collect_dual_details()
        return (smaller = Dict{Symbol, Any}(), greater = Dict{Symbol, Any}(), equal = Dict{Symbol, Any}())
    end
    dual_getter = opti_termination_status ? dual : shadow_price
    return (
        smaller = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._smaller_than),
        greater = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._greater_than),
        equal = Dict(k => dual_getter.(v) for (k, v) in scuc_subproblem_dic.reformated_constraints._equal_to),
    )
end

"""
`solve_subproblem_with_feasibility_cut(...)`

Fixes the first-stage variables for a single scenario subproblem, evaluates it, and extracts the corresponding dual variables (or Farkas duals if infeasible) to form Benders cuts.
"""

function solve_subproblem_with_feasibility_cut(
    scuc_subproblem_dic::SCUC_Model,
    x,
    u,
    v,
    NG::Int64,
    NT::Int64;
    scenario_id::Int64 = 1,
    storage_binary_values = nothing,
)
    scuc_subproblem = scuc_subproblem_dic.model

    # Link first-stage variables explicitly so the duals of these equalities form
    # stable Benders subgradients. Reduced costs of fixed variable bounds are
    # solver-dependent when both bounds are active.
    link_x, link_u, link_v, storage_links = ensure_benders_linking_constraints!(scuc_subproblem)
    set_normalized_rhs.(link_x, x)
    set_normalized_rhs.(link_u, u)
    set_normalized_rhs.(link_v, v)
    storage_values = normalize_storage_link_values(storage_binary_values, storage_links)
    if storage_links !== nothing
        set_normalized_rhs.(storage_links.charge, storage_values.charge)
        set_normalized_rhs.(storage_links.discharge, storage_values.discharge)
        set_normalized_rhs.(storage_links.start, storage_values.start)
        set_normalized_rhs.(storage_links.stop, storage_values.stop)
    end
    # fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
    # fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

    set_optimizer_attribute_if_supported(scuc_subproblem, "InfUnbdInfo", 1)
    set_optimizer_attribute_if_supported(scuc_subproblem, "DualReductions", 0)
    if Threads.nthreads() > 1
        subproblem_threads = parse(Int64, get(ENV, "BENDERS_SUBPROBLEM_SOLVER_THREADS", "1"))
        if subproblem_threads > 0
            set_optimizer_attribute_if_supported(scuc_subproblem, "Threads", subproblem_threads)
        end
    end
    # Optimize subproblem
    optimize!(scuc_subproblem)

    # Check if subproblem is solved and feasible
    opti_termination_status = is_solved_and_feasible(scuc_subproblem; dual = true)

    # constrs_smaller_than = scuc_subproblem_dic.reformated_constraints._smaller_than
    # res_smaller_than = get_dual_constrs_coefficient(
    # 	scuc_subproblem_dic, constrs_smaller_than, opti_termination_status)

    # constrs_equal_to = scuc_subproblem_dic.reformated_constraints._equal_to
    # res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constrs_equal_to, opti_termination_status)

    # constrs_greater_than = scuc_subproblem_dic.reformated_constraints._greater_than
    # res_greater_than = get_dual_constrs_coefficient(
    # 	scuc_subproblem_dic, constrs_greater_than, opti_termination_status)

    final_dual_subproblem_coefficient_results = maybe_get_dual_coefficients(scuc_subproblem_dic, opti_termination_status, NT, NG)
    dual_details = maybe_get_dual_detail_dictionaries(scuc_subproblem_dic, opti_termination_status)

    if opti_termination_status == true
        # Return solution information with scaled duals for numerical stability

        return (
            is_feasible = true,
            θ = objective_value(scuc_subproblem),
            scenario_id = scenario_id,
            x⁽⁰⁾ = copy(x),
            u⁽⁰⁾ = copy(u),
            v⁽⁰⁾ = copy(v),
            ray_x = dual.(link_x),
            ray_u = dual.(link_u),
            ray_v = dual.(link_v),
            storage_values = storage_values,
            storage_rays = get_storage_link_duals(storage_links, true),
            storage_dispatch = get_storage_dispatch_values(scuc_subproblem),

            # NOTE - strong convex duality
            dual_coeffs = final_dual_subproblem_coefficient_results,

            # NOTE - additional dual info
            dual_smaller_than_constr_dic = dual_details.smaller,
            dual_greater_than_constr_dic = dual_details.greater,
            dual_equal_to_constr_dic = dual_details.equal,
        )
    else
        # Get Farkas certificate (dual rays) for infeasibility
        # farkas_dual = MOI.get(scuc_subproblem, MOI.FarkasDual())

        # Scale and process the Farkas certificate
        return (
            is_feasible = false,
            dual_θ = dual_objective_value(scuc_subproblem),
            scenario_id = scenario_id,
            x⁽⁰⁾ = copy(x),
            u⁽⁰⁾ = copy(u),
            v⁽⁰⁾ = copy(v),
            ray_x = shadow_price.(link_x),
            ray_u = shadow_price.(link_u),
            ray_v = shadow_price.(link_v),
            storage_values = storage_values,
            storage_rays = get_storage_link_duals(storage_links, false),
            storage_dispatch = get_storage_dispatch_values(scuc_subproblem),

            # NOTE - farkas_dual process
            dual_coeffs = final_dual_subproblem_coefficient_results,

            # NOTE - additional dual info
            dual_smaller_than_constr_dic = dual_details.smaller,
            dual_greater_than_constr_dic = dual_details.greater,
            dual_equal_to_constr_dic = dual_details.equal,
        )
    end
end

function ensure_benders_linking_constraints!(model::Model)
    object_dict = JuMP.object_dictionary(model)
    if !haskey(object_dict, :benders_link_x)
        x = model[:x]
        u = model[:u]
        v = model[:v]
        @constraint(model, benders_link_x[g = axes(x, 1), t = axes(x, 2)], x[g, t] == 0.0)
        @constraint(model, benders_link_u[g = axes(u, 1), t = axes(u, 2)], u[g, t] == 0.0)
        @constraint(model, benders_link_v[g = axes(v, 1), t = axes(v, 2)], v[g, t] == 0.0)
    end
    if haskey(object_dict, :κ⁺) && !isempty(model[:κ⁺]) && !haskey(JuMP.object_dictionary(model), :benders_link_kappa_charge)
        κ⁺ = model[:κ⁺]
        κ⁻ = model[:κ⁻]
        α = model[:α]
        β = model[:β]
        @constraint(model, benders_link_kappa_charge[i = axes(κ⁺, 1), t = axes(κ⁺, 2)], κ⁺[i, t] == 0.0)
        @constraint(model, benders_link_kappa_discharge[i = axes(κ⁻, 1), t = axes(κ⁻, 2)], κ⁻[i, t] == 0.0)
        @constraint(model, benders_link_storage_start[i = axes(α, 1), t = axes(α, 2)], α[i, t] == 0.0)
        @constraint(model, benders_link_storage_stop[i = axes(β, 1), t = axes(β, 2)], β[i, t] == 0.0)
    end
    storage_links = if haskey(JuMP.object_dictionary(model), :benders_link_kappa_charge)
        (
            charge = model[:benders_link_kappa_charge],
            discharge = model[:benders_link_kappa_discharge],
            start = model[:benders_link_storage_start],
            stop = model[:benders_link_storage_stop],
        )
    else
        nothing
    end
    return model[:benders_link_x], model[:benders_link_u], model[:benders_link_v], storage_links
end

function normalize_storage_link_values(storage_binary_values, storage_links)
    if storage_links === nothing
        return empty_storage_link_values()
    end
    if storage_binary_values === nothing
        return (
            charge = zeros(size(storage_links.charge)),
            discharge = zeros(size(storage_links.discharge)),
            start = zeros(size(storage_links.start)),
            stop = zeros(size(storage_links.stop)),
        )
    end
    return storage_binary_values
end

function get_storage_link_duals(storage_links, opti_termination_status::Bool)
    if storage_links === nothing
        return empty_storage_link_values()
    end
    dual_getter = opti_termination_status ? dual : shadow_price
    return (
        charge = dual_getter.(storage_links.charge),
        discharge = dual_getter.(storage_links.discharge),
        start = dual_getter.(storage_links.start),
        stop = dual_getter.(storage_links.stop),
    )
end

function set_optimizer_attribute_if_supported(model::Model, attribute_name::String, value)
    try
        set_optimizer_attribute(model, attribute_name, value)
    catch err
        @debug "Skipping unsupported optimizer attribute" attribute_name value err
    end
    return nothing
end

"""
`print_iteration(numbers, col_width=15)`

Prints formatted algorithmic progress including iteration count and computed gaps.
"""

function print_iteration(numbers, col_width = 15)
    # f(x) = Printf.@sprintf("%12.4e", x)
    # println(lpad(k, 9), " ", join(f.(args), " "))
    for num in numbers
        print(rpad(@sprintf("%.*g", 6, num), col_width))
    end
    println()
    return nothing
end

"""
`scale_duals(duals; scale_factor=1e3, min_magnitude=1e-10)`

Scales dual values to improve numerical stability in resolving extreme constraint coefficients, explicitly preserving their signs.
"""

function scale_duals(duals; scale_factor = 1e3, min_magnitude = 1e-10)
    scaled_duals = similar(duals)
    for i in eachindex(duals)
        magnitude = abs(duals[i])
        if magnitude > scale_factor
            scaled_duals[i] = sign(duals[i]) * (magnitude / scale_factor)
        elseif magnitude < min_magnitude
            scaled_duals[i] = 0.0
        else
            scaled_duals[i] = duals[i]
        end
    end
    return scaled_duals
end
