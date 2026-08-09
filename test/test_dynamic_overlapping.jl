using JuMP
using Gurobi
using Random
using Printf

# ============================================================================
# Generator Data Structure
# ============================================================================
struct Unit
    id::Int
    name::String
    p_max::Float64
    p_min::Float64
    marginal_cost::Float64
    start_cost::Float64
    T_up::Int          # Minimum up time (hours)
    T_down::Int        # Minimum down time (hours)
    initial_x::Int     # Initial status (1=on, 0=off)
    initial_t::Int     # Initial duration (hours)
    is_slow::Bool      # True if slow thermal unit
end

# ============================================================================
# Dynamic Overlapping Unit Commitment Model Solver
# ============================================================================
function solve_rolling_uc(net_load_profile::Vector{Float64}, units::Vector{Unit}, T_D::Int, T_lookahead_max::Int; delta_ramp::Float64 = 40.0,
        T_o_min::Int = 1, T_o_max::Int = 12, enable_dynamic_overlapping::Bool = true, enable_space_decoupling::Bool = true)
    total_hours = length(net_load_profile)
    current_start = 1

    # Initialize previous state tracking
    pre_states = Dict(g.id => (x0 = g.initial_x, t_elapsed = g.initial_t) for g ∈ units)

    # Result containers
    dispatch_results = Dict{Int, Vector{Float64}}() # Hour => Generator Outputs
    commitment_results = Dict{Int, Vector{Int}}()   # Hour => Generator Commitments

    total_solve_time = 0.0
    total_mip_integers = 0
    interval_costs = Float64[]
    overlap_lengths = Int[]
    total_slack_violations = 0.0

    println("\nRunning UC Simulation (Dynamic Overlap: $enable_dynamic_overlapping, Space Decoupling: $enable_space_decoupling)...")

    while current_start <= total_hours - T_D
        # 1. Event Detection & Dynamic Overlap Window Selection
        T_o = T_o_min
        if enable_dynamic_overlapping
            lookahead_start = current_start + T_D
            lookahead_end = min(lookahead_start + T_lookahead_max - 1, total_hours)
            if lookahead_start < lookahead_end
                lookahead_net_load = net_load_profile[lookahead_start:lookahead_end]
                ramp_rates = abs.(diff(lookahead_net_load))
                event_indices = findall(r -> r >= delta_ramp, ramp_rates)
                if !isempty(event_indices)
                    first_event_offset = minimum(event_indices)
                    T_o = clamp(first_event_offset + 2, T_o_min, T_o_max)
                end
            end
        else
            T_o = 4 # Fixed 4-hour overlap for baseline comparison
        end
        push!(overlap_lengths, T_o)

        T_sub = T_D + T_o
        sub_net_load = net_load_profile[current_start:min(current_start + T_sub - 1, total_hours)]
        actual_T_sub = length(sub_net_load)

        # 2. Build Optimization Model
        model = Model(Gurobi.Optimizer)
        set_silent(model)
        set_optimizer_attribute(model, "MIPGap", 1e-4)

        NG = length(units)
        @variable(model, x[1:NG, 1:actual_T_sub], Bin)
        @variable(model, u[1:NG, 1:actual_T_sub] >= 0)
        @variable(model, v[1:NG, 1:actual_T_sub] >= 0)
        @variable(model, p[1:NG, 1:actual_T_sub] >= 0)

        # Space Decoupling: Relax binary variables of slow units in the overlap zone
        if enable_space_decoupling
            for g_idx ∈ 1:NG
                if units[g_idx].is_slow
                    for t ∈ (T_D + 1):actual_T_sub
                        unset_binary(x[g_idx, t])
                        set_lower_bound(x[g_idx, t], 0.0)
                        set_upper_bound(x[g_idx, t], 1.0)
                    end
                end
            end
        end

        # Track the number of integer variables in this subproblem
        num_integers = 0
        for var ∈ all_variables(model)
            if is_binary(var) || is_integer(var)
                num_integers += 1
            end
        end
        total_mip_integers += num_integers

        # 3. Enforce State Lock Countdown Constraints
        for g_idx ∈ 1:NG
            g = units[g_idx]
            state_info = pre_states[g.id]

            if state_info.x0 == 1
                L_up = max(0, g.T_up - state_info.t_elapsed)
                for t ∈ 1:min(L_up, actual_T_sub)
                    @constraint(model, x[g_idx, t] == 1.0)
                    @constraint(model, u[g_idx, t] == 0.0)
                    @constraint(model, v[g_idx, t] == 0.0)
                end
            else
                L_down = max(0, g.T_down - state_info.t_elapsed)
                for t ∈ 1:min(L_down, actual_T_sub)
                    @constraint(model, x[g_idx, t] == 0.0)
                    @constraint(model, u[g_idx, t] == 0.0)
                    @constraint(model, v[g_idx, t] == 0.0)
                end
            end
        end

        # 4. Standard Operational Constraints
        # Logical relations
        for g_idx ∈ 1:NG
            state_info = pre_states[units[g_idx].id]
            @constraint(model, u[g_idx, 1] - v[g_idx, 1] == x[g_idx, 1] - state_info.x0)
            for t ∈ 2:actual_T_sub
                @constraint(model, u[g_idx, t] - v[g_idx, t] == x[g_idx, t] - x[g_idx, t - 1])
                @constraint(model, u[g_idx, t] + v[g_idx, t] <= 1.0)
            end
        end

        # Power bounds
        for g_idx ∈ 1:NG
            g = units[g_idx]
            for t ∈ 1:actual_T_sub
                @constraint(model, p[g_idx, t] >= g.p_min * x[g_idx, t])
                @constraint(model, p[g_idx, t] <= g.p_max * x[g_idx, t])
            end
        end

        # System Power Balance with slack variables
        @variable(model, slack_up[1:actual_T_sub] >= 0)
        @variable(model, slack_dn[1:actual_T_sub] >= 0)
        for t ∈ 1:actual_T_sub
            @constraint(model, sum(p[g_idx, t] for g_idx ∈ 1:NG) + slack_up[t] - slack_dn[t] == sub_net_load[t])
        end

        # 5. Objective Function with Asymmetric Perturbation and Slack Penalty
        rng = Random.MersenneTwister(1234 + current_start)
        objective_expr = AffExpr(0.0)
        for g_idx ∈ 1:NG
            g = units[g_idx]
            epsilon = g.is_slow ? (g_idx * 1e-5 + rand(rng) * 1e-6) : 0.0
            perturbed_start_cost = g.start_cost * (1.0 + epsilon)
            for t ∈ 1:actual_T_sub
                add_to_expression!(objective_expr, p[g_idx, t] * g.marginal_cost)
                add_to_expression!(objective_expr, u[g_idx, t] * perturbed_start_cost)
            end
        end
        for t ∈ 1:actual_T_sub
            add_to_expression!(objective_expr, (slack_up[t] + slack_dn[t]) * 1e5)
        end
        @objective(model, Min, objective_expr)

        # 6. Solve Model
        t_start = time()
        optimize!(model)
        t_solve = time() - t_start
        total_solve_time += t_solve

        if termination_status(model) != OPTIMAL
            error("Optimization failed at interval start hour $(current_start)!")
        end

        # 7. Save Dispatch Results (Only for Decision Horizon T_D)
        interval_cost = 0.0
        interval_slack = 0.0
        for t ∈ 1:T_D
            global_t = current_start + t - 1
            p_val = [value(p[g_idx, t]) for g_idx ∈ 1:NG]
            x_val = [round(Int, value(x[g_idx, t])) for g_idx ∈ 1:NG]
            dispatch_results[global_t] = p_val
            commitment_results[global_t] = x_val

            s_up = value(slack_up[t])
            s_dn = value(slack_dn[t])
            interval_slack += s_up + s_dn
            total_slack_violations += s_up + s_dn

            # Sum up actual operating costs in decision horizon
            for g_idx ∈ 1:NG
                g = units[g_idx]
                u_val = value(u[g_idx, t])
                interval_cost += p_val[g_idx] * g.marginal_cost + u_val * g.start_cost
            end
        end
        push!(interval_costs, interval_cost)

        # 8. Update Boundary States
        for g_idx ∈ 1:NG
            g = units[g_idx]
            x_end = round(Int, value(x[g_idx, T_D]))
            prev_info = pre_states[g.id]
            t_elapsed_next = 1
            if x_end == prev_info.x0
                t_elapsed_next = prev_info.t_elapsed + T_D
            else
                history_states = [round(Int, value(x[g_idx, t])) for t ∈ 1:T_D]
                last_switch = findlast(s -> s != x_end, history_states)
                t_elapsed_next = isnothing(last_switch) ? T_D : (T_D - last_switch)
            end
            pre_states[g.id] = (x0 = x_end, t_elapsed = t_elapsed_next)
        end

        @printf("  Interval %2d (Hour %3d-%3d): Solve Time = %5.3f s, Overlap = %2d h, Cost = %10.2f, Slack = %5.1f MW, IntVars = %3d\n",
            length(interval_costs), current_start, current_start + T_D - 1, t_solve, T_o, interval_cost, interval_slack, num_integers)

        current_start += T_D
    end

    return Dict(
        "solve_time" => total_solve_time, "integers" => total_mip_integers, "cost" => sum(interval_costs), "commitments" => commitment_results,
        "dispatches" => dispatch_results, "overlap_lengths" => overlap_lengths, "slack" => total_slack_violations)
end

# ============================================================================
# Main Simulation and Verification
# ============================================================================
function run_debugging_demo()
    # 1. Define 4 Mock Units (Cluster of 2 slow and 2 fast units)
    # Unit format: id, name, p_max, p_min, marginal_cost, start_cost, T_up, T_down, initial_x, initial_t, is_slow
    units = [Unit(1, "Slow_Coal_A", 300.0, 100.0, 15.0, 3000.0, 12, 12, 1, 10, true),
        Unit(2, "Slow_Coal_B", 250.0, 80.0, 17.0, 2500.0, 10, 10, 1, 5, true),
        Unit(3, "Fast_Gas_C", 120.0, 30.0, 30.0, 500.0, 2, 2, 0, 4, false), Unit(4, "Fast_Gas_D", 100.0, 20.0, 35.0, 400.0, 1, 1, 0, 6, false)]

    # 2. Generate 168-hour net load profile with peak ramping events
    # We will simulate a solar-heavy system where net load drops at noon and ramps heavily in the evening
    T_total = 168
    net_load_profile = zeros(T_total)
    for t ∈ 1:T_total
        hour_of_day = (t - 1) % 24 + 1
        # Elevated base load to prevent over-generation issues
        base_load = 380.0 + 120.0 * sin(2 * pi * (hour_of_day - 6) / 24)

        # Simulating Solar Duck Curve (sharp dip during noon, sharp evening ramp)
        solar_generation = 0.0
        if 8 <= hour_of_day <= 17
            solar_generation = 180.0 * sin(pi * (hour_of_day - 8) / 9)
        end

        # Inject an extreme weather ramping event on Day 3 and Day 5
        event_impact = 0.0
        if (48 <= t <= 72 && 16 <= hour_of_day <= 20) || (96 <= t <= 120 && 16 <= hour_of_day <= 20)
            event_impact = 90.0 * sin(pi * (hour_of_day - 16) / 4) # Extra ramp
        end

        net_load_profile[t] = base_load - solar_generation + event_impact
    end

    T_D = 24
    T_lookahead_max = 12

    println("================================================================================")
    println("              DYNAMIC OVERLAPPING WINDOW UC - ACCELERATION RUN                 ")
    println("================================================================================")

    # 1. Run Proposed Model: Dynamic Overlapping + Space Decoupling
    res_dynamic = solve_rolling_uc(net_load_profile, units, T_D, T_lookahead_max; delta_ramp = 35.0, T_o_min = 1,
        T_o_max = 12, enable_dynamic_overlapping = true, enable_space_decoupling = true)

    # 2. Run Baseline Model: Fixed 4-hour Overlapping + No Space Decoupling
    res_baseline = solve_rolling_uc(
        net_load_profile, units, T_D, T_lookahead_max; enable_dynamic_overlapping = false, enable_space_decoupling = false)

    # ==========================================
    # 3. Print Beautiful Comparative Report
    # ==========================================
    println("\n" * "="^80)
    println("                        COMPARATIVE ACCELERATION REPORT                         ")
    println("="^80)
    @printf("  %-30s | %-18s | %-18s\n", "Metric", "Baseline (Fixed)", "Proposed (Dynamic)")
    println("-"^80)
    @printf("  %-30s | %18.4f | %18.4f\n", "Total Solving Time (s)", res_baseline["solve_time"], res_dynamic["solve_time"])
    @printf("  %-30s | %18d | %18d\n", "Total Integer Variables", res_baseline["integers"], res_dynamic["integers"])
    @printf("  %-30s | %18.2f | %18.2f\n", "Total Operating Cost (\$)", res_baseline["cost"], res_dynamic["cost"])
    @printf("  %-30s | %18.2f | %18.2f\n", "Total Slack Violation (MW)", res_baseline["slack"], res_dynamic["slack"])
    @printf("  %-30s | %18.2f%% | %18s\n",
        "Solve Time Saved (%)", (res_baseline["solve_time"] - res_dynamic["solve_time"]) / res_baseline["solve_time"] * 100, "Ref. 0.00%")
    @printf("  %-30s | %18.3f%% | %18s\n", "Cost Deviation (%)", (res_dynamic["cost"] - res_baseline["cost"]) / res_baseline["cost"] * 100,
        "Ref. 0.00%")
    println("-"^80)

    println("\nOverlap Windows over 7 intervals:")
    print("  Proposed Dynamic To: ")
    println(res_dynamic["overlap_lengths"])
    print("  Baseline Fixed To  : ")
    println(res_baseline["overlap_lengths"])

    println("\n" * "="^80)
    println("                COMMITMENT SCHEDULE DETAILS (PROPOSED DYNAMIC)                 ")
    println("="^80)
    for g_idx ∈ 1:length(units)
        @printf("  Unit %d (%-12s): ", g_idx, units[g_idx].name)
        for t ∈ 1:12:144 # Sample every 12 hours for output clarity
            state = res_dynamic["commitments"][t][g_idx]
            p_out = res_dynamic["dispatches"][t][g_idx]
            @printf("H%03d:%d(%.1f)  ", t, state, p_out)
        end
        println()
    end
    println("="^80 * "\n")
end

run_debugging_demo()
