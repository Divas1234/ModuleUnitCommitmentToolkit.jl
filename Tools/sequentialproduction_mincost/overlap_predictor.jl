module OverlapPredictor

using CSV, DataFrames, Statistics, Printf

export DecisionNode, train_model, predict_overlap, load_trained_model_or_fallback

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
const GLOBAL_MODEL = Ref{Union{DecisionNode, Nothing}}(nothing)

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
function fit_tree(X::Matrix{Float64}, Y::Vector{Float64}, depth::Int; max_depth::Int = 3, min_samples::Int = 5)::DecisionNode
    n_samples, n_features = size(X)
    
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
            thresh = (unique_vals[i] + unique_vals[i+1]) / 2.0
            
            left_idx = findall(v -> v <= thresh, feat_vals)
            right_idx = findall(v -> v > thresh, feat_vals)
            
            if length(left_idx) < 2 || length(right_idx) < 2
                continue
            end
            
            # Compute MSE of split
            left_y = Y[left_idx]
            right_y = Y[right_idx]
            mse = sum((left_y .- mean(left_y)).^2) + sum((right_y .- mean(right_y)).^2)
            
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
    left_child = fit_tree(X[best_left_idx, :], Y[best_left_idx], depth + 1, max_depth=max_depth, min_samples=min_samples)
    right_child = fit_tree(X[best_right_idx, :], Y[best_right_idx], depth + 1, max_depth=max_depth, min_samples=min_samples)
    
    return DecisionNode(best_feat, best_thresh, 0.0, left_child, right_child)
end

# Print the Decision Tree to console for debugging
function print_tree(node::DecisionNode, feature_names::Vector{String}, indent::String = "")
    if node.feature_idx == 0
        println(indent, "=> Prediction: ", round(node.value, digits=2))
        return
    end
    println(indent, "Split: ", feature_names[node.feature_idx], " <= ", round(node.threshold, digits=4))
    print(indent, "  L: ")
    print_tree(node.left, feature_names, indent * "    ")
    print(indent, "  R: ")
    print_tree(node.right, feature_names, indent * "    ")
end

# Train the CART decision tree from the generated CSV
function train_model(csv_path::String; max_depth::Int = 3, min_samples::Int = 5)
    println("Training Decision Tree on: ", csv_path)
    if !isfile(csv_path)
        error("Training dataset CSV not found at: $csv_path")
    end
    
    df = CSV.read(csv_path, DataFrame)
    
    feature_names = [
        "x0_1", "x0_2", "x0_3",
        "t0_1", "t0_2", "t0_3",
        "t1_1", "t1_2", "t1_3",
        "L_norm", "sigma_load", "R_wind_max"
    ]
    
    # Extract X (features) and Y (target optimal overlap)
    X = Matrix{Float64}(df[:, feature_names])
    Y = Vector{Float64}(df.To_star)
    
    # Fit the CART tree
    tree = fit_tree(X, Y, 0, max_depth=max_depth, min_samples=min_samples)
    GLOBAL_MODEL[] = tree
    
    println("Model training complete. Trained Tree Structure:")
    print_tree(tree, feature_names)
    
    # Evaluate R^2 score
    Y_pred = [predict_tree(tree, X[i, :]) for i in 1:size(X, 1)]
    y_mean = mean(Y)
    ss_tot = sum((Y .- y_mean).^2)
    ss_res = sum((Y .- Y_pred).^2)
    r2 = ss_tot > 0 ? 1.0 - (ss_res / ss_tot) : 1.0
    println(@sprintf("R^2 score on training data: %.4f", r2))
    
    return tree
end

# Pre-trained fallback model structure based on typical power system rules
# Splitting rule: If L_norm <= 0.18, To = 6 (low net load). Else if R_wind_max > 0.05, To = 10 (rampy). Else To = 8.
function get_fallback_tree()::DecisionNode
    # Features indices: L_norm = 10, R_wind_max = 12
    # Node 1: split on L_norm <= 0.18
    #   Left: prediction 6.0
    #   Right: split on R_wind_max <= 0.05
    #     Right-Left: prediction 8.0
    #     Right-Right: prediction 10.0
    right_right = DecisionNode(10.0)
    right_left = DecisionNode(8.0)
    right_node = DecisionNode(12, 0.05, 0.0, right_left, right_right)
    left_node = DecisionNode(6.0)
    
    return DecisionNode(10, 0.18, 0.0, left_node, right_node)
end

# Loader helper
function load_trained_model_or_fallback(csv_path::String = "d:/GithubClonefiles/module_unitcommitment/output/details_schedule_results/offline_training_dataset.csv")
    if GLOBAL_MODEL[] !== nothing
        return GLOBAL_MODEL[]
    end
    
    if isfile(csv_path)
        try
            return train_model(csv_path)
        catch e
            println("  Warning: Failed to train decision tree from dataset. Falling back to default heuristic.")
        end
    else
        println("  Info: Offline training dataset CSV not found. Loading pre-trained fallback decision model.")
    end
    
    GLOBAL_MODEL[] = get_fallback_tree()
    return GLOBAL_MODEL[]
end

# Inline inference function
function predict_overlap(features::Vector{Float64}; min_overlap::Int = 2, max_overlap::Int = 12)::Int
    model = load_trained_model_or_fallback()
    pred_val = predict_tree(model, features)
    pred_int = clamp(Int(round(pred_val)), min_overlap, max_overlap)
    return pred_int
end

end # module
