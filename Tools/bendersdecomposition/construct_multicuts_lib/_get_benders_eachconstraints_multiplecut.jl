"""
	get_benders_multicuts_expression(...)

	Generate Benders decomposition multi-cut expressions for each constraint.

	This function constructs the multi-cut formulation used in Benders decomposition,
	which creates separate optimality cuts for different scenarios or constraint groups
	rather than aggregating them into a single cut. This approach can improve convergence
	in some cases by providing more detailed information to the master problem.

	# Arguments
	- The specific arguments depend on the implementation, but typically include:
	- Master problem variables
	- Subproblem dual values/solutions
	- Constraint coefficients
	- Scenario/group indices

	# Returns
	- A collection of Benders multi-cut expressions, one for each constraint group

	# Notes
	- Multi-cuts provide tighter approximations of the recourse function compared to single cuts
	- Each cut corresponds to a different constraint or scenario in the subproblem
	- The function processes constraints individually to maintain separate cutting planes
	- This is part of the Benders decomposition framework for unit commitment problems

	# Implementation Details
	- Iterates through each constraint/scenario group
	- Computes dual values from subproblem solutions
	- Constructs cut expressions using dual multipliers and master problem variables
	- Maintains separate cuts to preserve problem structure information

  - Benders decomposition algorithm
  - Unit commitment optimization
"""

function get_benders_multicuts_expression(
		scuc_masterproblem::JuMP.Model, coeff, keys_name, NG, NT, NW, ND, NL, NC = 3
)
	# Unpack coefficients and related metadata from the coeff struct for clarity and maintainability
	x_coefficient = coeff.x  # Coefficients for commitment variables
	u_coefficient = coeff.u  # Coefficients for startup variables
	v_coefficient = coeff.v  # Coefficients for shutdown variables
	x_order = coeff.x_sort_order  # Sorting order for x variables (0: time-major, 1: unit-major)
	u_order = coeff.u_sort_order  # Sorting order for u variables
	v_order = coeff.v_sort_order  # Sorting order for v variables
	rhs = coeff.rhs  # Right-hand side values of constraints
	dual_coefficient = coeff.dual_coeffVector  # Dual variable values from subproblem
	operator_precedence = coeff.operator_associativity  # Sign operators (+1 or -1) for constraint terms

	# Check if all variable orders are nothing (indicates non-unit-related constraints)
	if all(x -> x === nothing, (x_order, u_order, v_order))

		# ===== Handle non-unit-related constraints =====
		"""
			Constraint types handled in this section:
			- key_winds_curt_constr: Wind curtailment constraints (NW * NT)
			- key_loads_curt_constr: Load curtailment constraints (ND * NT)
			- key_balance_constr: Power balance constraints (NT)
			- key_sys_down_reserve_constr: System down reserve constraints (NT)
			- key_transmissionline_powerflow_upbound_constr: Transmission line upper bound (NL * NT)
			- key_transmissionline_powerflow_downbound_constr: Transmission line lower bound (NL * NT)
			- key_units_pwlblock_dwbound_constr: Piecewise linear block lower bound (NG * NT * NC)
		"""

		# Wind power curtailment constraints: iterate over wind units and time periods
		if occursin("winds_curt_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					(
						operator_precedence[(t - 1) * NW + w, 1] *  # Sign of the term
						dual_coefficient[(t - 1) * NW + w, 1] *      # Dual value
						rhs[(t - 1) * NW + w, 1]                     # RHS constant
					) for w ∈ 1:NW  # Loop over wind units
				) for t ∈ 1:NT  # Loop over time periods
			))
		end

		# Load curtailment constraints: iterate over demand points and time periods
		if occursin("loads_curt_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					operator_precedence[(t - 1) * ND + d, 1] *
					dual_coefficient[(t - 1) * ND + d, 1] *
					rhs[(t - 1) * ND + d, 1] for d ∈ 1:ND  # Loop over demand points
				) for t ∈ 1:NT  # Loop over time periods
			))
		end

		# Piecewise linear block lower bound constraints: iterate over units, time, and blocks
		if occursin("units_pwlblock_dwbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					sum(
						operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
						dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
						rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] for g ∈ 1:NG  # Loop over units
					) for t ∈ 1:NT  # Loop over time periods
				) for k ∈ 1:NC  # Loop over piecewise linear blocks
			))
		end

		# System-level constraints (balance and reserve): iterate over time periods only
		if occursin("balance_constr", String(keys_name)) ||
		   occursin("sys_down_reserve_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1] for
			t ∈ 1:NT  # Loop over time periods
			))
		end

		# Transmission line upper bound constraints: iterate over lines and time periods
		if occursin("transmissionline_powerflow_upbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					operator_precedence[(t - 1) * NL + l, 1] *
					dual_coefficient[(t - 1) * NL + l, 1] *
					rhs[(t - 1) * NL + l, 1] for l ∈ 1:NL  # Loop over transmission lines
				) for t ∈ 1:NT  # Loop over time periods
			))
		end

		# Transmission line lower bound constraints: iterate over lines and time periods
		if occursin("transmissionline_powerflow_downbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					operator_precedence[(t - 1) * NL + l, 1] *
					dual_coefficient[(t - 1) * NL + l, 1] *
					rhs[(t - 1) * NL + l, 1] for l ∈ 1:NL  # Loop over transmission lines
				) for t ∈ 1:NT  # Loop over time periods
			))
		end

	else
		# ===== Handle unit-related constraints =====
		"""
			Constraint types handled in this section:
			- key_sys_upreserve_constr: System up reserve constraints (NG * NT)
			- key_units_minpower_constr: Unit minimum power constraints (NG * NT)
			- key_units_maxpower_constr: Unit maximum power constraints (NG * NT)
			- key_units_pwlpower_sum_constr: Piecewise linear power sum (NG * NT)
			- key_units_downramp_constr: Unit ramping down constraints (NG * NT)
			- key_units_upramp_constr: Unit ramping up constraints (NG * NT)
			- key_units_pwlblock_upbound_constr: PWL block upper bound (NG * NT * NC)
		"""

		# Define pattern list for regular unit-related constraints (NG * NT)
		patterns = [
			"units_minpower_constr",
			"units_maxpower_constr",
			"sys_upreserve_constr",
			"units_downramp_constr",
			"units_pwlpower_sum_constr"
		]
		RE_FLAG = any(p -> occursin(p, String(keys_name)), patterns)

		# Handle regular unit-related constraints (NG * NT)
		if RE_FLAG
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
				# Contribution from commitment variable x[g,t]
					(
						if isnothing(x_order)
						0  # No x variable in this constraint
					else
						(
							if x_order == 0  # Time-major ordering: (t-1)*NG + g
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								x_coefficient[(t - 1) * NG + g, 1] *
								scuc_masterproblem[:x][g, t]
							)
						else  # Unit-major ordering: (g-1)*NT + t
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								x_coefficient[(g - 1) * NT + t, 1] *
								scuc_masterproblem[:x][g, t]
							)
						end
						)
					end
					) +
					# Contribution from startup variable u[g,t]
					(
						if isnothing(u_order)
						0  # No u variable in this constraint
					else
						(
							if u_order == 0  # Time-major ordering
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								u_coefficient[(t - 1) * NG + g, 1] *
								scuc_masterproblem[:u][g, t]
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								u_coefficient[(g - 1) * NT + t, 1] *
								scuc_masterproblem[:u][g, t]
							)
						end
						)
					end
					) +
					# Contribution from shutdown variable v[g,t]
					(
						if isnothing(v_order)
						0  # No v variable in this constraint
					else
						(
							if v_order == 0  # Time-major ordering
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								v_coefficient[(t - 1) * NG + g, 1] *
								scuc_masterproblem[:v][g, t]
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								v_coefficient[(g - 1) * NT + t, 1] *
								scuc_masterproblem[:v][g, t]
							)
						end
						)
					end
					) +
					# Contribution from RHS constant term
					((
						if isnothing(x_order)
						(
							dual_coefficient[(t - 1) * NG + g, 1] *
							operator_precedence[(t - 1) * NG + g, 1] *
							rhs[(t - 1) * NG + g, 1]
						)
					else
						(
							dual_coefficient[(g - 1) * NT + t, 1] *
							operator_precedence[(g - 1) * NT + t, 1] *
							rhs[(g - 1) * NT + t, 1]
						)
					end
					)) for g ∈ 1:NG  # Loop over generating units
				) for t ∈ 1:NT  # Loop over time periods
			))
		end

		# Handle piecewise linear block upper bound constraints (NG * NT * NC)
		if occursin("units_pwlblock_upbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					sum(
					# System-level contribution (time-dependent only)
						(
							operator_precedence[t, 1] *
							dual_coefficient[t, 1] *
							rhs[t, 1]
						) +
						# Unit commitment variable contribution
						(
							if x_order == 0  # Time-major ordering
							(
								dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
								operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
								x_coefficient[(t - 1) * NG + g, 1] *
								scuc_masterproblem[:x][g, t]
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
								x_coefficient[(g - 1) * NT + t, 1] *
								scuc_masterproblem[:x][g, t]
							)
						end
						) +
						# RHS constant contribution
						(
							if x_order == 0  # Time-major ordering
							(
								dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
								operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
								rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
								operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
								rhs[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1]
							)
						end
						) for g ∈ 1:NG  # Loop over generating units
					) for t ∈ 1:NT  # Loop over time periods
				) for k ∈ 1:NC  # Loop over piecewise linear blocks
			))
		end

		# Handle unit ramping up constraints (special case: involves x[g,t-1])
		if occursin("units_upramp_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
				# Contribution from commitment variable x[g,t-1] (lagged commitment status)
					(
						if isnothing(x_order)
						0  # No x variable in this constraint
					else
						(
							if x_order == 0  # Time-major ordering
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								x_coefficient[(t - 1) * NG + g, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])  # Use previous period commitment
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								x_coefficient[(g - 1) * NT + t, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])  # Use previous period commitment
							)
						end
						)
					end
					) +
					# Contribution from startup variable u (based on previous commitment)
					(
						if isnothing(u_order)
						0  # No u variable in this constraint
					else
						(
							if u_order == 0  # Time-major ordering
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								u_coefficient[(t - 1) * NG + g, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								u_coefficient[(g - 1) * NT + t, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])
							)
						end
						)
					end
					) +
					# Contribution from shutdown variable v (based on previous commitment)
					(
						if isnothing(v_order)
						0  # No v variable in this constraint
					else
						(
							if v_order == 0  # Time-major ordering
							(
								dual_coefficient[(t - 1) * NG + g, 1] *
								operator_precedence[(t - 1) * NG + g, 1] *
								v_coefficient[(t - 1) * NG + g, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])
							)
						else  # Unit-major ordering
							(
								dual_coefficient[(g - 1) * NT + t, 1] *
								operator_precedence[(g - 1) * NT + t, 1] *
								v_coefficient[(g - 1) * NT + t, 1] *
								(1) *
								((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])
							)
						end
						)
					end
					) +
					# Contribution from RHS constant term
					((
						if isnothing(x_order)
						(
							dual_coefficient[(t - 1) * NG + g, 1] *
							operator_precedence[(t - 1) * NG + g, 1] *
							rhs[(t - 1) * NG + g, 1]
						)
					else
						(
							dual_coefficient[(g - 1) * NT + t, 1] *
							operator_precedence[(g - 1) * NT + t, 1] *
							rhs[(g - 1) * NT + t, 1]
						)
					end
					)) for g ∈ 1:NG  # Loop over generating units
				) for t ∈ 1:NT  # Loop over time periods
			))
		end
	end

	# Return the master problem model and the constructed Benders multi-cut expression
	return scuc_masterproblem, dual_expression_cut
end

# ---
# version - 1.0 discarded

# function construct_benders_cut(scuc_masterproblem::JuMP.Model, units::unit, winds::wind, loads::load, lines::transmission, NG::Int64, NT::Int64, NW::Int64, ND::Int64, NL::Int64, config_param::config)

# 	#NOTE -  Balance constraints
# 	# Calculate the coefficient for the balance constraint in the Benders cut
# 	coefficient_bal_constr = sum(dual_bal_constr[t] * (sum(loads.load_curve[d, t] for d in 1:ND) -
# 													   sum(winds.scenarios_curve[1, t] * wind_pmax[w, 1] for w in 1:NW)) for t in 1:NT)

# 	#NOTE - Conventional generation upper bound constraint
# 	# Calculate the Lagrange term for the conventional generation upper bound constraint
# 	coefficient_con_gen_ub_constr = @expression(sum(scuc_masterproblem, dual_con_gen_up_constr[g, t] * units.p_max[g, 1] * x[g, t] for g in 1:NG, t in 1:NT))

# 	#NOTE - Conventional generation lower bound constraint
# 	# Calculate the Lagrange term for the conventional generation lower bound constraint
# 	coefficient_con_gen_lb_constr = @expression(scuc_masterproblem, sum(dual_con_gen_lb_constr[g, t] * units.p_min[g, 1] * x[g, t] for g in 1:NG, t in 1:NT))

# 	#NOTE - Wind generation upper bound constraint
# 	# Calculate the coefficient for the wind generation upper bound constraint
# 	coefficient_wind_gen_ub_constr = sum(dual_wind_up_constr[w, t] * winds.scenarios_curve[1, t] * wind_pmax[w, 1] for w in 1:NW, t in 1:NT)

# 	#NOTE - Load curtailment constraint
# 	# Calculate the coefficient for the load curtailment constraint
# 	coefficient_load_cut_constr = sum(dual_wind_dw_constr[d, t] * loads.load_curve[d, t] for d in 1:ND, t in 1:NT)

# 	onoffinit = calculate_initial_unit_status(units, NG)

# 	#NOTE - Conventional generator ramping up constraints
# 	# Calculate the Lagrange term for the conventional generator ramping up constraints
# 	coefficient_con_gen_ramp_up_constr = @expression(scuc_masterproblem,
# 		sum(
# 		dual_con_gen_ramp_up_constr[g, t] * (
# 			units.ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
# 			units.shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
# 			units.p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]))
# 		) for g in 1:NG, t in 2:NT
# 	))

# 	#NOTE - Conventional generator ramping down constraints
# 	# Calculate the Lagrange term for the conventional generation ramping down constraints
# 	coefficient_con_gen_ramp_dw_constr = @expression(scuc_masterproblem,
# 		sum(
# 		dual_con_gen_ramp_down_constr[g, t] * (
# 			units.ramp_down[:, 1] .* x[:, t] +
# 			units.shut_down[:, 1] .* v[:, t] + units.p_max[:, 1] .* (x[:, t])
# 		) for g in 1:NG, t in 2:NT
# 	))

# 	#NOTE - Network powerflow constraints
# 	# Calculate the coefficient for the network powerflow constraints
# 	coefficient_term_nw_constr = (config_param.is_NetWorkCon == 0) ? 0.0 :
# 								 sum((dual_nw_powerflow_up_constr[l, t] + dual_nw_powerflow_dw_constr[l, t]) * lines.p_max[l, 1] for l in 1:NL, t in 1:NT)

# 	#NOTE - Combine all cuts
# 	# Sum up all the coefficients to form the combined cut
# 	combined_cuts = @expression(scuc_masterproblem,
# 		coefficient_bal_constr +
# 		coefficient_con_gen_ub_constr +
# 		coefficient_con_gen_lb_constr +
# 		coefficient_wind_gen_ub_constr +
# 		coefficient_load_cut_constr +
# 		coefficient_con_gen_ramp_dw_constr +
# 		coefficient_con_gen_ramp_up_constr +
# 		coefficient_con_gen_ramp_down_constr +
# 		coefficient_term_nw_constr)

# 	return scuc_masterproblem, combined_cuts
# end
