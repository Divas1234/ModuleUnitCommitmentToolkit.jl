"""Solver-agnostic JuMP model factory and termination-status helpers."""

using JuMP
using MathOptInterface

const _DEFAULT_UC_OPTIMIZER = Ref{Any}(nothing)
const _UC_OPTIMIZER_TLS_KEY = :_MODULE_UC_OPTIMIZER

"""
    default_uc_optimizer()

Return the active optimizer factory for UC models.

Precedence:
1. Task-local override set by `with_uc_optimizer` (thread/task-safe).
2. Package default set by `set_default_uc_optimizer!`.
3. `Gurobi.Optimizer` when `Gurobi` is loaded in the module.
"""
function default_uc_optimizer()
    tls = task_local_storage()
    if haskey(tls, _UC_OPTIMIZER_TLS_KEY)
        opt = tls[_UC_OPTIMIZER_TLS_KEY]
        opt !== nothing && return opt
    end
    if _DEFAULT_UC_OPTIMIZER[] !== nothing
        return _DEFAULT_UC_OPTIMIZER[]
    end
    if isdefined(@__MODULE__, :Gurobi)
        return getfield(@__MODULE__, :Gurobi).Optimizer
    end
    throw(
        ArgumentError(
            "No optimizer configured. Pass `optimizer = ...` to `solve_uc` or call `set_default_uc_optimizer!(optimizer)`.",
        ),
    )
end

"""
    set_default_uc_optimizer!(optimizer)

Set the package-wide fallback JuMP optimizer factory (e.g. `HiGHS.Optimizer`,
`Gurobi.Optimizer`, or `optimizer_with_attributes(...)`). Pass `nothing` to reset.
"""
function set_default_uc_optimizer!(optimizer)
    _DEFAULT_UC_OPTIMIZER[] = optimizer
    return optimizer
end

"""
    with_uc_optimizer(fn::Function, optimizer)

Execute `fn()` with `optimizer` bound as the task-local UC optimizer. When
`optimizer === nothing`, inherits the current default without modifying task state.
"""
function with_uc_optimizer(fn::Function, optimizer)
    optimizer === nothing && return fn()
    return task_local_storage(_UC_OPTIMIZER_TLS_KEY, optimizer) do
        return fn()
    end
end

"""
    uc_set_optimizer_attribute!(model::Model, attribute_name::AbstractString, value)

Set a solver attribute when supported by the active backend, silently skipping
backend-specific attributes (e.g. Gurobi's `NumericFocus` on HiGHS).
"""
function uc_set_optimizer_attribute!(model::Model, attribute_name::AbstractString, value)
    try
        set_optimizer_attribute(model, String(attribute_name), value)
    catch err
        @debug "Skipping unsupported optimizer attribute" attribute_name value err
    end
    return model
end

"""
    build_uc_model(; optimizer = nothing, silent = false, attributes = Pair{String, Any}[])

Construct a JuMP `Model` using the active UC optimizer factory, optionally
silencing output and applying backend-safe optimizer attributes.
"""
function build_uc_model(;
    optimizer = nothing,
    silent::Bool = false,
    attributes = (),
)
    opt = optimizer === nothing ? default_uc_optimizer() : optimizer
    model = Model(opt)
    silent && set_silent(model)
    for (attr_name, attr_val) in attributes
        uc_set_optimizer_attribute!(model, attr_name, attr_val)
    end
    return model
end

"""
    uc_has_feasible_solution(model::Model)

Return `true` if `model` terminated with an optimal or usable primal-feasible
incumbent (including `TIME_LIMIT` / `OBJECTIVE_LIMIT` / `ITERATION_LIMIT` with
at least one feasible primal solution).
"""
function uc_has_feasible_solution(model::Model)
    status = termination_status(model)
    if status in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL, MOI.ALMOST_LOCALLY_SOLVED)
        return true
    end
    if status in (MOI.TIME_LIMIT, MOI.OBJECTIVE_LIMIT, MOI.ITERATION_LIMIT, MOI.SOLUTION_LIMIT)
        return result_count(model) > 0 && primal_status(model) in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
    end
    return false
end

"""
    uc_require_feasible_solution!(model::Model; context = "UC model")

Verify that `model` has a usable primal-feasible solution, returning the
`MOI.TerminationStatusCode`. Throws a descriptive error if no feasible solution
was found.
"""
function uc_require_feasible_solution!(model::Model; context::AbstractString = "UC model")
    status = termination_status(model)
    uc_has_feasible_solution(model) && return status
    pstatus = primal_status(model)
    error("$(context) did not find a feasible solution (termination_status=$(status), primal_status=$(pstatus)).")
end
