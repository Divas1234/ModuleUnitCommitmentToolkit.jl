"""
    solve_uc(...)

The `pcm` branch is intentionally trimmed to the adaptive PCM workflow.
Benchmark, Benders, and CCG drivers are not shipped in this branch. Use the
scripts under `tools/pcm/` for PCM simulations and archived overlap analyses.
"""

function _normalize_solver_algorithm(algorithm)
    name = lowercase(replace(string(algorithm), '-' => '_', ' ' => '_'))
    if name in ("pcm", "adaptive_pcm", "rolling_pcm")
        return :pcm
    end
    throw(ArgumentError("Only PCM workflows are available on this branch; got $(algorithm). Run scripts under tools/pcm/."))
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
    algorithm::Union{Symbol, AbstractString} = :pcm,
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
    verbosity = :detailed,
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
        _normalize_uc_verbosity(verbosity),
    )
end

function solve_uc(::UCSolveRequest)
    throw(ArgumentError("The trimmed pcm branch does not expose solve_uc algorithm drivers. Run tools/pcm/pcm_main.jl or tools/pcm/evaluate_overlap_criteria_combinations.jl."))
end

function solve_uc(; kwargs...)
    return solve_uc(UCSolveRequest(; kwargs...))
end
