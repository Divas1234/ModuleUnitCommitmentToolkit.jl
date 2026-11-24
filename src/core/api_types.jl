"""Named request, input, problem data, result, and compatibility types for the public UC API."""

"""
    UCProblemData

Strongly typed problem data container unifying all system dimensions and component
structs so solvers, validators, and constraint builders accept a single structured
argument instead of 15-20 positional parameters.
"""
struct UCProblemData{C, U, L, D, S, W, DC}
    config_param::C
    units::U
    lines::L
    loads::D
    storages::S
    winds::W
    data_centers::DC
    NB::Int64
    NG::Int64
    NL::Int64
    ND::Int64
    NT::Int64
    NC::Int64
    ND2::Int64
    NW::Int64
    NS::Int64
end

UCProblemData(data::UCProblemData) = data

function UCProblemData(data::NamedTuple)
    return UCProblemData(
        data.config_param,
        data.units,
        data.lines,
        data.loads,
        hasproperty(data, :storages) ? data.storages : data.psses,
        data.winds,
        data.data_centers,
        Int64(data.NB),
        Int64(data.NG),
        Int64(data.NL),
        Int64(data.ND),
        Int64(data.NT),
        Int64(data.NC),
        Int64(data.ND2),
        Int64(data.NW),
        Int64(data.NS),
    )
end

function Base.getproperty(data::UCProblemData, name::Symbol)
    name === :psses && return getfield(data, :storages)
    name === :DataCentras && return getfield(data, :data_centers)
    return getfield(data, name)
end

Base.getindex(data::UCProblemData, name::Symbol) = getproperty(data, name)

"""
    AbstractUCAlgorithm

Supertype for typed solver/algorithm specifications enabling Julia multiple dispatch
via `solve_uc(alg::AbstractUCAlgorithm; kwargs...)`.
"""
abstract type AbstractUCAlgorithm end

struct BenchmarkUCAlgorithm <: AbstractUCAlgorithm end

struct BendersAlgorithm <: AbstractUCAlgorithm
    fast_direct::Bool
end
BendersAlgorithm(; fast_direct::Bool = false) = BendersAlgorithm(fast_direct)

struct CCGAlgorithm <: AbstractUCAlgorithm end

struct PCMAlgorithm <: AbstractUCAlgorithm
    method::Symbol
    profile::Symbol
    intervals::Union{Nothing, Int}
    window_hours::Union{Nothing, Int}
    performance_mode::Symbol
end
function PCMAlgorithm(;
    method::Symbol = :standard,
    profile::Symbol = :baseline,
    intervals::Union{Nothing, Int} = nothing,
    window_hours::Union{Nothing, Int} = nothing,
    performance_mode::Symbol = :fast,
)
    canon = if isdefined(@__MODULE__, :pcm_method_spec)
        pcm_method_spec(method)[1]
    else
        method in (:standard, :clustered, :clustered_pcm, :adaptive_overlap, :clustered_overlap, :clustered_adaptive_overlap, :benchmark, :integrated) ||
            throw(ArgumentError("Unsupported PCM method: $(method)"))
        method
    end
    return PCMAlgorithm(canon, profile, intervals, window_hours, performance_mode)
end

"""Immutable snapshot of clustered PCM window execution statistics."""
struct PCMRunStats
    attempts::Int
    successes::Int
    fallbacks::Int
    preprocess_time_sec::Float64
    extended_integer_variables::Int
end

struct UCInputSpec
    source::Symbol
    scenario_limit::Int64
    sys::Any
    case_name::Union{Nothing, String}
    case_category::Any
    case_dir::String
    data_center_buses::Vector{Int}
    data_center_pmax::Vector{Float64}
    frequency_parameters::Any
    data_centers::Any
    horizon::Int64
    data_file::Union{Nothing, String}

    function UCInputSpec(
        source::Symbol,
        scenario_limit::Int64,
        sys::Any,
        case_name::Union{Nothing, String},
        case_category::Any,
        case_dir::String,
        data_center_buses::Vector{Int},
        data_center_pmax::Vector{Float64},
        frequency_parameters::Any,
        data_centers::Any,
        horizon::Int64,
        data_file::Union{Nothing, String} = nothing,
    )
        return new(
            source, scenario_limit, sys, case_name, case_category, case_dir,
            data_center_buses, data_center_pmax, frequency_parameters, data_centers, horizon, data_file,
        )
    end
end

struct UCSolveRequest
    algorithm::Symbol
    input::UCInputSpec
    calibration::Any
    output_dir::Union{Nothing, String}
    verbosity::Symbol
    optimizer::Any
    solver_options::Any

    function UCSolveRequest(
        algorithm::Symbol,
        input::UCInputSpec,
        calibration::Any,
        output_dir::Union{Nothing, String},
        verbosity::Symbol,
        optimizer::Any = nothing,
        solver_options::Any = nothing,
    )
        return new(algorithm, input, calibration, output_dir, verbosity, optimizer, solver_options)
    end
end

function _optional_float(val)
    val === nothing && return nothing
    val isa Real || return nothing
    f = Float64(val)
    return isfinite(f) ? f : nothing
end

function _extract_uc_result_summary(details::NamedTuple, wall_runtime::Union{Nothing, Real})
    status = if hasproperty(details, :status) && details.status !== nothing
        string(details.status)
    elseif hasproperty(details, :termination_status) && details.termination_status !== nothing
        string(details.termination_status)
    else
        "UNKNOWN"
    end

    objective = if hasproperty(details, :objective)
        _optional_float(details.objective)
    elseif hasproperty(details, :upper_bound)
        _optional_float(details.upper_bound)
    elseif hasproperty(details, :total_cost)
        _optional_float(details.total_cost)
    elseif hasproperty(details, :cost_summary) && details.cost_summary !== nothing &&
           hasproperty(details.cost_summary, :total_cost)
        _optional_float(details.cost_summary.total_cost)
    else
        nothing
    end

    lower_bound = hasproperty(details, :lower_bound) ? _optional_float(details.lower_bound) : nothing
    gap = hasproperty(details, :gap) ? _optional_float(details.gap) : nothing

    runtime_seconds = if hasproperty(details, :runtime_seconds) && details.runtime_seconds !== nothing
        _optional_float(details.runtime_seconds)
    elseif hasproperty(details, :wall_time_sec) && details.wall_time_sec !== nothing
        _optional_float(details.wall_time_sec)
    elseif hasproperty(details, :solve_time) && details.solve_time !== nothing
        _optional_float(details.solve_time)
    else
        _optional_float(wall_runtime)
    end

    return status, objective, lower_bound, gap, runtime_seconds
end

"""
    UCSolveResult

Stable public result envelope with a unified minimal contract across all algorithms
(`status`, `objective`, `lower_bound`, `gap`, `runtime_seconds`). Algorithm-specific
payloads live in `details` and remain accessible via `getproperty` forwarding.
"""
struct UCSolveResult{T <: NamedTuple}
    algorithm::Symbol
    input::Symbol
    output_dir::String
    status::String
    objective::Union{Nothing, Float64}
    lower_bound::Union{Nothing, Float64}
    gap::Union{Nothing, Float64}
    runtime_seconds::Union{Nothing, Float64}
    details::T
end

function UCSolveResult(
    algorithm::Symbol,
    input::Symbol,
    output_dir::String,
    details::T;
    runtime_seconds::Union{Nothing, Real} = nothing,
) where {T <: NamedTuple}
    status, objective, lower_bound, gap, rt = _extract_uc_result_summary(details, runtime_seconds)
    return UCSolveResult{T}(
        algorithm,
        input,
        output_dir,
        status,
        objective,
        lower_bound,
        gap,
        rt,
        details,
    )
end

const _UC_RESULT_CORE_FIELDS = (
    :algorithm,
    :input,
    :output_dir,
    :status,
    :objective,
    :lower_bound,
    :gap,
    :runtime_seconds,
    :details,
)

function Base.getproperty(result::UCSolveResult, name::Symbol)
    name in _UC_RESULT_CORE_FIELDS && return getfield(result, name)
    return getproperty(getfield(result, :details), name)
end

function Base.propertynames(result::UCSolveResult, private::Bool = false)
    detail_keys = Tuple(k for k in keys(getfield(result, :details)) if !(k in _UC_RESULT_CORE_FIELDS))
    return (_UC_RESULT_CORE_FIELDS..., detail_keys...)
end

Base.getindex(result::UCSolveResult, name::Symbol) = getproperty(result, name)

function _as_schedule_matrix(raw::AbstractDict{String}, key::String)
    haskey(raw, key) || return zeros(Float64, 0, 0)
    val = raw[key]
    val === nothing && return zeros(Float64, 0, 0)
    return val isa AbstractMatrix ? Float64.(Matrix(val)) : reshape(Float64.(vec(val)), :, 1)
end

"""
    UCScheduleResult

Lightweight ASCII-named schedule result container wrapping a solved UC schedule
so downstream code can use `res.commitment`, `res.startup`, `res.shutdown`,
`res.dispatch`, `res.load_shed`, `res.wind_curtail`, `res.reserve_up`,
`res.reserve_down`, and `res.total_cost` instead of Unicode string keys
(`"x₀"`, `"pᵨ"`, `"pᵩ"`). Supports dictionary-style lookup (`res["x₀"]`,
`haskey`, `get`, `keys`) for full backward compatibility.
"""
struct UCScheduleResult
    commitment::Matrix{Float64}
    startup::Matrix{Float64}
    shutdown::Matrix{Float64}
    dispatch::Matrix{Float64}
    load_shed::Matrix{Float64}
    wind_curtail::Matrix{Float64}
    reserve_up::Matrix{Float64}
    reserve_down::Matrix{Float64}
    total_cost::Float64
    raw::Dict{String, Any}
end

UCScheduleResult(res::UCScheduleResult) = res

function UCScheduleResult(raw::AbstractDict{String})
    raw_dict = Dict{String, Any}(String(k) => v for (k, v) in pairs(raw))
    total_cost = if haskey(raw_dict, "total_cost") && raw_dict["total_cost"] isa Real
        Float64(raw_dict["total_cost"])
    elseif haskey(raw_dict, "objective_value") && raw_dict["objective_value"] isa Real
        Float64(raw_dict["objective_value"])
    else
        NaN
    end
    return UCScheduleResult(
        _as_schedule_matrix(raw_dict, "x₀"),
        _as_schedule_matrix(raw_dict, "u₀"),
        _as_schedule_matrix(raw_dict, "v₀"),
        _as_schedule_matrix(raw_dict, "p₀"),
        _as_schedule_matrix(raw_dict, "pᵨ"),
        _as_schedule_matrix(raw_dict, "pᵩ"),
        _as_schedule_matrix(raw_dict, "seq_sr⁺"),
        _as_schedule_matrix(raw_dict, "seq_sr⁻"),
        total_cost,
        raw_dict,
    )
end

Base.getindex(r::UCScheduleResult, key::AbstractString) = r.raw[String(key)]
Base.haskey(r::UCScheduleResult, key::AbstractString) = haskey(r.raw, String(key))
Base.get(r::UCScheduleResult, key::AbstractString, default) = get(r.raw, String(key), default)
Base.keys(r::UCScheduleResult) = keys(r.raw)

"""Named Benders model setup returned by `main`.

The iterator exposes the historical 20-value order for old scripts. New code
must use named fields; the compatibility iterator can be removed in a future
major release.
"""
struct BendersSetup
    master_model::Any
    sub_model::Any
    master_struct::Any
    sub_struct::Any
    batch_subproblems::Any
    config_param::Any
    units::Any
    lines::Any
    loads::Any
    winds::Any
    psses::Any
    NB::Int64
    NG::Int64
    NL::Int64
    ND::Int64
    NS::Int64
    NT::Int64
    NC::Int64
    ND2::Int64
    data_centers::Any
    data::Any
end

function Base.getproperty(setup::BendersSetup, name::Symbol)
    name === :DataCentras && return getfield(setup, :data_centers)
    return getfield(setup, name)
end

const _BENDERS_LEGACY_FIELDS = (
    :master_model,
    :sub_model,
    :master_struct,
    :sub_struct,
    :batch_subproblems,
    :config_param,
    :units,
    :lines,
    :loads,
    :winds,
    :psses,
    :NB,
    :NG,
    :NL,
    :ND,
    :NS,
    :NT,
    :NC,
    :ND2,
    :data_centers,
)

function Base.iterate(setup::BendersSetup, state::Int = 1)
    state > length(_BENDERS_LEGACY_FIELDS) && return nothing
    return getproperty(setup, _BENDERS_LEGACY_FIELDS[state]), state + 1
end

Base.length(::BendersSetup) = length(_BENDERS_LEGACY_FIELDS)
