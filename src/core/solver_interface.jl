
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

const _UC_ALGORITHM_ALIASES = Dict{String, Symbol}(
    "benchmark" => :benchmark,
    "benchmark_uc" => :benchmark,
    "extensive" => :benchmark,
    "extensive_form" => :benchmark,
    "benders" => :benders,
    "ccg" => :ccg,
    "column_constraint_generation" => :ccg,
    "pcm_standard" => :pcm_standard,
    "pcm_clustered" => :pcm_clustered,
    "pcm_adaptive_overlap" => :pcm_adaptive_overlap,
    "pcm_clustered_adaptive" => :pcm_clustered_adaptive,
    "pcm_integrated" => :pcm_integrated,
)

const _BUILTIN_UC_ALGORITHMS = (
    :benchmark,
    :benders,
    :ccg,
    :pcm_standard,
    :pcm_clustered,
    :pcm_adaptive_overlap,
    :pcm_clustered_adaptive,
    :pcm_integrated,
)

function _normalize_algorithm_key(name)
    return lowercase(replace(string(name), '-' => '_', ' ' => '_'))
end

function _normalize_solver_algorithm(algorithm)
    name = _normalize_algorithm_key(algorithm)
    haskey(_UC_ALGORITHM_ALIASES, name) || throw(
        ArgumentError("algorithm must be one of $(collect(_BUILTIN_UC_ALGORITHMS)); got $(algorithm)"),
    )
    return _UC_ALGORITHM_ALIASES[name]
end

const _EXTRA_CALIBRATION_KEYS = Set{String}([
    "BENCHMARK_UC_USE_DRO",
    "DATA_CENTER_NUM_SOS",
    "MODULE_UC_CONFIG_FILE",
    "MODULE_UC_CONFIG_VERBOSE",
    "MODULE_UC_DATA_FILE",
    "MODULE_UC_OUTPUT_DIR",
    "MODULE_UC_RUN_ID",
    "MODULE_UC_SEED_RNG",
    "MODULE_UC_VERBOSE_LOAD",
    "PCM_METHOD",
    "PCM_LOAD_PROFILE",
    "PCM_INTERVALS",
    "PCM_WINDOW_HOURS",
    "PCM_PERFORMANCE_MODE",
])

const _CALIBRATION_KEY_SUGGESTIONS = Dict{String, String}(
    "MODEL_CONSIDER_WIND" => "MODEL_IS_WIND_UNIT_CON",
    "MODEL_NETWORK_CONSTRAINT" => "MODEL_IS_NETWORK_CON",
    "MODEL_THERMAL_UNIT_CONSTRAINT" => "MODEL_IS_THERMAL_UNIT_CON",
)

"""
    known_uc_calibration_keys()

Return the `Set{String}` of recognized runtime calibration keys loaded from
`config/runtime_config.toml` plus supported package-level runtime controls.
"""
function known_uc_calibration_keys()
    keys_set = copy(_EXTRA_CALIBRATION_KEYS)
    if isfile(DEFAULT_RUNTIME_CONFIG_PATH)
        for (k, _) in runtime_config_entries(DEFAULT_RUNTIME_CONFIG_PATH)
            push!(keys_set, uppercase(k))
        end
    end
    return keys_set
end

function _validate_calibration_key(normalized_key::String, valid_keys::Set{String})
    if !(normalized_key in valid_keys)
        suggestion = get(_CALIBRATION_KEY_SUGGESTIONS, normalized_key, nothing)
        hint = suggestion === nothing ? "" : " Did you mean `$(suggestion)`?"
        throw(ArgumentError("Unknown calibration key `$(normalized_key)`.$(hint) See `known_uc_calibration_keys()` or `config/runtime_config.toml`."))
    end
    return nothing
end

function _calibration_pairs(calibration; validate_keys::Bool = false)
    calibration === nothing && return Pair{String, String}[]
    entries = calibration isa NamedTuple ? pairs(calibration) : calibration isa AbstractDict ? pairs(calibration) : nothing
    entries === nothing && throw(ArgumentError("calibration must be a NamedTuple, dictionary, or nothing"))

    valid_keys = validate_keys ? known_uc_calibration_keys() : nothing
    result = Pair{String, String}[]
    for (key, value) in entries
        normalized_key = uppercase(string(key))
        validate_keys && _validate_calibration_key(normalized_key, valid_keys)
        value === nothing && throw(ArgumentError("calibration value for $(key) cannot be nothing"))
        value isa Bool && (value = value ? 1 : 0)
        value isa Number || value isa AbstractString || throw(ArgumentError("calibration values must be scalar; $(key) has type $(typeof(value))"))
        push!(result, normalized_key => string(value))
    end
    return result
end

function _run_with_uc_context(fn::Function, calibration, output_dir; detailed::Bool = false)
    overrides = _calibration_pairs(calibration)
    output_dir === nothing || push!(overrides, "MODULE_UC_OUTPUT_DIR" => String(output_dir))
    detailed && push!(overrides, "PRINT_BOUNDARY_CONDITION" => "1")
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
    data_file::Union{Nothing, AbstractString} = nothing,
)
    source = _normalize_input_source(input, use_powersystems, sys, case_name, case_dir)
    normalized_case_name = case_name === nothing ? nothing : String(case_name)
    normalized_data_file = data_file === nothing ? nothing : String(data_file)
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
        normalized_data_file,
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
        data_file = spec.data_file,
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
    data_file::Union{Nothing, AbstractString} = nothing,
    calibration = NamedTuple(),
    output_dir = nothing,
    verbosity = :detailed,
    optimizer = nothing,
)
    _calibration_pairs(calibration; validate_keys = true)
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
            data_file = data_file,
        ),
        calibration,
        output_dir === nothing ? nothing : String(output_dir),
        _normalize_uc_verbosity(verbosity),
        optimizer,
    )
end

function _solve_benders_unified(request::UCSolveRequest)
    input = request.input
    setup = build_benders_setup(;
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
        data_file = input.data_file,
    )

    decomposition_result = multiple_benders_decomposition_scuc(
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
    if setup.config_param.consider_frequency_control == 1 &&
       frequency_model_mode() in (:hd_region, :hybrid) &&
       haskey(decomposition_result, :incumbent) &&
       decomposition_result.incumbent !== nothing
        export_hd_frequency_analysis(
            setup.units,
            setup.winds,
            decomposition_result.incumbent.x;
            output_dir = uc_scheduling_output_dir("benders"),
            file_prefix = uc_schedule_file_prefix("benders", setup.NS),
        )
    end
    return merge(decomposition_result, (data = setup.data,))
end

function _solve_uc_selected(request::UCSolveRequest)
    return with_uc_optimizer(request.optimizer) do
        algorithm = request.algorithm
        input = request.input
        if algorithm == :benchmark
            source = input.source
            if source == :excel
                return solve_benchmark_uc(;
                    scenario_limit = input.scenario_limit,
                    horizon = input.horizon,
                    data_file = input.data_file,
                )
            elseif source == :powersystems_csv
                return solve_benchmark_uc_powersystems(
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
                return solve_benchmark_uc_powersystems(
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
                return solve_benchmark_uc_powersystems(
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
            return solve_ccg_unit_commitment(;
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
                data_file = input.data_file,
            )
        elseif algorithm in (:pcm_standard, :pcm_clustered, :pcm_adaptive_overlap, :pcm_clustered_adaptive, :pcm_integrated)
            return _solve_pcm_unified(request)
        else
            return _solve_benders_unified(request)
        end
    end
end

function _solve_pcm_unified(request::UCSolveRequest)
    method_map = Dict{Symbol, Symbol}(
        :pcm_standard => :standard,
        :pcm_clustered => :clustered,
        :pcm_adaptive_overlap => :adaptive_overlap,
        :pcm_clustered_adaptive => :clustered_overlap,
        :pcm_integrated => :benchmark,
    )
    cfg = PCMConfig(
        data_file = request.input.data_file === nothing ?
            (let f = strip(get(ENV, "MODULE_UC_DATA_FILE", "")); isempty(f) ? nothing : f end) :
            String(request.input.data_file),
    )
    return run_pcm(method_map[request.algorithm]; cfg = cfg)
end

function _algorithm_to_request_args(alg::BenchmarkUCAlgorithm)
    return (:benchmark, Pair{Symbol, Any}[])
end

function _algorithm_to_request_args(alg::BendersAlgorithm)
    cal = alg.fast_direct ? Pair{Symbol, Any}[:BENDERS_FAST_DIRECT_SOLVE => 1] : Pair{Symbol, Any}[]
    return (:benders, cal)
end

function _algorithm_to_request_args(alg::CCGAlgorithm)
    return (:ccg, Pair{Symbol, Any}[])
end

function _algorithm_to_request_args(alg::PCMAlgorithm)
    canon = pcm_method_spec(alg.method)[1]
    algo_sym = Dict(
        :standard => :pcm_standard,
        :clustered => :pcm_clustered,
        :adaptive_overlap => :pcm_adaptive_overlap,
        :clustered_overlap => :pcm_clustered_adaptive,
        :benchmark => :pcm_integrated,
    )[canon]
    cal = Pair{Symbol, Any}[
        :PCM_LOAD_PROFILE => String(alg.profile),
        :PCM_PERFORMANCE_MODE => String(alg.performance_mode),
    ]
    alg.intervals !== nothing && push!(cal, :PCM_INTERVALS => alg.intervals)
    alg.window_hours !== nothing && push!(cal, :PCM_WINDOW_HOURS => alg.window_hours)
    return (algo_sym, cal)
end

"""
    solve_uc(alg::AbstractUCAlgorithm; kwargs...)

Typed multiple-dispatch entry point for `solve_uc` using concrete algorithm specs
(`BenchmarkUCAlgorithm`, `BendersAlgorithm`, `CCGAlgorithm`, `PCMAlgorithm`).
"""
function solve_uc(alg::AbstractUCAlgorithm; calibration = NamedTuple(), kwargs...)
    algo_sym, alg_cal = _algorithm_to_request_args(alg)
    merged_cal = Dict{Symbol, Any}(alg_cal)
    if calibration !== nothing
        for (k, v) in pairs(calibration)
            merged_cal[Symbol(k)] = v
        end
    end
    return solve_uc(; algorithm = algo_sym, calibration = merged_cal, kwargs...)
end

function solve_uc(request::UCSolveRequest)
    configured_output_dir = request.output_dir === nothing ? uc_output_root() : uc_output_dir(request.output_dir)
    verbosity = _normalize_uc_verbosity(request.verbosity)

    result = if verbosity === :verbose
        _run_with_uc_context(request.calibration, request.output_dir; detailed = false) do
            _solve_uc_selected(request)
        end
    elseif verbosity === :detailed
        redirect_stderr(devnull) do
            _run_with_uc_context(request.calibration, request.output_dir; detailed = true) do
                _solve_uc_selected(request)
            end
        end
    else
        try
            captured_result = redirect_stdout(devnull) do
                redirect_stderr(devnull) do
                    _run_with_uc_context(request.calibration, request.output_dir; detailed = false) do
                        _solve_uc_selected(request)
                    end
                end
            end
            captured_result
        catch error
            println(stderr, "[UC solve failed] ", sprint(showerror, error))
            rethrow()
        end
    end

    envelope = UCSolveResult(request.algorithm, request.input.source, configured_output_dir, result)
    verbosity === :summary && print_uc_result(envelope)
    if verbosity === :detailed
        redirect_stderr(devnull) do
            print_uc_result(envelope; detail = true)
        end
    end
    return envelope
end

function solve_uc(; kwargs...)
    return solve_uc(UCSolveRequest(; kwargs...))
end
