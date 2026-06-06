using JuMP

export add_unit_operation_constraints!, add_generator_power_constraints!, add_ramp_constraints!, add_pwl_constraints!

"""
`add_unit_operation_constraints!(...)`

Adds constraints related to unit commitment status, including minimum up/down time
limits, binary consistency logic, and startup/shutdown costs.

# Arguments

  - `scuc::Model`: The JuMP optimization model.
  - `NT`: Total number of time periods.
  - `NG`: Total number of thermal generators.
  - `units`: Unit data structure containing technical parameters.
  - `onoffinit`: Initial commitment status.

# Returns

  - A tuple containing the model and references to the newly created constraints.
"""
function add_unit_operation_constraints!(scuc::Model, NT, NG, units, onoffinit)
	# Retrieve decision variable references from the model
	x = scuc[:x]
	u = scuc[:u]
	v = scuc[:v]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]

	Lupmin = zeros(NG, 1)     # Minimum startup time
	Ldownmin = zeros(NG, 1)   # Minimum shutdown time

	for i in 1:NG
		# Uncomment if initial status is provided
		# onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
		# Calculate minimum up/down time limits
		Lupmin[i] = min(NT, units.min_shutup_time[i] * onoffinit[i])
		Ldownmin[i] = min(NT, (units.min_shutdown_time[i, 1]) * (1 - onoffinit[i]))
	end

	units_minuptime_constr = Vector{ConType}()
	units_mindowntime_constr = Vector{ConType}()

	# --- Minimum Up and Down Time Constraints ---
	for i in 1:NG
		# Minimum Up Time: If a unit starts, it must remain on for units.min_shutup_time
		for t in Int64(max(1, Lupmin[i])):NT
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			con = @constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t])
			push!(units_minuptime_constr, con)
		end

		# Minimum Down Time: If a unit stops, it must remain off for units.min_shutdown_time
		for t in Int64(max(1, Ldownmin[i])):NT
			LB = Int64(max(t - units.min_shutdown_time[i, 1] + 1, 1))
			con = @constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]))
			push!(units_mindowntime_constr, con)
		end
	end

	println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

	# --- Binary Variable Logic (State Transitions) ---
	# u[t] - v[t] = x[t] - x[t-1]
	units_init_stateslogic_consist_constr = @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))

	# Prevent simultaneous startup and shutdown
	units_states_consist_constr = @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)

	println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

	# --- Startup and Shutdown Costs (Linearization) ---
	shutupcost = units.coffi_cold_shutup_1
	shutdowncost = units.coffi_cold_shutdown_1
	units_init_shutup_cost_constr = @constraint(scuc, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
	units_init_shutdown_cost_costr = @constraint(scuc, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))
	units_shutup_cost_constr = @constraint(scuc, [t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
	units_shutdown_cost_constr = @constraint(scuc, [t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])

	println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")
	return scuc, units_minuptime_constr, units_mindowntime_constr, units_init_stateslogic_consist_constr, units_states_consist_constr, units_init_shutup_cost_constr, units_init_shutdown_cost_costr, units_shutup_cost_constr, units_shutdown_cost_constr
end

"""
`add_generator_power_constraints!(...)`

Defines technical limits for active power generation, accounting for commitment
status and reserve requirements across all scenarios.

# Constraints

  - P_min * x <= P_dispatch - Spare_Down
  - P_dispatch + Spare_Up <= P_max * x
"""
function add_generator_power_constraints!(scuc::Model, NT, NG, NS, units)
	x = scuc[:x]
	pg₀ = scuc[:pg₀]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]

	units_minpower_constr = @constraint(scuc, [s = 1:NS, t = 1:NT], pg₀[(1 + (s - 1) * NG):(s * NG), t] + sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<= units.p_max[:, 1] .* x[:, t])
	units_maxpower_constr = @constraint(scuc, [s = 1:NS, t = 1:NT], pg₀[(1 + (s - 1) * NG):(s * NG), t] - sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>= units.p_min[:, 1] .* x[:, t])
	println("\t constraints: 5) generatos power limits\t\t\t\t\t done")
	return scuc, units_minpower_constr, units_maxpower_constr
end

# Helper function for ramp rate constraints
function add_ramp_constraints!(scuc::Model, NT, NG, NS, units, onoffinit)
	x = scuc[:x]
	u = scuc[:u]
	v = scuc[:v]
	pg₀ = scuc[:pg₀]
	ramp_violation⁺ = haskey(JuMP.object_dictionary(scuc), :ramp_violation⁺) ? scuc[:ramp_violation⁺] : nothing
	ramp_violation⁻ = haskey(JuMP.object_dictionary(scuc), :ramp_violation⁻) ? scuc[:ramp_violation⁻] : nothing

	p_0 = units.p_0
	ramp_up = units.ramp_up
	ramp_down = units.ramp_down
	shut_up = units.shut_up
	shut_down = units.shut_down
	p_max = units.p_max
	p_min = units.p_min

	units_upramp_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] - ((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) .<=
		ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) + shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) + p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1])) +
		(ramp_violation⁺ === nothing ? zeros(NG) : ramp_violation⁺[(1 + (s - 1) * NG):(s * NG), t]))

	units_downramp_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
		((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) - pg₀[(1 + (s - 1) * NG):(s * NG), t] .<=
		ramp_down[:, 1] .* x[:, t] + shut_down[:, 1] .* v[:, t] + p_max[:, 1] .* (x[:, t]) + (ramp_violation⁻ === nothing ? zeros(NG) : ramp_violation⁻[(1 + (s - 1) * NG):(s * NG), t]))
	println("\t constraints: 8) ramp-up/ramp-down constraints\t\t\t\t done")
	return scuc, units_upramp_constr, units_downramp_constr
end

"""
`add_pwl_constraints!(...)`

Implements piecewise linear (PWL) constraints for the generation cost function.
This approximates the quadratic fuel cost curve with linear segments.

# Constraints

  - Total Power = P_min * Status + Sum(Segment_Powers)
  - Segment_Power <= Segment_Capacity * Status
"""
function add_pwl_constraints!(scuc::Model, NT, NG, NS, units)
	# Check if PWL variables exist
	if isempty(scuc[:pgₖ])
		return println("\t constraints: 9) PWL skipped (pgₖ not defined)")
	end

	x = scuc[:x]
	pg₀ = scuc[:pg₀]
	pgₖ = scuc[:pgₖ]

	p_max = units.p_max
	p_min = units.p_min

	num_segments = size(pgₖ, 3) # Get number of segments from variable definition

	eachsegment = (p_max - p_min) / num_segments

	units_pwlpower_sum_constr = @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG], pg₀[i + (s - 1) * NG, t] .== p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, k] for k in 1:num_segments))
	units_pwlblock_upbound_constr = @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments], pgₖ[i + (s - 1) * NG, t, k] <= eachsegment[i, 1] * x[i, t])
	units_pwlblock_dwbound_constr = @constraint(scuc, # Ensure segments are non-negative
		[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
		pgₖ[i + (s - 1) * NG, t, k] >= 0)
	println("\t constraints: 9) piece linearization constraints\t\t\t done")
	return scuc, units_pwlpower_sum_constr, units_pwlblock_upbound_constr, units_pwlblock_dwbound_constr
end
