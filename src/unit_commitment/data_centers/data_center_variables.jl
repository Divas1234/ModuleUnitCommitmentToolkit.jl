"""
	define_data_center_variables!(model, time_count, data_center_count, scenario_count; binary_response_weights)

Create data-center response variables.

`binary_response_weights=true` gives the exact mixed-integer piecewise response
used by the extensive-form benchmark and CCG recourse/master models.

`binary_response_weights=false` gives the LP relaxation required by classical
Benders subproblems so that dual multipliers and optimality cuts are well-defined.
"""
function define_data_center_variables!(model::Model, time_count::Int, data_center_count::Int, scenario_count::Int; binary_response_weights::Bool = true)
	if data_center_count <= 0
		return nothing
	end
	num_breakpoints = data_center_num_breakpoints()
	rows = data_center_count * scenario_count
	@variable(model, dc_p[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²λ[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²_plus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²_minus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²_2_plus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²_2_minus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²λ_plus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²λ_minus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²λ_2_plus[1:rows, 1:time_count] >= 0)
	@variable(model, dc_fv²λ_2_minus[1:rows, 1:time_count] >= 0)

	if binary_response_weights
		@variable(model, weight_fv²_plus[1:rows, 1:time_count, 1:num_breakpoints], Bin)
		@variable(model, weight_fv²_minus[1:rows, 1:time_count, 1:num_breakpoints], Bin)
		@variable(model, weight_fv²λ_plus[1:rows, 1:time_count, 1:num_breakpoints], Bin)
		@variable(model, weight_fv²λ_minus[1:rows, 1:time_count, 1:num_breakpoints], Bin)
	else
		@variable(model, 0 <= weight_fv²_plus[1:rows, 1:time_count, 1:num_breakpoints] <= 1)
		@variable(model, 0 <= weight_fv²_minus[1:rows, 1:time_count, 1:num_breakpoints] <= 1)
		@variable(model, 0 <= weight_fv²λ_plus[1:rows, 1:time_count, 1:num_breakpoints] <= 1)
		@variable(model, 0 <= weight_fv²λ_minus[1:rows, 1:time_count, 1:num_breakpoints] <= 1)
	end
	return num_breakpoints
end
