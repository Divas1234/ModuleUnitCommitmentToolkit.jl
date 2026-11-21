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
end

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
)
    return UCInputSpec(
        source, scenario_limit, sys, case_name, case_category, case_dir,
        data_center_buses, data_center_pmax, frequency_parameters, data_centers, horizon, nothing,
    )
end

struct UCSolveRequest
    algorithm::Symbol
    input::UCInputSpec
    calibration::Any
    output_dir::Union{Nothing, String}
    verbosity::Symbol
    optimizer::Any
end

function UCSolveRequest(
    algorithm::Symbol,
    input::UCInputSpec,
    calibration::Any,
    output_dir::Union{Nothing, String},
    verbosity::Symbol,
)
    return UCSolveRequest(algorithm, input, calibration, output_dir, verbosity, nothing)
end

"""Stable public result envelope; algorithm-specific fields live in `details`."""
struct UCSolveResult{T <: NamedTuple}
    algorithm::Symbol
    input::Symbol
    output_dir::String
    details::T
end

function Base.getproperty(result::UCSolveResult, name::Symbol)
    name === :algorithm && return getfield(result, :algorithm)
    name === :input && return getfield(result, :input)
    name === :output_dir && return getfield(result, :output_dir)
    name === :details && return getfield(result, :details)
    return getproperty(getfield(result, :details), name)
end

function Base.propertynames(result::UCSolveResult, private::Bool = false)
    return (:algorithm, :input, :output_dir, :details, keys(getfield(result, :details))...)
end

Base.getindex(result::UCSolveResult, name::Symbol) = getproperty(result, name)

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
