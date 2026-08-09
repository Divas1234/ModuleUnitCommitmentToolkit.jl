"""Output controls and concise reporting for the unified solver API."""

using CSV
using DataFrames

const UC_OUTPUT_VERBOSITIES = (:summary, :detailed, :verbose, :silent)

function _normalize_uc_verbosity(value)
    name = lowercase(replace(string(value), '-' => '_', ' ' => '_'))
    verbosity = Symbol(name)
    verbosity in UC_OUTPUT_VERBOSITIES || throw(ArgumentError("verbosity must be :detailed, :summary, :verbose, or :silent; got $(value)"))
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

function _uc_table_value(value)
    value === nothing && return "-"
    value isa AbstractArray && return sprint(show, value)
    value isa AbstractDict && return sprint(show, value)
    return value
end

function _uc_result_table(parameter, value)
    return DataFrame(; parameter = String[string(item) for item ∈ parameter], value = Any[_uc_table_value(item) for item ∈ value])
end

function _uc_write_result_table(df::DataFrame, name::AbstractString, output_dir::AbstractString)
    result_dir = joinpath(output_dir, "result")
    mkpath(result_dir)
    return CSV.write(joinpath(result_dir, string(name, ".csv")), df)
end

function _uc_print_result_table(io::IO, title::AbstractString, name::AbstractString, df::DataFrame, output_dir::AbstractString)
    _uc_print_section(io, title)
    show(io, MIME("text/plain"), df; allrows = true, allcols = true)
    println(io)
    csv_path = _uc_write_result_table(df, name, output_dir)
    println(io, "saved_csv       : ", csv_path)
    return nothing
end

function _uc_try(f::Function, default = nothing)
    try
        return f()
    catch
        return default
    end
end

function _uc_print_data_summary(io::IO, data, output_dir::AbstractString)
    data === nothing && return nothing
    fields = [field for field ∈ (:NB, :NG, :NL, :ND, :NT, :NW, :NS, :NC, :ND2, :full_scenario_probability) if hasproperty(data, field)]
    values = [getproperty(data, field) for field ∈ fields]
    _uc_print_result_table(io, "Input data", "04_input_data", _uc_result_table(fields, values), output_dir)

    config_param = _uc_result_value(data, :config_param)
    config_param === nothing && return nothing
    config_fields = fieldnames(typeof(config_param))
    config_values = [getfield(config_param, field) for field ∈ config_fields]
    _uc_print_result_table(io, "Effective model config", "05_effective_config", _uc_result_table(config_fields, config_values), output_dir)
    return nothing
end

function _uc_print_model_summary(io::IO, model, output_dir::AbstractString)
    model === nothing && return nothing
    fields = (:num_variables, :objective_value, :objective_bound, :relative_gap, :solve_time_seconds, :termination_status)
    values = [_uc_try(() -> JuMP.num_variables(model)), _uc_try(() -> JuMP.objective_value(model)), _uc_try(() -> JuMP.objective_bound(model)),
        _uc_try(() -> JuMP.relative_gap(model)), _uc_try(() -> JuMP.solve_time(model)), _uc_try(() -> JuMP.termination_status(model))]
    _uc_print_result_table(io, "Model and solver details", "06_model_solver", _uc_result_table(fields, values), output_dir)
    return nothing
end

function _uc_print_history(io::IO, history, output_dir::AbstractString)
    history isa AbstractVector || return nothing
    columns = (:iteration, :active_scenarios, :lower_bound, :upper_bound, :gap, :added_scenarios)
    rows = [[_uc_result_value(item, field, "-") for field ∈ columns] for item ∈ history]
    values = isempty(rows) ? [Any[] for _ ∈ columns] : [Any[row[index] for row ∈ rows] for index ∈ eachindex(columns)]
    history_df = DataFrame(;
        iteration = isempty(rows) ? Int[] : values[1], active_scenarios = isempty(rows) ? Any[] : [_uc_table_value(item) for item ∈ values[2]],
        lower_bound = isempty(rows) ? Float64[] : values[3],
        upper_bound = isempty(rows) ? Float64[] : values[4], gap = isempty(rows) ? Float64[] : values[5],
        added_scenarios = isempty(rows) ? String[] : [string(_uc_table_value(item)) for item ∈ values[6]])
    _uc_print_result_table(io, "Iteration history", "07_iteration_history", history_df, output_dir)
    return nothing
end

function _uc_print_cost_summary(io::IO, cost_summary, output_dir::AbstractString)
    cost_summary === nothing && return nothing
    fields = collect(keys(cost_summary))
    values = [getfield(cost_summary, field) for field ∈ fields]
    _uc_print_result_table(io, "Cost breakdown", "08_cost_breakdown", _uc_result_table(fields, values), output_dir)
    return nothing
end

function _uc_print_algorithm_details(io::IO, result, output_dir::AbstractString)
    parameters = String[]
    diagnostic_values = Any[]
    evaluation = _uc_result_value(result, :evaluation)
    if evaluation isa AbstractDict
        statuses = Dict{String, Int}()
        recourse_costs = Float64[]
        for item ∈ values(evaluation)
            status = string(_uc_result_value(item, :status, "unknown"))
            statuses[status] = get(statuses, status, 0) + 1
            cost = _uc_result_value(item, :recourse_cost)
            cost isa Number && push!(recourse_costs, Float64(cost))
        end
        push!(parameters, "scenario_count")
        push!(diagnostic_values, length(evaluation))
        push!(parameters, "statuses")
        push!(diagnostic_values, statuses)
        isempty(recourse_costs) || begin
            push!(parameters, "recourse_cost_min")
            push!(diagnostic_values, minimum(recourse_costs))
            push!(parameters, "recourse_cost_max")
            push!(diagnostic_values, maximum(recourse_costs))
            push!(parameters, "recourse_cost_mean")
            push!(diagnostic_values, sum(recourse_costs) / length(recourse_costs))
        end
    end

    subproblem_results = _uc_result_value(result, :subproblem_results)
    if subproblem_results isa AbstractDict
        feasible = [item for item ∈ values(subproblem_results) if _uc_result_value(item, :is_feasible, false)]
        push!(parameters, "subproblem_count")
        push!(diagnostic_values, length(subproblem_results))
        push!(parameters, "feasible_count")
        push!(diagnostic_values, length(feasible))
        push!(parameters, "infeasible_count")
        push!(diagnostic_values, length(subproblem_results) - length(feasible))
    end

    has_incumbent = hasproperty(result, :incumbent) && result.incumbent !== nothing
    has_dro_status = hasproperty(result, :dro_enabled)
    if has_incumbent || has_dro_status
        has_incumbent && begin
            push!(parameters, "incumbent")
            push!(diagnostic_values, "available")
        end
        has_dro_status && begin
            push!(parameters, "dro_enabled")
            push!(diagnostic_values, result.dro_enabled)
        end
    end
    isempty(parameters) && return nothing
    _uc_print_result_table(io, "Algorithm diagnostics", "09_algorithm_diagnostics", _uc_result_table(parameters, diagnostic_values), output_dir)
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

    active_scenarios = _uc_result_value(result, :active_scenarios)
    history = _uc_result_value(result, :history)
    iterations = _uc_result_value(result, :iterations)
    cost_summary = _uc_result_value(result, :cost_summary)
    resolved_iterations = iterations === nothing ? (history === nothing ? nothing : length(history)) : iterations

    _uc_print_result_table(io, "Request", "01_request", _uc_result_table((:algorithm, :input), (result.algorithm, result.input)), result.output_dir)
    _uc_print_result_table(io,
        "Status",
        "02_status",
        _uc_result_table((:status, :upper_bound, :lower_bound, :gap),
            (_uc_result_value(result, :status), _uc_result_value(result, :upper_bound),
                _uc_result_value(result, :lower_bound), _uc_result_value(result, :gap))),
        result.output_dir)
    _uc_print_result_table(
        io, "Progress", "03_progress", _uc_result_table((:iterations, :active_scenarios), (resolved_iterations, active_scenarios)), result.output_dir)

    if detail
        _uc_print_section(io, "Optimization details")
        _uc_print_data_summary(io, _uc_result_value(result, :data), result.output_dir)
        _uc_print_model_summary(io, _uc_result_value(result, :model), result.output_dir)
        _uc_print_history(io, history, result.output_dir)
        _uc_print_cost_summary(io, cost_summary, result.output_dir)
        _uc_print_algorithm_details(io, result, result.output_dir)
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
