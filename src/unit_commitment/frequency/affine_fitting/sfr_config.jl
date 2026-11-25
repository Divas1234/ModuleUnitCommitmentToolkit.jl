frequency_env_float(name::String, default::Float64) = uc_env_float(name, default)
frequency_env_bool(name::String, default::Bool) = uc_env_bool(name, default)

"""
    frequency_model_mode() -> Symbol

Return the active frequency-security modeling mode from `ENV["FREQUENCY_MODEL_MODE"]`:
- `:legacy`    — original 3-feature commitment-sampling affine nadir fitting (default)
- `:hd_region` — Inertia–Damping (H–D) Frequency Security Region linear cuts
- `:hybrid`    — apply both legacy and H–D region constraints together
"""
function frequency_model_mode()
    raw = lowercase(strip(get(ENV, "FREQUENCY_MODEL_MODE", "legacy")))
    if raw in ("legacy", "classic", "affine", "affine_fitting")
        return :legacy
    elseif raw in ("hd_region", "hd", "frsr", "hd_estimation")
        return :hd_region
    elseif raw in ("hybrid", "both")
        return :hybrid
    end
    throw(ArgumentError("Unsupported FREQUENCY_MODEL_MODE=$(raw); expected one of: affine_fitting (legacy), hd_region, hybrid"))
end

function frequency_contingency_size(units, Δp_contingency; use_env_override::Bool = true)
    contingency_fraction = use_env_override ? strip(get(ENV, "FREQUENCY_CONTINGENCY_FRACTION", "")) : ""
    raw_contingency = if isempty(contingency_fraction)
        Float64(Δp_contingency)
    else
        maximum(units.p_max) * parse(Float64, contingency_fraction)
    end
    imbalance_scaling = max(frequency_env_float("FREQUENCY_IMBALANCE_SCALING", 1.0), eps(Float64))
    return max(0.0, raw_contingency / imbalance_scaling)
end

function frequency_nadir_fit_contingency(units, fallback_contingency::Float64)
    fit_fraction = strip(get(ENV, "FREQUENCY_NADIR_FIT_CONTINGENCY_FRACTION", "1.0"))
    if isempty(fit_fraction)
        return fallback_contingency
    end
    return max(0.0, maximum(units.p_max) * parse(Float64, fit_fraction))
end

function parse_frequency_vector(text::String)
    return [parse(Float64, strip(value)) for value in split(text, ",") if !isempty(strip(value))]
end

function parse_frequency_matrix(text::String)
    rows = [parse_frequency_vector(row) for row in split(text, ";") if !isempty(strip(row))]
    if isempty(rows)
        return zeros(Float64, 0, 4)
    end
    row_width = length(rows[1])
    all(length(row) == row_width for row in rows) || throw(ArgumentError("FREQUENCY_NADIR_FITTING_PARAMETERS rows must have the same length"))
    return reduce(vcat, reshape(row, 1, row_width) for row in rows)
end
