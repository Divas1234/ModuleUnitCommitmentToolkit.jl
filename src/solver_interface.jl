"""
    solve_uc(; algorithm = :benchmark, input = :excel, scenario_limit = 20, ...)

Unified solver entry point for the extensive-form benchmark, Benders, and CCG
algorithms. The selected algorithm and input source are routed internally to
the existing implementation modules; callers do not need to manage include
order or algorithm-specific data-loading branches.

`calibration` is a named tuple or dictionary of runtime ENV overrides. Values
are applied only for the duration of this solve, so a one-off calibration does
not leak into later calls in the same Julia process.
"""

const _UC_ALGORITHM_MODULES_READY = Ref(false)

function _ensure_uc_algorithm_modules!()
    if !_UC_ALGORITHM_MODULES_READY[]
        project_root = normpath(joinpath(@__DIR__, ".."))
        include(joinpath(project_root, "tools", "ccg", "ccg_solver.jl"))
        include(joinpath(project_root, "tools", "benchmark", "benchmark_uc.jl"))
        _UC_ALGORITHM_MODULES_READY[] = true
    end
    return nothing
end

function _normalize_solver_algorithm(algorithm)
    name = lowercase(replace(string(algorithm), '-' => '_', ' ' => '_'))
    aliases = Dict(
        "benchmark" => :benchmark,
        "benchmark_uc" => :benchmark,
        "extensive" => :benchmark,
        "extensive_form" => :benchmark,
        "benders" => :benders,
        "ccg" => :ccg,
        "column_constraint_generation" => :ccg,
    )
    haskey(aliases, name) || throw(ArgumentError("algorithm must be :benchmark, :benders, or :ccg; got $(algorithm)"))
    return aliases[name]
end

function _calibration_pairs(calibration)
    calibration === nothing && return Pair{String, String}[]
    entries = calibration isa NamedTuple ? pairs(calibration) : calibration isa AbstractDict ? pairs(calibration) : nothing
    entries === nothing && throw(ArgumentError("calibration must be a NamedTuple, dictionary, or nothing"))

    result = Pair{String, String}[]
    for (key, value) in entries
        value === nothing && throw(ArgumentError("calibration value for $(key) cannot be nothing"))
        value isa Bool && (value = value ? 1 : 0)
        value isa Number || value isa AbstractString || throw(ArgumentError("calibration values must be scalar; $(key) has type $(typeof(value))"))
        push!(result, uppercase(string(key)) => string(value))
    end
    return result
end

function _run_with_uc_context(fn::Function, calibration, output_dir)
    overrides = _calibration_pairs(calibration)
    output_dir === nothing || push!(overrides, "MODULE_UC_OUTPUT_DIR" => String(output_dir))
    isempty(overrides) && return fn()
    return withenv(overrides...) do
        return fn()
    end
end

function UCInputSpec(;
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
    source = _normalize_input_source(input, use_powersystems, sys, case_name, case_dir)
    normalized_case_name = case_name === nothing ? nothing : String(case_name)
    return UCInputSpec(
        source,
        scenario_limit,
        sys,
        normalized_case_name,
        case_category,
        case_dir,
        copy(data_center_buses),
        copy(data_center_pmax),
        frequency_parameters,
        data_centers,
        horizon,
    )
end

function load_uc_data(spec::UCInputSpec)
    return load_uc_data(
        input = spec.source,
        scenario_limit = spec.scenario_limit,
        sys = spec.sys,
        case_name = spec.case_name,
        case_category = spec.case_category,
        case_dir = spec.case_dir,
        data_center_buses = spec.data_center_buses,
        data_center_pmax = spec.data_center_pmax,
        frequency_parameters = spec.frequency_parameters,
        data_centers = spec.data_centers,
        horizon = spec.horizon,
    )
end

function UCSolveRequest(;
    algorithm::Union{Symbol, AbstractString} = :benchmark,
    input::Union{Symbol, AbstractString} = :excel,
    use_powersystems::Union{Nothing, Bool} = nothing,
    scenario_limit::Int64 = 20,
    sys = nothing,
    case_name = nothing,
    case_category = MatpowerTestSystems,
    case_dir::String = "",
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
    calibration = NamedTuple(),
    output_dir = nothing,
)
    return UCSolveRequest(
        _normalize_solver_algorithm(algorithm),
        UCInputSpec(
            input = input,
            scenario_limit = scenario_limit,
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
        ),
        calibration,
        output_dir === nothing ? nothing : String(output_dir),
    )
end

function _invoke_uc_algorithm(name::Symbol, args...; kwargs...)
    algorithm = Base.invokelatest(getfield, @__MODULE__, name)
    return Base.invokelatest(algorithm, args...; kwargs...)
end

function _solve_benders_unified(request::UCSolveRequest)
    input = request.input
    values = _invoke_uc_algorithm(
        :main;
        input = input.source,
        scenario_limit = input.scenario_limit,
        sys = input.sys,
        case_name = input.case_name,
        case_category = input.case_category,
        case_dir = input.case_dir,
        data_center_buses = input.data_center_buses,
        data_center_pmax = input.data_center_pmax,
        frequency_parameters = input.frequency_parameters,
        data_centers = input.data_centers,
        horizon = input.horizon,
    )
    setup = values

    return _invoke_uc_algorithm(
        :multiple_bender_decomposition_scuc,
        setup.master_model,
        setup.sub_model,
        setup.master_struct,
        setup.batch_subproblems,
        setup.winds,
        setup.config_param,
        setup.NG,
        setup.NT,
        length(setup.winds.index),
        setup.ND,
        setup.NL,
    )
end

function _solve_uc_selected(request::UCSolveRequest)
    algorithm = request.algorithm
    input = request.input
    _ensure_uc_algorithm_modules!()
    if algorithm == :benchmark
        source = input.source
        if source == :excel
            return _invoke_uc_algorithm(:solve_benchmark_uc; scenario_limit = input.scenario_limit)
        elseif source == :powersystems_csv
            return _invoke_uc_algorithm(
                :solve_benchmark_uc_powersystems,
                input.sys,
                input.case_dir;
                scenario_limit = input.scenario_limit,
                data_center_buses = input.data_center_buses,
                data_center_pmax = input.data_center_pmax,
                frequency_parameters = input.frequency_parameters,
                data_centers = input.data_centers,
                horizon = input.horizon,
            )
        elseif input.case_name !== nothing
            return _invoke_uc_algorithm(
                :solve_benchmark_uc_powersystems,
                input.case_name;
                case_category = input.case_category,
                scenario_limit = input.scenario_limit,
                data_center_buses = input.data_center_buses,
                data_center_pmax = input.data_center_pmax,
                frequency_parameters = input.frequency_parameters,
                data_centers = input.data_centers,
                horizon = input.horizon,
            )
        else
            return _invoke_uc_algorithm(
                :solve_benchmark_uc_powersystems,
                input.sys;
                scenario_limit = input.scenario_limit,
                data_center_buses = input.data_center_buses,
                data_center_pmax = input.data_center_pmax,
                frequency_parameters = input.frequency_parameters,
                data_centers = input.data_centers,
                horizon = input.horizon,
            )
        end
    elseif algorithm == :ccg
        return _invoke_uc_algorithm(
            :solve_ccg_unit_commitment;
            input = input.source,
            scenario_limit = input.scenario_limit,
            sys = input.sys,
            case_name = input.case_name,
            case_category = input.case_category,
            case_dir = input.case_dir,
            data_center_buses = input.data_center_buses,
            data_center_pmax = input.data_center_pmax,
            frequency_parameters = input.frequency_parameters,
            data_centers = input.data_centers,
            horizon = input.horizon,
        )
    else
        return _solve_benders_unified(request)
    end
end

function solve_uc(request::UCSolveRequest)
    configured_output_dir = request.output_dir === nothing ? uc_output_root() : uc_output_dir(request.output_dir)
    result = _run_with_uc_context(request.calibration, request.output_dir) do
        return _solve_uc_selected(request)
    end
    return UCSolveResult(request.algorithm, request.input.source, configured_output_dir, result)
end

function solve_uc(; kwargs...)
    return solve_uc(UCSolveRequest(; kwargs...))
end
