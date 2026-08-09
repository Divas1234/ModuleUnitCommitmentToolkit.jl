using TOML

const DEFAULT_RUNTIME_CONFIG_PATH = joinpath(dirname(@__DIR__), "config", "runtime_config.toml")

"""
    runtime_config_value_to_env(value)

Convert a TOML scalar into the string representation expected by `ENV`.

The optimization drivers still read runtime options from `ENV` so that batch
jobs, CI, and shell-level overrides can use one consistent interface. The TOML
loader is intentionally a thin compatibility layer: it validates supported
scalar types and leaves domain-specific parsing to each algorithm module.
"""
function runtime_config_value_to_env(value)
    if value isa Bool
        return value ? "1" : "0"
    elseif value isa AbstractString
        return String(value)
    elseif value isa Integer || value isa AbstractFloat
        return string(value)
    else
        throw(ArgumentError("Unsupported runtime config value type: $(typeof(value))"))
    end
end

"""
    collect_runtime_config_entries!(entries, table)

Flatten a nested TOML table into `ENV` key-value pairs.

Only leaf keys are exported. Section names such as `[benders.cuts]` are used for
human organization in the TOML file and are not prefixed onto the final ENV key.
This keeps the public variable names stable, e.g. `BENDERS_MAX_ITERATIONS`.
"""
function collect_runtime_config_entries!(entries::Vector{Pair{String, String}}, table)
    for (key, value) ∈ table
        if value isa AbstractDict
            collect_runtime_config_entries!(entries, value)
        else
            push!(entries, String(key) => runtime_config_value_to_env(value))
        end
    end
    return entries
end

"""
    runtime_config_entries(config_path)

Parse and validate a runtime TOML file without mutating process state.
Use this function in tests or diagnostics when the caller only needs to inspect
what would be exported to `ENV`.
"""
function runtime_config_entries(config_path::AbstractString)
    isfile(config_path) || throw(ArgumentError("Runtime config file not found: $config_path"))
    config = TOML.parsefile(config_path)
    entries = Pair{String, String}[]
    collect_runtime_config_entries!(entries, config)
    return entries
end

"""
    load_runtime_config!(; config_path, override, verbose)

Load runtime defaults from TOML into `ENV`.

Precedence is production-oriented:

  - existing shell/CI environment variables win by default;
  - TOML values fill in missing variables;
  - `override=true` is reserved for tests or controlled experiments.

Blank TOML strings are treated as "unset" sentinels. This is useful for options
such as `CCG_INITIAL_SCENARIOS`, where an empty value means "derive a default
from the loaded scenario count" instead of forcing a literal empty string.
"""
function load_runtime_config!(; config_path::AbstractString = get(ENV, "MODULE_UC_CONFIG_FILE", DEFAULT_RUNTIME_CONFIG_PATH),
        override::Bool = false, verbose::Bool = get(ENV, "MODULE_UC_CONFIG_VERBOSE", "0") in ("1", "true", "yes", "on"))
    entries = runtime_config_entries(config_path)
    applied = String[]
    skipped = String[]

    for (key, value) ∈ entries
        if isempty(value)
            continue
        end
        if !override && haskey(ENV, key)
            push!(skipped, key)
            continue
        end
        ENV[key] = value
        push!(applied, key)
    end

    if verbose
        println("Runtime config loaded: ", config_path)
        println("  applied: ", sort(applied))
        println("  preserved existing ENV: ", sort(skipped))
    end
    return (config_path = config_path, applied = applied, skipped = skipped)
end
