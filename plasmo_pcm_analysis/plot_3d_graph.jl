# ============================================================================
# 3D Hypergraph Visualization Generator for Power System Optimization Models
#
# References: Cole et al. (2023) "Hierarchical Graph Modeling for Multi-Scale
# Optimization of Power Systems"
# ============================================================================

import Pkg
Pkg.activate(@__DIR__)

using Plots
using LinearAlgebra
using Random

# Set plotting backend
gr()

"""
    generate_3d_graph_layout(NT, NS, NB; radius_func, height_scale, noise)

Computes 3D spatial-temporal-scenario node coordinates (X, Y, Z) and edge sets
for an OptiGraph structure.
"""
function generate_3d_graph_layout(NT::Int, NS::Int, NB::Int; R0=1.0, z_scale=1.0, shape_type=:vase)
    nodes_x = Float64[]
    nodes_y = Float64[]
    nodes_z = Float64[]
    node_labels = Tuple{Int,Int,Int}[]  # (s, t, b)

    for t in 1:NT
        # Radial modulation for vase/cylinder shape as in Cole et al. (2023)
        t_norm = (t - 1) / max(1, NT - 1)
        r_mod = if shape_type == :vase
            1.0 + 0.4 * sin(2 * pi * t_norm) + 0.15 * cos(4 * pi * t_norm)
        elseif shape_type == :barrel
            1.2 + 0.3 * sin(pi * t_norm)
        else
            1.0
        end

        for s in 1:NS
            # Scenario angle around the z-axis
            theta_s = 2 * pi * (s - 1) / NS
            for b in 1:NB
                # Bus perturbation around scenario position
                phi_b = 2 * pi * (b - 1) / (NB * NS)
                r_total = R0 * r_mod + 0.1 * (b - 1) / max(1, NB)
                
                x = r_total * cos(theta_s + phi_b)
                y = r_total * sin(theta_s + phi_b)
                z = t * z_scale

                push!(nodes_x, x)
                push!(nodes_y, y)
                push!(nodes_z, z)
                push!(node_labels, (s, t, b))
            end
        end
    end

    total_nodes = length(nodes_x)
    node_dict = Dict(node_labels[i] => i for i in 1:total_nodes)

    # Build coupling edges
    edges_temporal = Tuple{Int, Int}[]
    edges_spatial = Tuple{Int, Int}[]
    edges_scenario = Tuple{Int, Int}[]

    for (s, t, b) in node_labels
        curr_idx = node_dict[(s, t, b)]

        # Temporal edge: t -> t + 1
        if t < NT && haskey(node_dict, (s, t + 1, b))
            push!(edges_temporal, (curr_idx, node_dict[(s, t + 1, b)]))
        end

        # Spatial edge: b -> b + 1
        b_next = (b % NB) + 1
        if haskey(node_dict, (s, t, b_next))
            push!(edges_spatial, (curr_idx, node_dict[(s, t, b_next)]))
        end

        # Scenario edge: s -> s + 1 (Non-anticipativity coupling)
        if s > 1 && haskey(node_dict, (1, t, b))
            push!(edges_scenario, (curr_idx, node_dict[(1, t, b)]))
        end
    end

    return nodes_x, nodes_y, nodes_z, edges_spatial, edges_temporal, edges_scenario
end

"""
    plot_subgraph_3d(nodes_x, nodes_y, nodes_z, E_S, E_T, E_Omega; title_text, main_color)

Renders a 3D OptiGraph layout plot.
"""
function plot_subgraph_3d(nodes_x, nodes_y, nodes_z, E_S, E_T, E_Omega; title_text="", node_color=:black, edge_color=:gray, bg_color=:white)
    p = plot3d(
        legend = false,
        ticks = false,
        showaxis = false,
        grid = false,
        title = title_text,
        titlefont = font(14, "Times"),
        background_color = bg_color,
        size = (400, 500),
        camera = (30, 25)
    )

    # 1. Draw Temporal Edges
    for (i, j) in E_T
        plot3d!(p, [nodes_x[i], nodes_x[j]], [nodes_y[i], nodes_y[j]], [nodes_z[i], nodes_z[j]],
            line = (0.3, edge_color), alpha = 0.3)
    end

    # 2. Draw Spatial Edges
    for (i, j) in E_S
        plot3d!(p, [nodes_x[i], nodes_x[j]], [nodes_y[i], nodes_y[j]], [nodes_z[i], nodes_z[j]],
            line = (0.5, edge_color), alpha = 0.4)
    end

    # 3. Draw Scenario Edges
    for (i, j) in E_Omega
        plot3d!(p, [nodes_x[i], nodes_x[j]], [nodes_y[i], nodes_y[j]], [nodes_z[i], nodes_z[j]],
            line = (0.6, edge_color), alpha = 0.5)
    end

    # 4. Draw OptiNodes
    scatter3d!(p, nodes_x, nodes_y, nodes_z,
        markersize = 1.5,
        markercolor = node_color,
        markerstrokewidth = 0
    )

    return p
end

function generate_cole_2023_figure()
    println("="^80)
    println("  Generating 3D OptiGraph Visualization (Cole et al. 2023 Style)...")
    println("="^80)

    # 1. Day Ahead Unit Commitment (DA-UC) - Black/Dark Mesh
    println("  - Building Day Ahead Unit Commitment 3D layout...")
    x1, y1, z1, es1, et1, eo1 = generate_3d_graph_layout(48, 12, 4, R0=1.2, z_scale=0.8, shape_type=:vase)
    p1 = plot_subgraph_3d(x1, y1, z1, es1, et1, eo1,
        title_text = "Day Ahead\nUnit Commitment",
        node_color = :black,
        edge_color = :darkgray
    )

    # 2. Short Term Unit Commitment (ST-UC) - Red Mesh
    println("  - Building Short Term Unit Commitment 3D layout...")
    x2, y2, z2, es2, et2, eo2 = generate_3d_graph_layout(40, 10, 4, R0=1.1, z_scale=0.7, shape_type=:vase)
    p2 = plot_subgraph_3d(x2, y2, z2, es2, et2, eo2,
        title_text = "Short Term\nUnit Commitment",
        node_color = :red,
        edge_color = :lightcoral
    )

    # 3. Hour Ahead Economic Dispatch (HA-ED) - Blue Barrel Mesh
    println("  - Building Hour Ahead Economic Dispatch 3D layout...")
    x3, y3, z3, es3, et3, eo3 = generate_3d_graph_layout(16, 8, 4, R0=1.4, z_scale=0.6, shape_type=:barrel)
    p3 = plot_subgraph_3d(x3, y3, z3, es3, et3, eo3,
        title_text = "Hour Ahead\nEconomic Dispatch",
        node_color = :dodgerblue,
        edge_color = :lightskyblue
    )

    # Combine into 3-panel side-by-side multi-scale figure
    combined_plot = plot(p1, p2, p3, layout = (1, 3), size = (1200, 500))

    # Output paths
    res_dir = joinpath(@__DIR__, "..", "res")
    mkpath(res_dir)
    
    png_path = joinpath(res_dir, "polygon_figure.png")
    pdf_path = joinpath(res_dir, "polygon_figure.pdf")
    png_path_module = joinpath(@__DIR__, "pcm_3d_graph_visualization.png")

    savefig(combined_plot, png_path)
    savefig(combined_plot, pdf_path)
    savefig(combined_plot, png_path_module)

    println("✓ 3D OptiGraph figures successfully saved:")
    println("   - $(png_path)")
    println("   - $(pdf_path)")
    println("   - $(png_path_module)")

    return combined_plot
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_cole_2023_figure()
end
