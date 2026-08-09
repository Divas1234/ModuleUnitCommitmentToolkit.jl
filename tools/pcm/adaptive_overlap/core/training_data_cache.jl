module AdaptiveOverlapTrainingCache

using CSV
using DataFrames
using Dates
using SHA
using TOML

export DEFAULT_REQUIRED_COLUMNS, array_sha256, build_case_metadata, case_signature,
       cache_paths, load_cached_dataset, save_cached_dataset

const CACHE_SCHEMA_VERSION = "1"
const CACHE_DIRECTORY = "overlap_training_cache"
const DEFAULT_REQUIRED_COLUMNS = [
    :U_norm, :T_dwell_rem, :L_norm, :sigma_load, :R_wind_max,
    :X_delta_norm, :X_switch_ratio, :To_star]
const VOLATILE_METADATA_KEYS = Set(("signature", "sample_count", "created_at"))

function _canonical_value(value)
    value isa AbstractDict && return join(("$(key)=$(_canonical_value(value[key]))" for key ∈ sort!(collect(keys(value)))), ';')
    value isa AbstractVector && return join(_canonical_value.(value), ',')
    string(value)
end

function _canonical_payload(metadata::AbstractDict)
    keys_to_use = sort!(String.(collect(keys(metadata))))
    join(("$key=$(_canonical_value(metadata[key]))" for key ∈ keys_to_use if key ∉ VOLATILE_METADATA_KEYS), '\n')
end

case_signature(metadata::AbstractDict) = bytes2hex(sha256(codeunits(_canonical_payload(metadata))))

function array_sha256(array)
    values = Float64.(vec(array))
    bytes2hex(sha256(reinterpret(UInt8, values)))
end

function _file_sha256(path::AbstractString)
    isfile(path) || throw(ArgumentError("Training-cache input file not found: $path"))
    bytes2hex(sha256(read(path)))
end

function build_case_metadata(; input_file::AbstractString, load_profile::AbstractString, solver::AbstractString,
        network_constraints::AbstractString, window_hours::Integer, intervals::Integer,
        min_overlap::Integer, max_overlap::Integer, dimensions::AbstractDict,
        load_curve, wind_curve, training_mode::AbstractString = "sweep")
    metadata = Dict{String, String}(
        "cache_schema_version" => CACHE_SCHEMA_VERSION,
        "input_file_sha256" => _file_sha256(input_file),
        "load_profile" => lowercase(strip(load_profile)),
        "solver" => lowercase(strip(solver)),
        "network_constraints" => string(network_constraints),
        "window_hours" => string(window_hours),
        "intervals" => string(intervals),
        "min_overlap" => string(min_overlap),
        "max_overlap" => string(max_overlap),
        "training_mode" => lowercase(strip(training_mode)),
        "dimensions" => _canonical_value(Dict(string(key) => string(value) for (key, value) ∈ dimensions)),
        "load_curve_sha256" => array_sha256(load_curve),
        "wind_curve_sha256" => array_sha256(wind_curve))
    metadata["signature"] = case_signature(metadata)
    metadata
end

function cache_paths(cache_root::AbstractString, metadata::AbstractDict)
    signature = case_signature(metadata)
    directory = joinpath(cache_root, CACHE_DIRECTORY, signature)
    (directory = directory,
        dataset_path = joinpath(directory, "offline_training_dataset.csv"),
        metadata_path = joinpath(directory, "offline_training_dataset.meta.toml"))
end

function _metadata_matches(actual::AbstractDict, expected::AbstractDict)
    actual_signature = get(actual, "signature", "")
    actual_signature == case_signature(expected) && case_signature(actual) == case_signature(expected)
end

function load_cached_dataset(cache_root::AbstractString; expected_metadata::AbstractDict,
        required_columns = DEFAULT_REQUIRED_COLUMNS, min_samples::Integer = 1)
    paths = cache_paths(cache_root, expected_metadata)
    isfile(paths.dataset_path) && isfile(paths.metadata_path) || return nothing
    metadata = try
        TOML.parsefile(paths.metadata_path)
    catch
        return nothing
    end
    _metadata_matches(metadata, expected_metadata) || return nothing
    data = try
        CSV.read(paths.dataset_path, DataFrame)
    catch
        return nothing
    end
    required = Set(Symbol.(required_columns))
    required ⊆ Set(Symbol.(names(data))) || return nothing
    nrow(data) >= min_samples || return nothing
    data
end

function save_cached_dataset(cache_root::AbstractString, data::AbstractDataFrame, metadata::AbstractDict)
    paths = cache_paths(cache_root, metadata)
    mkpath(paths.directory)
    CSV.write(paths.dataset_path, data)
    stored = Dict{String, String}(String(key) => string(value) for (key, value) ∈ metadata)
    stored["signature"] = case_signature(metadata)
    stored["sample_count"] = string(nrow(data))
    stored["created_at"] = string(now())
    open(paths.metadata_path, "w") do io
        TOML.print(io, stored)
    end
    (dataset_path = paths.dataset_path, metadata_path = paths.metadata_path, signature = stored["signature"])
end

end
