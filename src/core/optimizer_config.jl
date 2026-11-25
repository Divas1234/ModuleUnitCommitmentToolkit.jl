"""Solver-agnostic JuMP model factory and termination-status helpers."""

using JuMP
using MathOptInterface

const _DEFAULT_UC_OPTIMIZER = Ref{Any}(nothing)
const _UC_OPTIMIZER_TLS_KEY = :_MODULE_UC_OPTIMIZER
const _UC_SOLVER_OPTIONS_TLS_KEY = :_MODULE_UC_SOLVER_OPTIONS

"""
    SolverOptions(; optimizer = nothing, mip_gap = nothing, threads = nothing, time_limit = nothing, silent = false)

Immutable, thread/task-safe solver configuration replacing scattered `ENV` lookups
inside optimization loops. Bind per-task via `with_solver_options` or pass directly
to `build_uc_model(; options = opts)`.
"""
Base.@kwdef struct SolverOptions
    optimizer::Any = nothing
    mip_gap::Union{Nothing, Float64} = nothing
    threads::Union{Nothing, Int} = nothing
    time_limit::Union{Nothing, Float64} = nothing
    silent::Bool = false
end

"""Return the active task-local `SolverOptions`, or `nothing` if unbound."""
function current_solver_options()
    tls = task_local_storage()
    return get(tls, _UC_SOLVER_OPTIONS_TLS_KEY, nothing)
end

"""
    with_solver_options(fn::Function, opts::Union{Nothing, SolverOptions})

Execute `fn()` with `opts` bound in task-local storage so concurrent `Threads.@spawn`
sweeps can use independent MIP gaps, thread counts, time limits, and optimizers without
mutating global `ENV`.
"""
function with_solver_options(fn::Function, opts::Union{Nothing, SolverOptions})
    opts === nothing && return fn()
    return task_local_storage(_UC_SOLVER_OPTIONS_TLS_KEY, opts) do
        return opts.optimizer === nothing ? fn() : with_uc_optimizer(fn, opts.optimizer)
    end
end

"""
    solver_options_from_env(; prefix = "UC", optimizer = nothing, silent = false) -> SolverOptions

Construct an immutable `SolverOptions` snapshot once at entry from environment variables
(`\$(prefix)_MIP_GAP`, `\$(prefix)_SOLVER_THREADS`, `\$(prefix)_SOLVER_TIME_LIMIT_SECONDS`).
"""
function solver_options_from_env(;
    prefix::AbstractString = "UC",
    optimizer = nothing,
    silent::Bool = false,
)
    _parse_opt(T, key) = begin
        raw = strip(get(ENV, key, ""))
        isempty(raw) ? nothing : tryparse(T, raw)
    end
    mip_gap = _parse_opt(Float64, "$(prefix)_MIP_GAP")
    threads = _parse_opt(Int, "$(prefix)_SOLVER_THREADS")
    time_limit = _parse_opt(Float64, "$(prefix)_SOLVER_TIME_LIMIT_SECONDS")
    return SolverOptions(
        optimizer = optimizer,
        mip_gap = mip_gap,
        threads = threads,
        time_limit = time_limit,
        silent = silent,
    )
end

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
    apply_solver_options!(model::Model, options::Union{Nothing, SolverOptions}; default_mip_gap = nothing, default_threads = nothing, default_time_limit = nothing, default_silent = false)

Apply explicit `SolverOptions` to `model` using backend-safe attribute setters,
falling back to the caller-supplied defaults only for fields left `nothing`.
"""
function _uc_set_moi_attribute!(model::Model, attr, value)
    try
        set_attribute(model, attr, value)
        return true
    catch err
        @debug "Skipping unsupported MOI attribute" attr value err
        return false
    end
end

function apply_solver_options!(
    model::Model,
    options::Union{Nothing, SolverOptions};
    default_mip_gap::Union{Nothing, Real} = nothing,
    default_threads::Union{Nothing, Integer} = nothing,
    default_time_limit::Union{Nothing, Real} = nothing,
    default_silent::Bool = false,
)
    is_silent = options === nothing ? default_silent : (options.silent || default_silent)
    is_silent && set_silent(model)

    mip_gap = (options !== nothing && options.mip_gap !== nothing) ? options.mip_gap : default_mip_gap
    if mip_gap !== nothing
        if !_uc_set_moi_attribute!(model, MOI.RelativeGapTolerance(), Float64(mip_gap))
            uc_set_optimizer_attribute!(model, "MIPGap", Float64(mip_gap))
            uc_set_optimizer_attribute!(model, "mip_gap", Float64(mip_gap))
            uc_set_optimizer_attribute!(model, "mip_rel_gap", Float64(mip_gap))
        end
    end

    threads = (options !== nothing && options.threads !== nothing) ? options.threads : default_threads
    if threads !== nothing && threads > 0
        if !_uc_set_moi_attribute!(model, MOI.NumberOfThreads(), Int(threads))
            uc_set_optimizer_attribute!(model, "Threads", Int(threads))
            uc_set_optimizer_attribute!(model, "threads", Int(threads))
        end
    end

    time_limit = (options !== nothing && options.time_limit !== nothing) ? options.time_limit : default_time_limit
    if time_limit !== nothing && time_limit > 0
        if !_uc_set_moi_attribute!(model, MOI.TimeLimitSec(), Float64(time_limit))
            uc_set_optimizer_attribute!(model, "TimeLimit", Float64(time_limit))
            uc_set_optimizer_attribute!(model, "tm_lim", round(Int, Float64(time_limit) * 1000))
            uc_set_optimizer_attribute!(model, "time_limit", Float64(time_limit))
        end
    end
    return model
end

const _UNSET_SOLVER_OPTIONS = :_unset_solver_options

"""
    build_uc_model(; options = current_solver_options(), optimizer = nothing, silent = nothing, attributes = ())

Construct a JuMP `Model` using the active UC optimizer factory and optional `SolverOptions`,
applying backend-safe solver attributes (`MIPGap`, `Threads`, `TimeLimit`).
"""
function build_uc_model(;
    options = _UNSET_SOLVER_OPTIONS,
    optimizer = nothing,
    silent::Union{Nothing, Bool} = nothing,
    attributes = (),
)
    explicit_options = options !== _UNSET_SOLVER_OPTIONS
    resolved_options::Union{Nothing, SolverOptions} = explicit_options ? options : current_solver_options()
    resolved_opt = if optimizer !== nothing
        optimizer
    elseif explicit_options && resolved_options !== nothing && resolved_options.optimizer !== nothing
        resolved_options.optimizer
    else
        default_uc_optimizer()
    end
    model = Model(resolved_opt)
    apply_solver_options!(
        model,
        resolved_options;
        default_silent = silent === nothing ? false : silent,
    )
    if silent === false && resolved_options !== nothing && resolved_options.silent
        unset_silent(model)
    end
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
