using Gurobi
using JuMP
using MathOptInterface

function frequency_nadir_fitting_parameters(units, winds, contingency::Float64)
    parameter_text = strip(get(ENV, "FREQUENCY_NADIR_FITTING_PARAMETERS", ""))
    if !isempty(parameter_text)
        parameters = parse_frequency_matrix(parameter_text)
        size(parameters, 2) == 4 || throw(ArgumentError("FREQUENCY_NADIR_FITTING_PARAMETERS must contain rows of 4 comma-separated values"))
        return parameters
    end
    X, y = frequency_nadir_sampling_dataset(units, winds, contingency)
    method = lowercase(strip(get(ENV, "FREQUENCY_NADIR_FITTING_METHOD", "max_min_affine")))
    if method in ("least_squares", "ls", "ols")
        return fit_frequency_nadir_least_squares(X, y)
    elseif method in ("max_min_affine", "maxmin", "multi_cut", "multicut")
        return fit_frequency_nadir_max_min_affine(X, y)
    else
        throw(ArgumentError("Unsupported FREQUENCY_NADIR_FITTING_METHOD=$(method)"))
    end
end

function fit_frequency_nadir_least_squares(X::Matrix{Float64}, y::Vector{Float64})
    plane = X \ y
    if frequency_env_bool("FREQUENCY_NADIR_LS_UNDERESTIMATE", true)
        plane[4] -= max(0.0, maximum(X * plane .- y))
    end
    return reshape(collect(plane), 1, 4)
end

function fit_frequency_nadir_max_min_affine(X::Matrix{Float64}, y::Vector{Float64})
    row_count = size(X, 1)
    cut_count = min(row_count, max(1, floor(Int, frequency_env_float("FREQUENCY_NADIR_MAX_CUTS", 4.0))))
    big_m = max(maximum(abs.(y)) + 1.0, frequency_env_float("FREQUENCY_NADIR_FIT_BIG_M", 100.0))
    coefficient_bound = frequency_env_float("FREQUENCY_NADIR_COEFFICIENT_BOUND", 10.0)
    regularization = frequency_env_float("FREQUENCY_NADIR_COEFFICIENT_REGULARIZATION", 1.0e-3)
    fit_tolerance = frequency_env_float("FREQUENCY_NADIR_FIT_TOLERANCE", 0.0)

    fit_model = Model(Gurobi.Optimizer)
    set_silent(fit_model)
    set_optimizer_attribute(fit_model, "OutputFlag", 0)

    @variable(fit_model, -coefficient_bound <= coefficient[1:cut_count, 1:4] <= coefficient_bound)
    @variable(fit_model, coefficient_abs[1:cut_count, 1:4] >= 0.0)
    @variable(fit_model, selected_value[1:row_count])
    @variable(fit_model, fitting_error[1:row_count] >= 0.0)
    @variable(fit_model, max_error >= 0.0)
    @variable(fit_model, assignment[1:row_count, 1:cut_count], Bin)

    @constraint(fit_model, [k = 1:cut_count, j = 1:4], coefficient_abs[k, j] >= coefficient[k, j])
    @constraint(fit_model, [k = 1:cut_count, j = 1:4], coefficient_abs[k, j] >= -coefficient[k, j])
    @constraint(fit_model, [i = 1:row_count], sum(assignment[i, k] for k ∈ 1:cut_count) == 1)
    @constraint(fit_model, [k = 1:cut_count], sum(assignment[i, k] for i ∈ 1:row_count) >= 1)
    @constraint(fit_model, [i = 1:row_count, k = 1:cut_count], sum(coefficient[k, j] * X[i, j] for j ∈ 1:4) <= y[i])
    @constraint(fit_model, [i = 1:row_count, k = 1:cut_count],
        selected_value[i] <= sum(coefficient[k, j] * X[i, j] for j ∈ 1:4) + big_m * (1 - assignment[i, k]))
    @constraint(fit_model, [i = 1:row_count, k = 1:cut_count],
        selected_value[i] >= sum(coefficient[k, j] * X[i, j] for j ∈ 1:4) - big_m * (1 - assignment[i, k]))
    @constraint(fit_model, [i = 1:row_count], fitting_error[i] >= y[i] - selected_value[i])
    @constraint(fit_model, [i = 1:row_count], max_error >= fitting_error[i])
    if fit_tolerance > 0.0
        @constraint(fit_model, max_error <= fit_tolerance)
    end
    @objective(fit_model, Min,
        1.0e3 * max_error + sum(fitting_error[i] for i ∈ 1:row_count) + regularization * sum(coefficient_abs[k, j] for k ∈ 1:cut_count, j ∈ 1:4))

    optimize!(fit_model)
    if termination_status(fit_model) != MathOptInterface.OPTIMAL
        return fit_frequency_nadir_least_squares(X, y)
    end
    return Matrix(value.(coefficient))
end
