using JuMP

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

    units_minuptime_constr = Vector{ConType}()
    units_mindowntime_constr = Vector{ConType}()

    # --- Minimum Up and Down Time Constraints ---
    has_t0 = hasproperty(units, :t_0) && length(units.t_0) >= NG
    has_t1 = hasproperty(units, :t_1) && length(units.t_1) >= NG
    for i in 1:NG
        tu = ceil(Int64, Float64(units.min_up_time[i]))
        td = ceil(Int64, Float64(units.min_down_time[i]))
        init_on = onoffinit[i] > 0.5

        elapsed_up = (init_on && has_t0) ? Float64(units.t_0[i]) : 0.0
        L_up = (init_on && tu > 0 && elapsed_up > 0.0) ? min(NT, max(Int64(0), ceil(Int64, Float64(units.min_up_time[i]) - elapsed_up))) : Int64(0)
        for t in 1:L_up
            push!(units_minuptime_constr, @constraint(scuc, x[i, t] >= 1.0))
        end
        if tu >= 1
            for t in (L_up + 1):NT
                LB = max(Int64(1), t - tu + 1)
                con = @constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t])
                push!(units_minuptime_constr, con)
            end
        end

        elapsed_down = if !init_on
            t1_val = has_t1 ? Float64(units.t_1[i]) : 0.0
            t1_val > 0.0 ? t1_val : (has_t0 ? Float64(units.t_0[i]) : 0.0)
        else
            0.0
        end
        L_down = (!init_on && td > 0 && elapsed_down > 0.0) ? min(NT, max(Int64(0), ceil(Int64, Float64(units.min_down_time[i]) - elapsed_down))) : Int64(0)
        for t in 1:L_down
            push!(units_mindowntime_constr, @constraint(scuc, x[i, t] <= 0.0))
        end
        if td >= 1
            for t in (L_down + 1):NT
                LB = max(Int64(1), t - td + 1)
                con = @constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]))
                push!(units_mindowntime_constr, con)
            end
        end
    end

    println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

    # --- Binary Variable Logic (State Transitions) ---
    # u[t] - v[t] = x[t] - x[t-1]
    units_init_stateslogic_consist_constr =
        @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))

    # Prevent simultaneous startup and shutdown
    units_states_consist_constr = @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)

    println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

    # --- Startup and Shutdown Costs (Linearization) ---
    shutupcost = units.coeff_hot_startup
    shutdowncost = units.coeff_shutdown
    units_init_shutup_cost_constr = @constraint(scuc, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
    units_init_shutdown_cost_costr = @constraint(scuc, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))
    units_shutup_cost_constr = @constraint(scuc, [t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
    units_shutdown_cost_constr = @constraint(scuc, [t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])

    println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")
    return scuc,
    units_minuptime_constr,
    units_mindowntime_constr,
    units_init_stateslogic_consist_constr,
    units_states_consist_constr,
    units_init_shutup_cost_constr,
    units_init_shutdown_cost_costr,
    units_shutup_cost_constr,
    units_shutdown_cost_constr
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

    units_minpower_constr = @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] + sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<= units.p_max[:, 1] .* x[:, t]
    )
    units_maxpower_constr = @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] - sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>= units.p_min[:, 1] .* x[:, t]
    )
    println("\t constraints: 5) generatos power limits\t\t\t\t\t done")
    return scuc, units_minpower_constr, units_maxpower_constr
end

# Helper function for ramp rate constraints
function add_ramp_constraints!(scuc::Model, NT, NG, NS, units, onoffinit)
    x = scuc[:x]
    u = scuc[:u]
    v = scuc[:v]
    pg₀ = scuc[:pg₀]
    ramp_violation⁺ = if haskey(JuMP.object_dictionary(scuc), :ramp_violation⁺)
        scuc[:ramp_violation⁺]
    else
        nothing
    end
    ramp_violation⁻ = if haskey(JuMP.object_dictionary(scuc), :ramp_violation⁻)
        scuc[:ramp_violation⁻]
    else
        nothing
    end

    p_0 = units.p_0
    ramp_up = units.ramp_up
    ramp_down = units.ramp_down
    startup_ramp = units.startup_ramp
    shutdown_ramp = units.shutdown_ramp
    p_max = units.p_max
    p_min = units.p_min

    units_upramp_constr = @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] - ((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) .<=
        ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
        startup_ramp[:, 1] .* u[:, t] +
        p_max[:, 1] .* (ones(NG, 1) - x[:, t]) +
        (
            if ramp_violation⁺ === nothing
                zeros(NG)
            else
                ramp_violation⁺[(1 + (s - 1) * NG):(s * NG), t]
            end
        )
    )

    units_downramp_constr = @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        ((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) - pg₀[(1 + (s - 1) * NG):(s * NG), t] .<=
        ramp_down[:, 1] .* x[:, t] +
        shutdown_ramp[:, 1] .* v[:, t] +
        p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1])) + (
            if ramp_violation⁻ === nothing
                zeros(NG)
            else
                ramp_violation⁻[(1 + (s - 1) * NG):(s * NG), t]
            end
        )
    )
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

    units_pwlpower_sum_constr = @constraint(
        scuc,
        [s = 1:NS, t = 1:NT, i = 1:NG],
        pg₀[i + (s - 1) * NG, t] .== p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, k] for k in 1:num_segments)
    )
    units_pwlblock_upbound_constr =
        @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments], pgₖ[i + (s - 1) * NG, t, k] <= eachsegment[i, 1] * x[i, t])
    units_pwlblock_dwbound_constr = @constraint(
        scuc, # Ensure segments are non-negative
        [s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
        pgₖ[i + (s - 1) * NG, t, k] >= 0
    )
    println("\t constraints: 9) piece linearization constraints\t\t\t done")
    return scuc, units_pwlpower_sum_constr, units_pwlblock_upbound_constr, units_pwlblock_dwbound_constr
end
