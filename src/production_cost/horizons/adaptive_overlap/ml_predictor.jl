module OverlapPredictor

using CSV, DataFrames, Statistics, Printf
using ..AdaptiveOverlapTrainingCache

export DecisionNode, train_model, predict_overlap, load_trained_model_or_fallback, configure_training_cache!

# Decision Tree Node structure
struct DecisionNode
    feature_idx::Int             # Index of the split feature (0 if leaf)
    threshold::Float64           # Split threshold
    value::Float64               # Predicted value (only used if leaf)
    left::Union{DecisionNode, Nothing}
    right::Union{DecisionNode, Nothing}
end

# Leaf node constructor
DecisionNode(val::Float64) = DecisionNode(0, 0.0, val, nothing, nothing)

# In-memory global model reference
const _PREDICTOR_LOCK = ReentrantLock()
const GLOBAL_MODEL = Ref{Union{DecisionNode, Nothing}}(nothing)
const TRAINING_CACHE_ROOT = Ref{Union{Nothing, String}}(nothing)
const EXPECTED_TRAINING_METADATA = Ref{Any}(nothing)

function configure_training_cache!(cache_root::AbstractString, expected_metadata::AbstractDict)
    lock(_PREDICTOR_LOCK) do
        TRAINING_CACHE_ROOT[] = String(cache_root)
        EXPECTED_TRAINING_METADATA[] = Dict{String, String}(String(key) => string(value) for (key, value) in expected_metadata)
        GLOBAL_MODEL[] = nothing
    end
    return nothing
end

# Predict using a DecisionNode
function predict_tree(node::DecisionNode, x::Vector{Float64})::Float64
    if node.feature_idx == 0
        return node.value
    end
    if x[node.feature_idx] <= node.threshold
        return predict_tree(node.left, x)
    else
        return predict_tree(node.right, x)
    end
end

# Fit a Decision Tree recursively
function fit_tree(X::Matrix{Float64}, Y::Vector{Float64}, depth::Int; max_depth::Int = 3, min_samples::Int = 4)::DecisionNode
    n_samples, n_features = size(X)
    n_samples > 0 || throw(ArgumentError("Cannot fit decision tree on empty training set."))

    # Base cases: leaf node conditions
    if depth >= max_depth || n_samples < min_samples || all(Y .== Y[1])
        return DecisionNode(mean(Y))
    end

    best_mse = Inf
    best_feat = 0
    best_thresh = 0.0
    best_left_idx = Int[]
    best_right_idx = Int[]

    # Scan all features and thresholds to minimize sum of squared errors
    for f in 1:n_features
        feat_vals = X[:, f]
        unique_vals = unique(feat_vals)
        sort!(unique_vals)

        # Test split thresholds at midpoints
        for i in 1:(length(unique_vals) - 1)
            thresh = (unique_vals[i] + unique_vals[i + 1]) / 2.0

            left_idx = findall(v -> v <= thresh, feat_vals)
            right_idx = findall(v -> v > thresh, feat_vals)

            if length(left_idx) < 2 || length(right_idx) < 2
                continue
            end

            # Compute MSE of split
            left_y = Y[left_idx]
            right_y = Y[right_idx]
            mse = sum((left_y .- mean(left_y)) .^ 2) + sum((right_y .- mean(right_y)) .^ 2)

            if mse < best_mse
                best_mse = mse
                best_feat = f
                best_thresh = thresh
                best_left_idx = left_idx
                best_right_idx = right_idx
            end
        end
    end

    # If no split improves MSE, return leaf
    if best_feat == 0
        return DecisionNode(mean(Y))
    end

    # Recursively build subtrees
    left_child = fit_tree(X[best_left_idx, :], Y[best_left_idx], depth + 1; max_depth = max_depth, min_samples = min_samples)
    right_child = fit_tree(X[best_right_idx, :], Y[best_right_idx], depth + 1; max_depth = max_depth, min_samples = min_samples)

    return DecisionNode(best_feat, best_thresh, 0.0, left_child, right_child)
end

# Print the Decision Tree to console for debugging
function print_tree(node::DecisionNode, feature_names::Vector{String}, indent::String = "")
    if node.feature_idx == 0
        println(indent, "=> Prediction: ", round(node.value; digits = 2))
        return
    end
    println(indent, "Split: ", feature_names[node.feature_idx], " <= ", round(node.threshold; digits = 4))
    print(indent, "  L: ")
    print_tree(node.left, feature_names, indent * "    ")
    print(indent, "  R: ")
    return print_tree(node.right, feature_names, indent * "    ")
end

# Train the CART decision tree from the generated CSV
function train_model(csv_path::String; max_depth::Int = 3, min_samples::Int = 4)
    println("Training Decision Tree on: ", csv_path)
    if !isfile(csv_path)
        error("Training dataset CSV not found at: $csv_path")
    end

    df = CSV.read(csv_path, DataFrame)

    # System-independent features. The last two columns describe how much the
    # inherited rolling-boundary commitment differs from the base initial state.
    feature_names = ["U_norm", "T_dwell_rem", "L_norm", "sigma_load", "R_wind_max", "X_delta_norm", "X_switch_ratio"]

    missing_cols = setdiff([feature_names; ["To_star"]], names(df))
    if !isempty(missing_cols)
        error("Training dataset is missing required columns: $(join(missing_cols, ", "))")
    end

    # Extract X (features) and Y (target optimal overlap), filtering missing/non-finite rows before Float64 conversion
    required_cols = [feature_names; ["To_star"]]
    complete_rows = [all(col -> !ismissing(df[i, col]) && df[i, col] isa Real && isfinite(Float64(df[i, col])), required_cols) for i in 1:nrow(df)]
    df_valid = df[complete_rows, :]
    if nrow(df_valid) < min_samples
        error("Training dataset has only $(nrow(df_valid)) valid rows; at least $min_samples are required.")
    end
    X = Matrix{Float64}(df_valid[:, feature_names])
    Y = Vector{Float64}(df_valid.To_star)

    # Fit the CART tree
    tree = fit_tree(X, Y, 0; max_depth = max_depth, min_samples = min_samples)
    lock(_PREDICTOR_LOCK) do
        GLOBAL_MODEL[] = tree
    end

    println("Model training complete. Trained Tree Structure:")
    print_tree(tree, feature_names)

    # Evaluate R^2 score
    Y_pred = [predict_tree(tree, X[i, :]) for i in eachindex(X[:, 1])]
    y_mean = mean(Y)
    ss_tot = sum((Y .- y_mean) .^ 2)
    ss_res = sum((Y .- Y_pred) .^ 2)
    r2 = ss_tot > 0 ? 1.0 - (ss_res / ss_tot) : 1.0
    println(@sprintf("R^2 score on training data: %.4f", r2))

    return tree
end

# Loader helper
function _configured_dataset_path(csv_path::AbstractString)
    expected, configured_root = lock(_PREDICTOR_LOCK) do
        EXPECTED_TRAINING_METADATA[], TRAINING_CACHE_ROOT[]
    end
    expected === nothing && return isfile(csv_path) ? csv_path : nothing
    cache_root = configured_root === nothing ? dirname(csv_path) : configured_root
    cached = AdaptiveOverlapTrainingCache.load_cached_dataset(
        cache_root;
        expected_metadata = expected,
        required_columns = [:U_norm, :T_dwell_rem, :L_norm, :sigma_load, :R_wind_max, :X_delta_norm, :X_switch_ratio, :To_star],
        min_samples = 4,
    )
    return cached === nothing ? nothing : AdaptiveOverlapTrainingCache.cache_paths(cache_root, expected).dataset_path
end

function load_trained_model_or_fallback(
    csv_path::String = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "output", "details_schedule_results", "offline_training_dataset.csv")),
)
    existing = lock(_PREDICTOR_LOCK) do
        GLOBAL_MODEL[]
    end
    if existing !== nothing
        return existing
    end

    dataset_path = _configured_dataset_path(csv_path)
    if dataset_path !== nothing
        try
            println("  Training cache hit: $(dataset_path)")
            return train_model(dataset_path)
        catch e
            error("Compatible ML dataset exists but model training failed: $(sprint(showerror, e)). Fallback is disabled.")
        end
    else
        error("No compatible ML training dataset is available. Generate it in output/ml_trainningdata_res; fallback is disabled.")
    end
end

# Inline inference function
function predict_overlap(features::Vector{Float64}; min_overlap::Int = 2, max_overlap::Int = 12)::Int
    all(isfinite, features) || throw(ArgumentError("ML overlap features contain non-finite values: $features"))
    model = load_trained_model_or_fallback()
    pred_val = predict_tree(model, features)
    if !isfinite(pred_val)
        error("ML overlap model produced a non-finite prediction: $pred_val. Fallback is disabled.")
    end
    pred_int = clamp(Int(round(pred_val)), min_overlap, max_overlap)
    return pred_int
end

end # module
