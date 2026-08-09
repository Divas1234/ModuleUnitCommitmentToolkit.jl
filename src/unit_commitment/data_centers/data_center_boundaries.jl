"""
    data_center_num_breakpoints()

Number of discrete breakpoints used by the data-center response approximation.
The reference case uses five points; keeping this configurable makes sensitivity
checks easy without changing the model code.
"""
function data_center_num_breakpoints()
    return max(2, Int(round(parse(Float64, get(ENV, "DATA_CENTER_NUM_SOS", "5")))))
end

data_center_sos_count() = data_center_num_breakpoints()

"""
    build_data_center_response_grid(num_breakpoints, data_center_count)

Build the plus/minus square-difference grids used to approximate:

  - `fv2 = f * v^2`
  - `fv2lambda = fv2 * lambda`

The formulation follows the reference `datacentra_uc` littlecase:
`xy = ((x + y) / 2)^2 - ((x - y) / 2)^2`.
"""
function build_data_center_response_grid(num_breakpoints::Int, data_center_count::Int)
    frequency_lb = fill(0.50, data_center_count)
    frequency_ub = fill(1.50, data_center_count)
    voltage_lb = fill(0.85, data_center_count)
    voltage_ub = fill(1.50, data_center_count)
    voltage_squared_lb = voltage_lb .^ 2
    voltage_squared_ub = voltage_ub .^ 2

    fv2_plus_lb = 0.5 .* (frequency_lb .+ voltage_squared_lb)
    fv2_plus_ub = 0.5 .* (frequency_ub .+ voltage_squared_ub)
    fv2_minus_lb = 0.5 .* abs.(frequency_lb .- voltage_squared_lb)
    fv2_minus_ub = 0.5 .* abs.(frequency_ub .- voltage_squared_ub)

    lambda_lb = fill(0.50, data_center_count)
    lambda_ub = fill(1.50, data_center_count)
    fv2lambda_plus_lb = 0.5 .* (fv2_plus_lb .+ lambda_lb)
    fv2lambda_plus_ub = 0.5 .* (fv2_plus_ub .+ lambda_ub)
    fv2lambda_minus_lb = 0.5 .* abs.(fv2_minus_lb .- lambda_lb)
    fv2lambda_minus_ub = 0.5 .* abs.(fv2_minus_ub .- lambda_ub)

    fv2_plus_grid = collect(range(fv2_plus_lb[1], fv2_plus_ub[1]; length = num_breakpoints))
    fv2_minus_grid = collect(range(fv2_minus_lb[1], fv2_minus_ub[1]; length = num_breakpoints))
    fv2lambda_plus_grid = collect(range(fv2lambda_plus_lb[1], fv2lambda_plus_ub[1]; length = num_breakpoints))
    fv2lambda_minus_grid = collect(range(fv2lambda_minus_lb[1], fv2lambda_minus_ub[1]; length = num_breakpoints))

    return (fv2_plus_lb = fv2_plus_lb, fv2_plus_ub = fv2_plus_ub, fv2_minus_lb = fv2_minus_lb, fv2_minus_ub = fv2_minus_ub,
        fv2lambda_plus_lb = fv2lambda_plus_lb, fv2lambda_plus_ub = fv2lambda_plus_ub, fv2lambda_minus_lb = fv2lambda_minus_lb,
        fv2lambda_minus_ub = fv2lambda_minus_ub, fv2_plus_grid = fv2_plus_grid, fv2_minus_grid = fv2_minus_grid,
        fv2lambda_plus_grid = fv2lambda_plus_grid, fv2lambda_minus_grid = fv2lambda_minus_grid, fv2_2_plus_grid = fv2_plus_grid .^ 2,
        fv2_2_minus_grid = fv2_minus_grid .^ 2, fv2lambda_2_plus_grid = fv2lambda_plus_grid .^ 2, fv2lambda_2_minus_grid = fv2lambda_minus_grid .^ 2)
end

get_data_center_boundaries(num_sos::Int, ND2::Int) = build_data_center_response_grid(num_sos, ND2)
