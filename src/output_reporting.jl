"""Output controls and concise reporting for the unified solver API."""

const UC_OUTPUT_VERBOSITIES = (:summary, :detailed, :verbose, :silent)

function _normalize_uc_verbosity(value)
    name = lowercase(replace(string(value), '-' => '_', ' ' => '_'))
    verbosity = Symbol(name)
    verbosity in UC_OUTPUT_VERBOSITIES ||
        throw(ArgumentError("verbosity must be :detailed, :summary, :verbose, or :silent; got $(value)"))
    return verbosity
end

function _uc_result_value(result, field::Symbol, default = nothing)
    return hasproperty(result, field) ? getproperty(result, field) : default
end

function _uc_display_value(value)
    value === nothing && return "-"
    value isa AbstractFloat && !isfinite(value) && return string(value)
    return string(value)
end

function _uc_print_section(io::IO, title::AbstractString)
    separator = repeat("=", 88)
    println(io, "\n", separator)
    println(io, "[", title, "]")
    println(io, separator)
    return nothing
end

function _uc_print_kv(io::IO, label, value)
    println(io, "  ", rpad(string(label) * ":", 32), " ", _uc_display_value(value))
    return nothing
end

function _uc_try(f::Function, default = nothing)
    try
        return f()
    catch
        return default
    end
end

function _uc_print_data_summary(io::IO, data)
    data === nothing && return nothing
    _uc_print_section(io, "Input data")
    for field in (:NB, :NG, :NL, :ND, :NT, :NW, :NS, :NC, :ND2)
        hasproperty(data, field) && _uc_print_kv(io, field, getproperty(data, field))
    end
    hasproperty(data, :full_scenario_probability) &&
        _uc_print_kv(io, :full_scenario_probability, getproperty(data, :full_scenario_probability))

    config_param = _uc_result_value(data, :config_param)
    config_param === nothing && return nothing
    _uc_print_section(io, "Effective model config")
    for field in fieldnames(typeof(config_param))
        _uc_print_kv(io, field, getfield(config_param, field))
    end
    return nothing
end

function _uc_print_model_summary(io::IO, model)
    model === nothing && return nothing
    _uc_print_section(io, "Model and solver details")
    _uc_print_kv(io, :num_variables, _uc_try(() -> JuMP.num_variables(model)))
    _uc_print_kv(io, :objective_value, _uc_try(() -> JuMP.objective_value(model)))
    _uc_print_kv(io, :objective_bound, _uc_try(() -> JuMP.objective_bound(model)))
    _uc_print_kv(io, :relative_gap, _uc_try(() -> JuMP.relative_gap(model)))
    _uc_print_kv(io, :solve_time_seconds, _uc_try(() -> JuMP.solve_time(model)))
    _uc_print_kv(io, :termination_status, _uc_try(() -> JuMP.termination_status(model)))
    return nothing
end

function _uc_print_history(io::IO, history)
    history isa AbstractVector || return nothing
    _uc_print_section(io, "Iteration history")
    isempty(history) && return println(io, "  <empty>")
    println(io, "  iteration | active | lower_bound | upper_bound | gap | added_scenarios")
    for item in history
        iteration = _uc_result_value(item, :iteration, "-")
        active = _uc_result_value(item, :active_scenarios, "-")
        lower = _uc_result_value(item, :lower_bound, "-")
        upper = _uc_result_value(item, :upper_bound, "-")
        gap = _uc_result_value(item, :gap, "-")
        added = _uc_result_value(item, :added_scenarios, "-")
        println(io, "  ", iteration, " | ", active, " | ", lower, " | ", upper, " | ", gap, " | ", added)
    end
    return nothing
end

function _uc_print_cost_summary(io::IO, cost_summary)
    cost_summary === nothing && return nothing
    _uc_print_section(io, "Cost breakdown")
    for field in keys(cost_summary)
        _uc_print_kv(io, field, getfield(cost_summary, field))
    end
    return nothing
end

function _uc_print_algorithm_details(io::IO, result)
    evaluation = _uc_result_value(result, :evaluation)
    if evaluation isa AbstractDict
        _uc_print_section(io, "Recourse evaluation details")
        statuses = Dict{String, Int}()
        recourse_costs = Float64[]
        for item in values(evaluation)
            status = string(_uc_result_value(item, :status, "unknown"))
            statuses[status] = get(statuses, status, 0) + 1
            cost = _uc_result_value(item, :recourse_cost)
            cost isa Number && push!(recourse_costs, Float64(cost))
        end
        _uc_print_kv(io, :scenario_count, length(evaluation))
        _uc_print_kv(io, :statuses, statuses)
        isempty(recourse_costs) || begin
            _uc_print_kv(io, :recourse_cost_min, minimum(recourse_costs))
            _uc_print_kv(io, :recourse_cost_max, maximum(recourse_costs))
            _uc_print_kv(io, :recourse_cost_mean, sum(recourse_costs) / length(recourse_costs))
        end
    end

    subproblem_results = _uc_result_value(result, :subproblem_results)
    if subproblem_results isa AbstractDict
        _uc_print_section(io, "Benders subproblem details")
        feasible = [item for item in values(subproblem_results) if _uc_result_value(item, :is_feasible, false)]
        _uc_print_kv(io, :subproblem_count, length(subproblem_results))
        _uc_print_kv(io, :feasible_count, length(feasible))
        _uc_print_kv(io, :infeasible_count, length(subproblem_results) - length(feasible))
    end

    has_incumbent = hasproperty(result, :incumbent) && result.incumbent !== nothing
    has_dro_status = hasproperty(result, :dro_enabled)
    if has_incumbent || has_dro_status
        _uc_print_section(io, "Algorithm diagnostics")
        has_incumbent && _uc_print_kv(io, :incumbent, "available")
        has_dro_status && _uc_print_kv(io, :dro_enabled, result.dro_enabled)
    end
    return nothing
end

"""
    print_uc_result(result; io = stdout, diagnostics = 0, detail = false)

Print a stable result report for a `UCSolveResult`. Set `detail=true` to include
input dimensions, effective model configuration, solver metadata, iteration history,
cost components, and algorithm-specific diagnostics.
"""
function print_uc_result(result::UCSolveResult; io::IO = stdout, diagnostics::Integer = 0, detail::Bool = false)
    separator = repeat("=", 88)
    println(io, separator)
    println(io, "UNIFIED UC SOLVE RESULT")
    println(io, separator)

    println(io, "[Request]")
    println(io, "  algorithm       : ", result.algorithm)
    println(io, "  input           : ", result.input)

    println(io, "[Status]")
    println(io, "  status          : ", _uc_display_value(_uc_result_value(result, :status)))
    println(io, "  upper_bound     : ", _uc_display_value(_uc_result_value(result, :upper_bound)))
    println(io, "  lower_bound     : ", _uc_display_value(_uc_result_value(result, :lower_bound)))
    println(io, "  gap             : ", _uc_display_value(_uc_result_value(result, :gap)))

    active_scenarios = _uc_result_value(result, :active_scenarios)
    history = _uc_result_value(result, :history)
    iterations = _uc_result_value(result, :iterations)
    cost_summary = _uc_result_value(result, :cost_summary)
    resolved_iterations = iterations === nothing ? (history === nothing ? nothing : length(history)) : iterations
    println(io, "[Progress]")
    println(io, "  iterations      : ", _uc_display_value(resolved_iterations))
    println(io, "  active_scenarios: ", _uc_display_value(active_scenarios))

    if detail
        _uc_print_section(io, "Optimization details")
        _uc_print_data_summary(io, _uc_result_value(result, :data))
        _uc_print_model_summary(io, _uc_result_value(result, :model))
        _uc_print_history(io, history)
        _uc_print_cost_summary(io, cost_summary)
        _uc_print_algorithm_details(io, result)
    end

    println(io, "[Artifacts]")
    println(io, "  output_dir      : ", result.output_dir)
    cost_summary === nothing || println(io, "  cost_summary    : available")

    if diagnostics > 0
        println(io, "[Diagnostics]")
        println(io, "  hidden_messages : ", diagnostics, " line(s); use verbosity=:verbose to show them")
    end
    println(io, separator)
    return result
end
