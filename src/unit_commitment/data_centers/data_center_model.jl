const DATA_CENTER_RESPONSE_VARIABLES = (
    :dc_p, :dc_fv², :dc_fv²λ, :dc_fv²_plus, :dc_fv²_minus, :dc_fv²_2_plus, :dc_fv²_2_minus, :dc_fv²λ_plus, :dc_fv²λ_minus,
    :dc_fv²λ_2_plus, :dc_fv²λ_2_minus, :weight_fv²_plus, :weight_fv²_minus, :weight_fv²λ_plus, :weight_fv²λ_minus)

function require_data_center_variables!(model::Model)
    missing = [name for name ∈ DATA_CENTER_RESPONSE_VARIABLES if !haskey(JuMP.object_dictionary(model), name)]
    if !isempty(missing)
        error("Data center variables are missing from model: $(join(string.(missing), ", "))")
    end
    return nothing
end

function data_center_variable_refs(model::Model)
    return (power = model[:dc_p], fv2 = model[:dc_fv²], fv2lambda = model[:dc_fv²λ], fv2_plus = model[:dc_fv²_plus],
        fv2_minus = model[:dc_fv²_minus], fv2_square_plus = model[:dc_fv²_2_plus], fv2_square_minus = model[:dc_fv²_2_minus],
        fv2lambda_plus = model[:dc_fv²λ_plus], fv2lambda_minus = model[:dc_fv²λ_minus], fv2lambda_square_plus = model[:dc_fv²λ_2_plus],
        fv2lambda_square_minus = model[:dc_fv²λ_2_minus], weight_fv2_plus = model[:weight_fv²_plus], weight_fv2_minus = model[:weight_fv²_minus],
        weight_fv2lambda_plus = model[:weight_fv²λ_plus], weight_fv2lambda_minus = model[:weight_fv²λ_minus])
end

function add_data_center_power_constraints!(
        model::Model, variables, DataCentras, workload::AbstractMatrix, scenario_count::Int, time_count::Int, data_center_count::Int)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.power[(s - 1) * data_center_count + dc, t] <= DataCentras.p_max[dc])
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.power[(s - 1) * data_center_count + dc, t] >= 0.0)

    # Active-response power model from the reference datacentra_uc case:
    # P_dc = idle + service_constant / efficiency * workload * (f * v^2 * lambda).
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.power[(s - 1) * data_center_count + dc, t] ==
        DataCentras.idale[dc] +
        DataCentras.sv_constant[dc] / DataCentras.μ[dc] * workload[dc, t] * variables.fv2lambda[(s - 1) * data_center_count + dc, t])
    return nothing
end

function add_data_center_grid_bound_constraints!(model::Model, variables, response_grid, scenario_count::Int, time_count::Int, data_center_count::Int)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        response_grid.fv2_plus_lb[dc] <= variables.fv2_plus[(s - 1) * data_center_count + dc, t] <= response_grid.fv2_plus_ub[dc])
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        response_grid.fv2_minus_lb[dc] <= variables.fv2_minus[(s - 1) * data_center_count + dc, t] <= response_grid.fv2_minus_ub[dc])
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        response_grid.fv2lambda_plus_lb[dc] <= variables.fv2lambda_plus[(s - 1) * data_center_count + dc, t] <= response_grid.fv2lambda_plus_ub[dc])
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        response_grid.fv2lambda_minus_lb[dc] <=
        variables.fv2lambda_minus[(s - 1) * data_center_count + dc, t] <=
        response_grid.fv2lambda_minus_ub[dc])
    return nothing
end

function add_square_difference_reconstruction_constraints!(model::Model, variables, scenario_count::Int, time_count::Int, data_center_count::Int)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.fv2[(s - 1) * data_center_count + dc, t] ==
        variables.fv2_square_plus[(s - 1) * data_center_count + dc, t] - variables.fv2_square_minus[(s - 1) * data_center_count + dc, t])
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.fv2lambda[(s - 1) * data_center_count + dc, t] ==
        variables.fv2lambda_square_plus[(s - 1) * data_center_count + dc, t] - variables.fv2lambda_square_minus[(s - 1) * data_center_count + dc, t])
    return nothing
end

function add_convex_grid_reconstruction_constraints!(
        model::Model, variables, response_grid, scenario_count::Int, time_count::Int, data_center_count::Int, num_breakpoints::Int)
    function add_grid_pair!(value_var, square_var, grid_points, square_grid_points, weight_var)
        @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
            value_var[(s - 1) * data_center_count + dc, t] ==
            sum(grid_points[k] * weight_var[(s - 1) * data_center_count + dc, t, k] for k ∈ 1:num_breakpoints))
        @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
            square_var[(s - 1) * data_center_count + dc, t] ==
            sum(square_grid_points[k] * weight_var[(s - 1) * data_center_count + dc, t, k] for k ∈ 1:num_breakpoints))
        @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
            sum(weight_var[(s - 1) * data_center_count + dc, t, k] for k ∈ 1:num_breakpoints) == 1)
    end

    add_grid_pair!(
        variables.fv2_plus, variables.fv2_square_plus, response_grid.fv2_plus_grid, response_grid.fv2_2_plus_grid, variables.weight_fv2_plus)
    add_grid_pair!(
        variables.fv2_minus, variables.fv2_square_minus, response_grid.fv2_minus_grid, response_grid.fv2_2_minus_grid, variables.weight_fv2_minus)
    add_grid_pair!(variables.fv2lambda_plus, variables.fv2lambda_square_plus, response_grid.fv2lambda_plus_grid,
        response_grid.fv2lambda_2_plus_grid, variables.weight_fv2lambda_plus)
    add_grid_pair!(variables.fv2lambda_minus, variables.fv2lambda_square_minus, response_grid.fv2lambda_minus_grid,
        response_grid.fv2lambda_2_minus_grid, variables.weight_fv2lambda_minus)
    return nothing
end

function add_data_center_response_band_constraints!(model::Model, variables, scenario_count::Int, time_count::Int, data_center_count::Int)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count], variables.fv2[(s - 1) * data_center_count + dc, t] <= 1.5)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.fv2lambda[(s - 1) * data_center_count + dc, t] <= 1.5)
    @constraint(model, [s = 1:scenario_count, t = 1:time_count, dc = 1:data_center_count],
        variables.fv2lambda[(s - 1) * data_center_count + dc, t] <= 1.05 * variables.fv2[(s - 1) * data_center_count + dc, t])

    for block ∈ data_center_time_blocks(time_count)
        @constraint(model, [s = 1:scenario_count],
            sum(variables.fv2lambda[(s - 1) * data_center_count + dc, t] for dc ∈ 1:data_center_count, t ∈ block.first:block.last) <=
            1.05 * sum(variables.fv2[(s - 1) * data_center_count + dc, t] for dc ∈ 1:data_center_count, t ∈ block.first:block.last))
        @constraint(model, [s = 1:scenario_count],
            sum(variables.fv2lambda[(s - 1) * data_center_count + dc, t] for dc ∈ 1:data_center_count, t ∈ block.first:block.last) >=
            0.95 * sum(variables.fv2[(s - 1) * data_center_count + dc, t] for dc ∈ 1:data_center_count, t ∈ block.first:block.last))
    end
    return nothing
end

"""
    add_data_center_response_constraints!(model, data_centers, config, scenario_count, time_count, data_center_count)

Attach the data-center response model. The formulation is shared by benchmark
UC, CCG, and Benders; the variable declaration controls whether the grid weights
are binary (exact MIP) or continuous (Benders LP relaxation).
"""
function add_data_center_response_constraints!(model::Model, DataCentras, config_param, scenario_count::Int, time_count::Int, data_center_count::Int)
    if config_param.is_ConsiderDataCentra != 1 || data_center_count <= 0
        return nothing
    end

    require_data_center_variables!(model)
    variables = data_center_variable_refs(model)
    num_breakpoints = size(variables.weight_fv2_plus, 3)
    response_grid = build_data_center_response_grid(num_breakpoints, data_center_count)
    workload = validate_data_center_configuration(DataCentras, time_count, data_center_count)

    add_data_center_power_constraints!(model, variables, DataCentras, workload, scenario_count, time_count, data_center_count)
    add_data_center_grid_bound_constraints!(model, variables, response_grid, scenario_count, time_count, data_center_count)
    add_square_difference_reconstruction_constraints!(model, variables, scenario_count, time_count, data_center_count)
    add_convex_grid_reconstruction_constraints!(model, variables, response_grid, scenario_count, time_count, data_center_count, num_breakpoints)
    add_data_center_response_band_constraints!(model, variables, scenario_count, time_count, data_center_count)

    println("\t constraints: 12) data centra constraints\t\t\t\t done")
    return nothing
end
