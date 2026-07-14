"""
`add_storage_constraints!(...)`

Adds operational constraints for Battery Energy Storage Systems (BESS) or Pumped
Storage Systems (PSS). This includes power limits, State of Charge (SoC)
dynamics, efficiency losses, and cycle count restrictions.

# Arguments

  - `scuc`: The JuMP model.
  - `NT`, `NC`, `NS`: Number of time periods, storage units, and scenarios.
  - `stroges`: Data structure containing storage technical parameters.
"""
function add_storage_constraints!(scuc::Model, NT, NC, NS, config_param, stroges; include_binary_logic::Bool = true)

    # Check if storage exists before defining constraints
    if NC == 0 || !check_var_exists(scuc, "pc⁺") # Check if variables were defined
        println("\t constraints: 11) stroges system constraints skipped (NC=0 or variables not defined)")
        return nothing # Skip if no storage units or variables missing
    end

    if config_param.is_ConsiderBESS == 0
        println("\t constraints: 11) stroges system constraints skipped (is_ConsiderBESS=0)")
    else
        # Retrieve variable references
        κ⁺ = scuc[:κ⁺] # Charging status
        κ⁻ = scuc[:κ⁻] # Discharging status
        pc⁺ = scuc[:pc⁺] # Charging power
        pc⁻ = scuc[:pc⁻] # Discharging power
        qc = scuc[:qc]   # Energy storage level (SoC)
        α = scuc[:α]     # Auxiliary flag for cycle start
        β = scuc[:β]     # Auxiliary flag for cycle end

        # Use get with defaults for robustness against missing fields in stroges struct
        p_plus = stroges.p⁺
        p_minus = stroges.p⁻
        gamma_plus = stroges.γ⁺
        gamma_minus = stroges.γ⁻
        Q_max = stroges.Q_max
        Q_min = stroges.Q_min
        Q_initial = stroges.P₀
        # stroges.Q₀
        P_initial = stroges.P₀
        eta_plus = stroges.η⁺
        eta_minus = stroges.η⁻

        # --- Charge and Discharge Power Limits ---
        # Ensures power is within physical limits and respects the binary status
        charge_power_limit =
            @constraint(scuc, [s = 1:NS, t = 1:NT], pc⁺[((s - 1) * NC + 1):(s * NC), t] .<= p_plus[:, 1] .* κ⁺[((s - 1) * NC + 1):(s * NC), t])
        discharge_power_limit =
            @constraint(scuc, [s = 1:NS, t = 1:NT], pc⁻[((s - 1) * NC + 1):(s * NC), t] .<= p_minus[:, 1] .* κ⁻[((s - 1) * NC + 1):(s * NC), t])

        # coupling limits for adjacent discharge/charge constraints (Ramping for storage)
        charge_ramp_up = @constraint(
            scuc,
            [s = 1:NS, t = 1:NT],
            pc⁺[((s - 1) * NC + 1):(s * NC), t] - ((t == 1) ? P_initial[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) .<= gamma_plus[:, 1]
        )
        charge_ramp_down = @constraint(
            scuc,
            [s = 1:NS, t = 1:NT],
            ((t == 1) ? P_initial[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) - pc⁺[((s - 1) * NC + 1):(s * NC), t] .<= gamma_minus[:, 1]
        )

        # Mutual exclusion constraints in charge and discharge states
        state_exclusion = if include_binary_logic
            @constraint(scuc, [s = 1:NS, t = 1:NT, c = 1:NC], κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t] <= 1)
        else
            nothing
        end

        # --- Energy Storage Dynamics (State of Charge) ---
        # qc(t) = qc(t-1) + η⁺*pc⁺(t) - pc⁻(t)/η⁻
        soc_max = @constraint(scuc, [s = 1:NS, t = 1:NT], qc[((s - 1) * NC + 1):(s * NC), t] .<= Q_max[:, 1]) # Maximum SoC
        soc_min = @constraint(scuc, [s = 1:NS, t = 1:NT], qc[((s - 1) * NC + 1):(s * NC), t] .>= Q_min[:, 1]) # Minimum SoC
        soc_balance = @constraint(
            scuc,
            [s = 1:NS, t = 1:NT],
            qc[((s - 1) * NC + 1):(s * NC), t] .==
            ((t == 1) ? Q_initial[:, 1] : qc[((s - 1) * NC + 1):(s * NC), t - 1]) + eta_plus[:, 1] .* pc⁺[((s - 1) * NC + 1):(s * NC), t] -
            (ones(NC, 1) ./ eta_minus[:, 1]) .* pc⁻[((s - 1) * NC + 1):(s * NC), t]
        )

        # Initial-time and end-time equality (SoC target relative to initial SoC Q₀)
        soc_terminal = @constraint(scuc, [s = 1:NS], 0.99 * Q_initial[:, 1] .<= qc[((s - 1) * NC + 1):(s * NC), NT] .<= 1.01 * Q_initial[:, 1])

        # Constraints on charging cycles (α, β logic)
        start_logic = if include_binary_logic
            @constraint(
                scuc,
                [s = 1:NS, c = 1:NC, t = 1:NT],
                α[(s - 1) * NC + c, t] >= κ⁺[(s - 1) * NC + c, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1])
            )
        else
            nothing
        end
        stop_logic = if include_binary_logic
            @constraint(
                scuc,
                [s = 1:NS, c = 1:NC, t = 1:NT],
                β[(s - 1) * NC + c, t] >= ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]) - κ⁺[(s - 1) * NC + c, t]
            )
        else
            nothing
        end

        start_cycle_limit = if include_binary_logic
            @constraint(scuc, [s = 1:NS, c = 1:NC], sum(α[(s - 1) * NC + c, t] for t in 1:NT) <= 5)
        else
            nothing
        end
        stop_cycle_limit = if include_binary_logic
            @constraint(scuc, [s = 1:NS, c = 1:NC], sum(β[(s - 1) * NC + c, t] for t in 1:NT) <= 5)
        else
            nothing
        end

        println("\t constraints: 11) stroges system constraints limits\t\t\t done")
        return (
            charge_power_limit = charge_power_limit,
            discharge_power_limit = discharge_power_limit,
            charge_ramp_up = charge_ramp_up,
            charge_ramp_down = charge_ramp_down,
            state_exclusion = state_exclusion,
            soc_max = soc_max,
            soc_min = soc_min,
            soc_balance = soc_balance,
            soc_terminal = soc_terminal,
            start_logic = start_logic,
            stop_logic = stop_logic,
            start_cycle_limit = start_cycle_limit,
            stop_cycle_limit = stop_cycle_limit,
        )
    end
end
