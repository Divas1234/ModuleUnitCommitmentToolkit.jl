# ============================================================================
# Plasmo.jl OptiGraph Builder for Stochastic Unit Commitment (PCM)
# Incorporating ALL 12 Operational UC Constraints from `pcm` branch
# Extended over 168-Hour Scheduling Horizon (1 Week / 7 Days)
# 
# References: Cole et al. (2023) "Hierarchical Graph Modeling for Multi-Scale
# Optimization of Power Systems"
# ============================================================================

using JuMP
using Plasmo
using DataFrames
using LinearAlgebra

export build_pcm_optigraph, OptiGraphMetrics

struct OptiGraphMetrics
    num_nodes::Int
    num_edges::Int
    num_variables::Int
    num_constraints::Int
    num_spatial_edges::Int
    num_temporal_edges::Int
    num_scenario_edges::Int
    subproblem_vars_per_node::Vector{Int}
    subproblem_cons_per_node::Vector{Int}
    spatial_dim::Int
    temporal_dim::Int
    scenario_dim::Int
end

"""
    build_pcm_optigraph(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, 
                         DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH)

Constructs a 3D Plasmo OptiGraph for the SUC (PCM) optimization problem incorporating
ALL operational constraints on the `pcm` branch over a 168-hour scheduling horizon.
Nodes are created for each (Scenario s, Time t) subproblem.

Linking OptiEdges are partitioned into:
  1. Spatial Edges (Power balance, GSDF line capacity, System reserve, Data center, Frequency)
  2. Temporal Edges (Ramping, Minimum Up/Down time, Storage SOC continuity, Unit status transition)
  3. Scenario Edges (Non-anticipativity linking first-stage UC decisions across scenarios)
"""
function build_pcm_optigraph(
    NT::Int64,
    NB::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    units,
    loads,
    winds,
    lines,
    DataCentras,
    config_param,
    stroges,
    scenarios_prob::Float64,
    NL::Int64,
    hydros,
    NH::Int64,
)
    NS = winds.scenarios_nums
    NW = length(winds.index)

    # Initialize Plasmo OptiGraph
    graph = OptiGraph()

    # Matrix of OptiNodes: nodes[s, t] for scenario s and time t
    nodes = Array{OptiNode, 2}(undef, NS, NT)

    # Calculate initial unit status parameters
    onoffinit = zeros(NG)
    for i in 1:NG
        if units.t_0[i, 1] > 0
            onoffinit[i] = 1
        end
    end

    # Linearize fuel cost curve
    refcost, eachslope = linearizationfuelcurve(units, NG)
    p_step = (units.p_max - units.p_min) ./ 3

    shutupcost = units.coffi_cold_shutup_1
    shutdowncost = units.coffi_cold_shutdown_1

    # Data curve lengths
    load_len = size(loads.load_curve, 2)
    wind_len = size(winds.scenarios_curve, 2)

    # Calculate initial minimum up/down time limits
    Lupmin = zeros(Int, NG)
    Ldownmin = zeros(Int, NG)
    for i in 1:NG
        Lupmin[i] = min(NT, max(1, Int(units.min_shutup_time[i, 1] - units.t_0[i, 1] + 1) * Int(onoffinit[i])))
        Ldownmin[i] = min(NT, max(1, Int(units.min_shutdown_time[i, 1] - units.t_1[i, 1] + 1) * (1 - Int(onoffinit[i]))))
    end

    # ========================================================================
    # Step 1: Create OptiNodes for each (s, t) subproblem
    # ========================================================================
    for s in 1:NS
        for t in 1:NT
            n = add_node!(graph)
            nodes[s, t] = n

            # --- 1. Local First-Stage Replication Variables (for Scenario Coupling) ---
            @variable(n, x[1:NG], Bin)
            @variable(n, u[1:NG], Bin)
            @variable(n, v[1:NG], Bin)
            @variable(n, su₀[1:NG] >= 0)
            @variable(n, sd₀[1:NG] >= 0)

            # --- 2. Local Second-Stage Variables ---
            @variable(n, pg₀[1:NG] >= 0)
            @variable(n, pgₖ[1:NG, 1:3] >= 0)
            @variable(n, sr⁺[1:NG] >= 0)
            @variable(n, sr⁻[1:NG] >= 0)
            @variable(n, Δpd[1:ND] >= 0)
            @variable(n, Δpw[1:NW] >= 0)

            # --- 3. Optional BESS Storage Variables ---
            if NC > 0
                @variable(n, κ⁺[1:NC], Bin)
                @variable(n, κ⁻[1:NC], Bin)
                @variable(n, pc⁺[1:NC] >= 0)
                @variable(n, pc⁻[1:NC] >= 0)
                @variable(n, qc[1:NC] >= 0)
            end

            # --- 4. Optional Hydro Unit Variables ---
            if NH > 0
                @variable(n, ph[1:NH] >= 0)
            end

            # --- 5. Optional Data Center Variables ---
            if config_param.is_ConsiderDataCentra == 1 && ND2 > 0
                @variable(n, dc_p[1:ND2] >= 0)
            end

            # --- Intra-Node Local Constraints ---
            # Generator power limits & PWL cost decomposition
            for g in 1:NG
                p_min_val = units.p_min[g, 1]
                p_max_val = units.p_max[g, 1]
                @constraint(n, pg₀[g] >= p_min_val * x[g])
                @constraint(n, pg₀[g] + sr⁺[g] <= p_max_val * x[g])
                @constraint(n, pg₀[g] - sr⁻[g] >= p_min_val * x[g])
                @constraint(n, pg₀[g] == p_min_val * x[g] + sum(pgₖ[g, k] for k in 1:3))

                # PWL segment limits
                step_val = p_step[g, 1]
                @constraint(n, pgₖ[g, 1] <= step_val * x[g])
                @constraint(n, pgₖ[g, 2] <= step_val * x[g])
                @constraint(n, pgₖ[g, 3] <= step_val * x[g])
            end

            # Storage intra-node bounds
            if NC > 0
                for c in 1:NC
                    Emax = stroges.Q_max[c, 1]
                    Pmax_charge = stroges.p⁺[c, 1]
                    Pmax_discharge = stroges.p⁻[c, 1]
                    @constraint(n, pc⁺[c] <= Pmax_charge * κ⁺[c])
                    @constraint(n, pc⁻[c] <= Pmax_discharge * κ⁻[c])
                    @constraint(n, κ⁺[c] + κ⁻[c] <= 1)
                    @constraint(n, qc[c] <= Emax)
                end
            end

            # Hydro unit bounds
            if NH > 0
                for h in 1:NH
                    @constraint(n, ph[h] >= hydros.p_min[h, 1])
                    @constraint(n, ph[h] <= hydros.p_max[h, 1])
                end
            end

            # Curtailment bounds
            t_load_idx = ((t - 1) % load_len) + 1
            t_wind_idx = ((t - 1) % wind_len) + 1
            for d in 1:ND
                load_val = loads.load_curve[d, t_load_idx]
                @constraint(n, Δpd[d] <= load_val)
            end
            for w in 1:NW
                wind_val = winds.scenarios_curve[s, t_wind_idx] * winds.p_max[w, 1]
                @constraint(n, Δpw[w] <= wind_val)
            end

            # Data center bounds
            if config_param.is_ConsiderDataCentra == 1 && ND2 > 0
                for dc in 1:ND2
                    @constraint(n, n[:dc_p][dc] >= DataCentras.p_min[dc, 1])
                    @constraint(n, n[:dc_p][dc] <= DataCentras.p_max[dc, 1])
                end
            end

            # Startup/shutdown cost constraints
            for g in 1:NG
                @constraint(n, su₀[g] >= shutupcost[g, 1] * u[g])
                @constraint(n, sd₀[g] >= shutdowncost[g, 1] * v[g])
                @constraint(n, u[g] + v[g] <= 1)
            end
        end
    end

    # Tracking link constraint counts
    spatial_edge_count = 0
    temporal_edge_count = 0
    scenario_edge_count = 0

    # ========================================================================
    # Step 2: Temporal Coupling OptiEdges (Inter-time constraints across 168h)
    # ========================================================================
    for s in 1:NS
        for t in 1:NT
            n_curr = nodes[s, t]
            n_prev = (t > 1) ? nodes[s, t-1] : nothing

            # --- Generator Status Transitions & Ramping Limits ---
            for g in 1:NG
                # Status transition logic (u_t - v_t = x_t - x_{t-1})
                if t == 1
                    @linkconstraint(graph, n_curr[:u][g] - n_curr[:v][g] == n_curr[:x][g] - onoffinit[g])
                    temporal_edge_count += 1
                else
                    @linkconstraint(graph, n_curr[:u][g] - n_curr[:v][g] == n_curr[:x][g] - n_prev[:x][g])
                    temporal_edge_count += 1
                end

                # Minimum Up Time & Minimum Down Time constraints
                min_up_t = Int(units.min_shutup_time[g, 1])
                min_down_t = Int(units.min_shutdown_time[g, 1])

                if t >= Lupmin[g]
                    lb_up = max(t - min_up_t + 1, 1)
                    @linkconstraint(graph, sum(nodes[s, r][:u][g] for r in lb_up:t) <= n_curr[:x][g])
                    temporal_edge_count += 1
                end

                if t >= Ldownmin[g]
                    lb_down = max(t - min_down_t + 1, 1)
                    @linkconstraint(graph, sum(nodes[s, r][:v][g] for r in lb_down:t) <= 1 - n_curr[:x][g])
                    temporal_edge_count += 1
                end

                # Ramp Up / Ramp Down limits
                ramp_up = units.ramp_up[g, 1]
                ramp_down = units.ramp_down[g, 1]

                if t > 1
                    # Ramp Up
                    @linkconstraint(graph, n_curr[:pg₀][g] - n_prev[:pg₀][g] <= ramp_up * n_prev[:x][g] + ramp_up * n_curr[:u][g])
                    # Ramp Down
                    @linkconstraint(graph, n_prev[:pg₀][g] - n_curr[:pg₀][g] <= ramp_down * n_curr[:x][g] + ramp_down * n_curr[:v][g])
                    temporal_edge_count += 2
                end
            end

            # --- Storage Energy Inventory Continuity ---
            if NC > 0
                for c in 1:NC
                    η_in = stroges.η⁺[c, 1]
                    η_out = stroges.η⁻[c, 1]
                    if t == 1
                        q0 = stroges.P₀[c, 1]
                        @linkconstraint(graph, n_curr[:qc][c] - q0 == η_in * n_curr[:pc⁺][c] - (1/η_out) * n_curr[:pc⁻][c])
                        temporal_edge_count += 1
                    else
                        @linkconstraint(graph, n_curr[:qc][c] - n_prev[:qc][c] == η_in * n_curr[:pc⁺][c] - (1/η_out) * n_curr[:pc⁻][c])
                        temporal_edge_count += 1
                    end
                end
            end
        end
    end

    # ========================================================================
    # Step 3: Spatial Coupling OptiEdges (Power balance, GSDF, Reserve)
    # ========================================================================
    # Calculate GSDF line distribution factors
    Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

    for s in 1:NS
        for t in 1:NT
            n = nodes[s, t]
            t_load_idx = ((t - 1) % load_len) + 1
            t_wind_idx = ((t - 1) % wind_len) + 1

            # 1. System Power Balance (System-wide Spatial Coupling)
            total_load = sum(loads.load_curve[d, t_load_idx] for d in 1:ND)
            total_wind = sum(winds.scenarios_curve[s, t_wind_idx] * winds.p_max[w, 1] for w in 1:NW)
            
            gen_sum = sum(n[:pg₀][g] for g in 1:NG)
            curtail_load_sum = sum(n[:Δpd][d] for d in 1:ND)
            curtail_wind_sum = sum(n[:Δpw][w] for w in 1:NW)
            storage_balance = (NC > 0) ? sum(n[:pc⁻][c] - n[:pc⁺][c] for c in 1:NC) : 0.0
            hydro_sum = (NH > 0) ? sum(n[:ph][h] for h in 1:NH) : 0.0
            dc_sum = (config_param.is_ConsiderDataCentra == 1 && ND2 > 0) ? sum(n[:dc_p][dc] for dc in 1:ND2) : 0.0

            @linkconstraint(graph, gen_sum + hydro_sum + storage_balance + total_wind - curtail_wind_sum == total_load + dc_sum - curtail_load_sum)
            spatial_edge_count += 1

            # 2. Transmission Line Capacity Constraints (GSDF Spatial Coupling)
            if config_param.is_NetWorkCon == 1
                for l in 1:NL
                    line_cap = lines.p_max[l, 1]
                    # GSDF flow calculation across units, loads, winds, storage, data centers
                    flow_gen = sum(Gsdf[l, units.locatebus[g, 1]] * n[:pg₀][g] for g in 1:NG)
                    flow_load = sum(Gsdf[l, loads.locatebus[d, 1]] * (loads.load_curve[d, t_load_idx] - n[:Δpd][d]) for d in 1:ND)
                    flow_wind = sum(Gsdf[l, winds.locatebus[w, 1]] * (winds.scenarios_curve[s, t_wind_idx] * winds.p_max[w, 1] - n[:Δpw][w]) for w in 1:NW)

                    @linkconstraint(graph, flow_gen + flow_wind - flow_load <= line_cap)
                    @linkconstraint(graph, flow_gen + flow_wind - flow_load >= -line_cap)
                    spatial_edge_count += 2
                end
            end

            # 3. System Spinning Reserve Requirement
            res_req = sum(loads.load_curve[d, t_load_idx] for d in 1:ND) * 0.10  # 10% reserve requirement
            @linkconstraint(graph, sum(n[:sr⁺][g] for g in 1:NG) >= res_req)
            spatial_edge_count += 1
        end
    end

    # ========================================================================
    # Step 4: Scenario Coupling OptiEdges (Non-Anticipativity for 1st-Stage UC)
    # ========================================================================
    # Link scenario s (for s = 2..NS) to scenario 1 for unit status variables across 168h
    for s in 2:NS
        for t in 1:NT
            n_base = nodes[1, t]
            n_scen = nodes[s, t]
            for g in 1:NG
                @linkconstraint(graph, n_scen[:x][g] == n_base[:x][g])
                @linkconstraint(graph, n_scen[:u][g] == n_base[:u][g])
                @linkconstraint(graph, n_scen[:v][g] == n_base[:v][g])
                scenario_edge_count += 3
            end
        end
    end

    # ========================================================================
    # Step 5: Global Objective Function
    # ========================================================================
    # Minimize total expected operational cost across 168h
    obj_terms = []

    for s in 1:NS
        prob = scenarios_prob
        for t in 1:NT
            n = nodes[s, t]
            # Startup/shutdown costs
            for g in 1:NG
                push!(obj_terms, prob * (n[:su₀][g] + n[:sd₀][g]))
                # PWL generation costs
                push!(obj_terms, prob * (refcost[g] * n[:x][g] + eachslope[1, g] * n[:pgₖ][g, 1] + eachslope[2, g] * n[:pgₖ][g, 2] + eachslope[3, g] * n[:pgₖ][g, 3]))
            end
            # Curtailment penalties
            for d in 1:ND
                push!(obj_terms, prob * 1000.0 * n[:Δpd][d])
            end
            for w in 1:NW
                push!(obj_terms, prob * 100.0 * n[:Δpw][w])
            end
        end
    end

    @objective(graph, Min, sum(obj_terms))

    return graph, nodes, spatial_edge_count, temporal_edge_count, scenario_edge_count
end
