"""
    src/production_cost/configuration.jl

Core orthogonal types, configuration, load-profile transforms, and Excel data
adapter for Production Cost Modeling (PCM).

Orthogonal 2x2 PCM Method Matrix + Benchmark Reference:
  Formulation Axis (Clustering):
    - SingleUnitFormulation  (physical single-unit SCUC, no clustering)
    - ClusteredFormulation   (homogeneous clustering + PTDF + disaggregation)
  Horizon Axis (Overlap):
    - FixedHorizonPolicy     (non-overlapping fixed rolling windows)
    - AdaptiveOverlapPolicy  (adaptive ML/rule-based overlapping windows)
  Reference Baseline:
    - Benchmark (Integrated Full-Horizon UC over `intervals * window_hours`)
"""

using Statistics

abstract type AbstractPCMFormulation end
struct SingleUnitFormulation <: AbstractPCMFormulation end
struct ClusteredFormulation <: AbstractPCMFormulation end

abstract type AbstractPCMHorizonPolicy end

Base.@kwdef struct FixedHorizonPolicy <: AbstractPCMHorizonPolicy
    window_hours::Int = 24
    intervals::Int = 7
end

Base.@kwdef struct AdaptiveOverlapPolicy <: AbstractPCMHorizonPolicy
    window_hours::Int = 24
    intervals::Int = 7
    max_overlap_hours::Int = 12
    overlap_mode::String = "ml_prediction"
end

Base.@kwdef struct PCMConfig
    window_hours::Int = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
    intervals::Int = parse(Int, get(ENV, "PCM_INTERVALS", "7"))
    load_profile::String = lowercase(strip(get(ENV, "PCM_LOAD_PROFILE", "baseline")))
    performance_mode::String = lowercase(strip(get(ENV, "PCM_PERFORMANCE_MODE", "fast")))
    network_constraints::Bool = get(ENV, "PCM_NETWORK_CONSTRAINTS", "0") in ("1", "true", "yes")
    random_seed::Int = parse(Int, get(ENV, "PCM_RANDOM_SEED", "20260809"))
    data_file::Union{Nothing, String} = let f = strip(get(ENV, "MODULE_UC_DATA_FILE", ""))
        isempty(f) ? nothing : f
    end

    function PCMConfig(window_hours, intervals, load_profile, performance_mode, network_constraints, random_seed, data_file)
        window_hours > 0 || throw(ArgumentError("PCMConfig.window_hours must be positive; got $window_hours"))
        intervals > 0 || throw(ArgumentError("PCMConfig.intervals must be positive; got $intervals"))
        perf = lowercase(strip(String(performance_mode)))
        perf in ("fast", "balanced") || throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced; got '$performance_mode'"))
        return new(window_hours, intervals, lowercase(strip(String(load_profile))), perf, network_constraints, random_seed, data_file)
    end
end

"""
    pcm_method_spec(method) -> (name::Symbol, formulation::AbstractPCMFormulation, horizon::AbstractPCMHorizonPolicy, is_benchmark::Bool)

Resolve a canonical or alias PCM method name into its orthogonal
`(formulation, horizon)` pair or the full-horizon `:benchmark` reference.
"""
function pcm_method_spec(method; cfg::PCMConfig = PCMConfig())
    key = lowercase(replace(strip(string(method)), '-' => '_', ' ' => '_'))
    if key in ("benchmark", "integrated", "integrated_uc", "uc_reference", "pcm_integrated")
        total_h = parse(Int, get(ENV, "PCM_INTEGRATED_HORIZON_HOURS", string(cfg.intervals * cfg.window_hours)))
        return (:benchmark, SingleUnitFormulation(), FixedHorizonPolicy(window_hours = total_h, intervals = 1), true)
    elseif key in ("standard", "single", "single_unit", "pcm_standard")
        return (:standard, SingleUnitFormulation(), FixedHorizonPolicy(window_hours = cfg.window_hours, intervals = cfg.intervals), false)
    elseif key in ("clustered", "clustered_pcm", "cluster", "pcm_clustered")
        return (:clustered, ClusteredFormulation(), FixedHorizonPolicy(window_hours = cfg.window_hours, intervals = cfg.intervals), false)
    elseif key in ("adaptive_overlap", "adaptive", "overlap", "pcm_adaptive_overlap")
        return (:adaptive_overlap, SingleUnitFormulation(), AdaptiveOverlapPolicy(window_hours = cfg.window_hours, intervals = cfg.intervals), false)
    elseif key in ("clustered_overlap", "clustered_adaptive_overlap", "adaptive_clustered", "clustered_adaptive", "pcm_clustered_adaptive")
        return (:clustered_overlap, ClusteredFormulation(), AdaptiveOverlapPolicy(window_hours = cfg.window_hours, intervals = cfg.intervals), false)
    end
    throw(ArgumentError(
        "Unsupported PCM method '$(method)'. Expected one of: standard, adaptive_overlap, clustered, clustered_overlap, benchmark",
    ))
end

# Load-profile transforms preserving total energy for fair cost comparison.
if !isdefined(@__MODULE__, :_PCM_LOAD_PROFILES_INCLUDED)
    const _PCM_LOAD_PROFILES_INCLUDED = true

    function _rescale_energy!(curve, target_energy)
        current_energy = sum(curve)
        current_energy > 0 && (curve .*= target_energy / current_energy)
        return curve
    end

    function apply_pcm_load_profile!(loads, profile::AbstractString)
        mode = lowercase(strip(profile))
        mode in ("", "baseline", "original") && return loads

        original = copy(loads.load_curve)
        target_energy = sum(original)
        hours = size(original, 2)

        if mode == "smooth"
            smoothed = similar(original)
            for t in 1:hours
                window = max(1, t - 2):min(hours, t + 2)
                smoothed[:, t] .= vec(mean(original[:, window]; dims = 2))
            end
            loads.load_curve .= _rescale_energy!(smoothed, target_energy)
        elseif mode in ("extreme_ramp", "ramp")
            factors = [isodd(div(t - 1, 4)) ? 1.30 : 0.70 for t in 1:hours]
            for t in 1:hours
                t % 12 == 0 && (factors[t] *= 1.15)
            end
            ramped = original .* reshape(factors, 1, :)
            loads.load_curve .= _rescale_energy!(ramped, target_energy)
        else
            throw(ArgumentError("Unsupported PCM_LOAD_PROFILE='$profile'. Use baseline, smooth, or extreme_ramp."))
        end
        return loads
    end
end

"""
    load_pcm_excel_data(; data_file = nothing, network_constraints = nothing)

Load Excel input data via the canonical 9-tuple `readxlssheet()` / 13-tuple
`forminputdata()` pipeline and return a PCM-ready NamedTuple (including empty
hydro placeholder when hydro sheets are absent).
"""
function load_pcm_excel_data(;
    data_file::Union{Nothing, AbstractString} = nothing,
    network_constraints::Union{Nothing, Bool} = nothing,
)
    net_flag = if network_constraints === nothing
        get(ENV, "PCM_NETWORK_CONSTRAINTS", "0")
    else
        network_constraints ? "1" : "0"
    end
    raw = withenv("MODEL_IS_NETWORK_CON" => net_flag) do
        data_file === nothing ? readxlssheet() : readxlssheet(String(data_file))
    end
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data = raw[1:9]

    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
        withenv("MODEL_IS_NETWORK_CON" => net_flag) do
            forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data)
        end

    NH = 0
    hydros = (
        index = Int64[],
        locatebus = Int64[],
        p_min = Float64[],
        p_max = Float64[],
        inflow = zeros(Float64, 0, NT),
    )
    return (
        config_param = config_param,
        units = units,
        lines = lines,
        loads = loads,
        stroges = stroges,
        NB = NB,
        NG = NG,
        NL = NL,
        ND = ND,
        NT = NT,
        NC = NC,
        ND2 = ND2,
        NH = NH,
        DataCentras = DataCentras,
        hydros = hydros,
        WindsFreqParam = WindsFreqParam,
    )
end
