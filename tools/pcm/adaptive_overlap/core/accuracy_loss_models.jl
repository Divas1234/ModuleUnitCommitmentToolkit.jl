# 调度精度损失模型
# 定义损失模型参数、预测接口及轻量神经网络训练。

"""
		TrainedLossModels

	A structure holding the calibrated parameters for regression and neural network models
	mapping normalized load, online capacity, boundary commitment deviation, and
	overlap size to subproblem solving accuracy loss.
	"""

mutable struct TrainedLossModels
    mode::String
    beta::Vector{Float64}
    W1::Matrix{Float64}
    b1::Vector{Float64}
    W2::Matrix{Float64}
    b2::Float64
end

function TrainedLossModels(mode::String = "decay")
    # Default pre-set parameters
    # Regression features are:
    # [1, L_norm, U_norm, X_delta_norm, X_switch_ratio, H].
    # X_delta_norm and X_switch_ratio quantify how much the current
    # rolling-boundary commitment differs from the base initial state.
    beta = [-0.5, 0.8, -0.4, 0.6, 0.4, -0.3]
    W1 = [     0.5   0.2   0.4   0.2  -1.2;
          -0.3   0.4   0.3   0.1  -0.8;
           0.7  -0.5   0.5   0.2  -1.5;
          -0.2  -0.3   0.4   0.3  -1.0]
    b1 = [0.1, -0.2, 0.3, 0.0]
    W2 = [0.4 0.3 0.5 0.6]
    b2 = -0.1
    return TrainedLossModels(mode, beta, W1, b1, W2, b2)
end

"""
    predict_accuracy_loss_neural_network(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64)

Evaluate a pre-trained feedforward neural network (1 hidden layer of 4 neurons)
mapping normalized load level, normalized online unit capacity, boundary-state
deviation, and candidate overlap window H to the predicted subproblem solving
accuracy loss.
"""
function predict_accuracy_loss_neural_network(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64)
    # Inputs: normalized load, online capacity, boundary-state deviation,
    # switched-unit ratio, normalized overlap window H (H/12).
    x = [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H) / 12.0]

    # Predefined weights and biases (representing typical sensitivity characteristics)
    W1 = [     0.5   0.2   0.4   0.2  -1.2;
          -0.3   0.4   0.3   0.1  -0.8;
           0.7  -0.5   0.5   0.2  -1.5;
          -0.2  -0.3   0.4   0.3  -1.0]
    b1 = [0.1, -0.2, 0.3, 0.0]
    W2 = [0.4 0.3 0.5 0.6]
    b2 = -0.1

    hidden = tanh.(W1 * x + b1)
    output_raw = (W2 * hidden)[1] + b2
    loss = 1.0 / (1.0 + exp(-output_raw))
    return loss
end

"""
    predict_accuracy_loss_neural_network_custom(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64, models::TrainedLossModels)

Evaluate neural network using calibrated weights.
"""
function predict_accuracy_loss_neural_network_custom(
        L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64, models::TrainedLossModels)
    x = [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H) / 12.0]
    hidden = tanh.(models.W1 * x + models.b1)
    output_raw = (models.W2 * hidden)[1] + models.b2
    loss = 1.0 / (1.0 + exp(-output_raw))
    return loss
end

"""
    train_neural_network_backprop(X_data::Matrix{Float64}, Y_data::Vector{Float64}; epochs=600, lr=0.05)

Simple gradient descent backpropagation to train feedforward neural network weights.
"""
function train_neural_network_backprop(X_data::Matrix{Float64}, Y_data::Vector{Float64}; epochs = 600, lr = 0.05)
    W1 = [     0.5   0.2   0.4   0.2  -1.2;
          -0.3   0.4   0.3   0.1  -0.8;
           0.7  -0.5   0.5   0.2  -1.5;
          -0.2  -0.3   0.4   0.3  -1.0]
    b1 = [0.1, -0.2, 0.3, 0.0]
    W2 = [0.4 0.3 0.5 0.6]
    b2 = -0.1

    N = size(X_data, 1)
    for epoch ∈ 1:epochs
        for i ∈ 1:N
            x = X_data[i, :]
            y = Y_data[i]

            # Forward
            h_raw = W1 * x + b1
            h = tanh.(h_raw)
            o_raw = (W2 * h)[1] + b2
            pred = 1.0 / (1.0 + exp(-o_raw))

            # Backward
            d_loss = pred - y
            d_o_raw = d_loss * pred * (1.0 - pred)

            d_W2 = d_o_raw .* h'
            d_b2 = d_o_raw

            d_h = W2' * d_o_raw
            d_h_raw = d_h .* (1.0 .- h .^ 2)

            d_W1 = d_h_raw * x'
            d_b1 = d_h_raw

            # Update
            W1 .-= lr .* d_W1
            b1 .-= lr .* d_b1
            W2 .-= lr .* d_W2
            b2 -= lr * d_b2
        end
    end
    return W1, b1, W2, b2
end
