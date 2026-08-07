# ============================================================================
# High-Detail Elongated 3D Hypergraph Visualization Generator (168h Horizon)
# 
# Features:
# - Vertically elongated 3D cylindrical geometry (168 Hours / 7 Days)
# - Color-coded constraint categories:
#   * Intra-Day UC Constraints (Ramping & Status within Day 1..7): Crimson Red
#   * Day-Boundary Coupling Constraints (t=24d -> 24d+1 links): Bright Gold / Amber
#   * Spatial Grid Constraints (Power balance & GSDF capacity): Cyan / Deep Blue
#   * Scenario Non-Anticipativity Constraints (1st-stage UC coupling): Purple
# ============================================================================

import Pkg
Pkg.activate(@__DIR__)

using JuMP
using Plasmo
using Plots
using LinearAlgebra
using Dates
using Random

# Include core codebase dependencies from parent directory
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

include(joinpath(@__DIR__, "..", "src", "renewableresource_modules", "stochasticsimulation.jl"))
include(joinpath(@__DIR__, "..", "src", "read_inputdata_modules", "readdatas.jl"))
include(joinpath(@__DIR__, "..", "src", "unitcommitment_model_modules", "utilitie_modules_lib", "utilities.jl"))

include("build_plasmo_pcm.jl")
include("graph_analyzer.jl")

Plots.gr()

"""
    extract_168h_colored_topology(graph, nodes, NS, NT, load_curve)

Extracts 3D coordinates and classifies OptiGraph coupling constraints into 
distinct physical/temporal categories (Intra-day UC, Day-boundary, Spatial, Scenario).
"""
function extract_168h_colored_topology(graph::OptiGraph, nodes::Array{OptiNode, 2}, NS::Int, NT::Int, load_curve::Array{Float64})
    node_coords = Dict{Tuple{Int, Int}, Tuple{Float64, Float64, Float64}}()
    
    load_len = size(load_curve, 2)
    avg_load_per_t = [sum(load_curve[:, ((t-1)%load_len)+1]) for t in 1:NT]
    max_load = maximum(avg_load_per_t)
    min_load = minimum(avg_load_per_t)
    
    # Vertically elongated scale factor for 168 hours
    z_scale = 1.8  # Elongates z-axis
    
    for t in 1:NT
        # 7-day cyclical daily load profile modulation
        r_t = 1.0 + 0.5 * (avg_load_per_t[t] - min_load) / max(1e-5, max_load - min_load)
        z_t = t * z_scale

        for s in 1:NS
            theta_s = 2 * pi * (s - 1) / NS
            x_st = r_t * cos(theta_s)
            y_st = r_t * sin(theta_s)
            node_coords[(s, t)] = (x_st, y_st, z_t)
        end
    end

    # Edge Classifications
    edges_intra_day_temporal = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]
    edges_boundary_temporal = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]
    edges_spatial = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]
    edges_scenario = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]

    # 1. Temporal Edges: Separate Intra-day from Day-Boundary (t = 24, 48, 72, 96, 120, 144 -> t+1)
    for s in 1:NS
        for t in 1:(NT-1)
            if t % 24 == 0
                # Day-Boundary Coupling Edge
                push!(edges_boundary_temporal, ((s, t), (s, t+1)))
            else
                # Intra-Day UC Temporal Edge
                push!(edges_intra_day_temporal, ((s, t), (s, t+1)))
            end
        end
    end

    # 2. Spatial Edges (Hourly Grid Constraints)
    for s in 1:NS
        for t in 1:NT
            push!(edges_spatial, ((s, t), (s, t)))
        end
    end

    # 3. Scenario Non-Anticipativity Edges
    for s in 2:NS
        for t in 1:NT
            push!(edges_scenario, ((s, t), (1, t)))
        end
    end

    return node_coords, edges_intra_day_temporal, edges_boundary_temporal, edges_spatial, edges_scenario
end

"""
    plot_elongated_colored_3d(node_coords, e_intraday, e_boundary, e_spatial, e_scenario, NS, NT; title_text)

Plots an elongated, color-coded 3D OptiGraph structure highlighting daily UC and day-boundary coupling.
"""
function plot_elongated_colored_3d(
    node_coords,
    e_intraday,
    e_boundary,
    e_spatial,
    e_scenario,
    NS::Int,
    NT::Int;
    title_text="168h PCM 3D OptiGraph Model"
)
    p = Plots.plot3d(
        legend = :topright,
        ticks = false,
        showaxis = false,
        grid = false,
        title = title_text,
        titlefont = font(14, "Times", :bold),
        background_color = :white,
        size = (700, 1100),  # Elongated vertical proportions (700 x 1100)
        camera = (32, 20)
    )

    # 1. Draw Intra-Day UC Temporal Edges (Crimson Red)
    first_intra = true
    for (node1, node2) in e_intraday
        c1 = node_coords[node1]
        c2 = node_coords[node2]
        lbl = first_intra ? "Intra-Day UC Links (Daily Ramp/Status)" : ""
        first_intra = false
        Plots.plot3d!(p, [c1[1], c2[1]], [c1[2], c2[2]], [c1[3], c2[3]], 
            line = (0.7, :crimson), alpha = 0.45, label = lbl)
    end

    # 2. Draw Day-Boundary Coupling Edges (Bright Gold / Amber - Thick)
    first_boundary = true
    for (node1, node2) in e_boundary
        c1 = node_coords[node1]
        c2 = node_coords[node2]
        lbl = first_boundary ? "Day-Boundary Coupling Links (t=24d->24d+1)" : ""
        first_boundary = false
        Plots.plot3d!(p, [c1[1], c2[1]], [c1[2], c2[2]], [c1[3], c2[3]], 
            line = (2.5, :orange), alpha = 0.9, label = lbl)
    end

    # 3. Draw Scenario Non-Anticipativity Edges (Purple / Violet)
    first_scen = true
    for (node1, node2) in e_scenario
        c1 = node_coords[node1]
        c2 = node_coords[node2]
        lbl = first_scen ? "Scenario Non-Anticipativity Links (UC 1st-Stage)" : ""
        first_scen = false
        Plots.plot3d!(p, [c1[1], c2[1]], [c1[2], c2[2]], [c1[3], c2[3]], 
            line = (0.8, :purple), alpha = 0.5, label = lbl)
    end

    # 4. Draw Spatial Ring Couplings (Cyan / Deep Blue)
    first_spatial = true
    for s in 1:NS
        # Draw spatial rings every 12 hours for clear visualization
        for t in 1:12:NT
            c = node_coords[(s, t)]
            r = sqrt(c[1]^2 + c[2]^2)
            theta = range(0, 2pi, length=35)
            lbl = (first_spatial && s == 1 && t == 1) ? "Spatial Grid Couplings (Balance/GSDF)" : ""
            first_spatial = false
            Plots.plot3d!(p, r .* cos.(theta), r .* sin.(theta), fill(c[3], 35), 
                line = (0.5, :deepskyblue3), alpha = 0.35, label = lbl)
        end
    end

    # 5. Highlight Day Boundaries with Horizontal Planes / Markers
    for d in 1:6
        t_bound = d * 24
        z_bound = t_bound * 1.8
        # Draw subtle day-separator ring
        theta = range(0, 2pi, length=50)
        r_bound = 1.6
        Plots.plot3d!(p, r_bound .* cos.(theta), r_bound .* sin.(theta), fill(z_bound, 50),
            line = (1.2, :goldenrod, :dash), alpha = 0.7, label = "")
    end

    # 6. Draw Actual OptiNodes (840 nodes)
    xs = [node_coords[(s, t)][1] for s in 1:NS for t in 1:NT]
    ys = [node_coords[(s, t)][2] for s in 1:NS for t in 1:NT]
    zs = [node_coords[(s, t)][3] for s in 1:NS for t in 1:NT]

    Plots.scatter3d!(p, xs, ys, zs,
        markersize = 1.6,
        markercolor = :black,
        markerstrokewidth = 0,
        label = "OptiNodes (s, t Subproblems)"
    )

    return p
end

function generate_168h_detailed_visualizations()
    println("="^80)
    println("  Generating Elongated & Color-Coded 3D OptiGraph Plots (168h)...")
    println("="^80)

    # 1. Load data
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT_orig, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )

    NT = 168
    winds, NW = genscenario(WindsFreqParam, 1)
    NS = winds.scenarios_nums
    scenarios_prob = 1.0 / NS

    # 2. Build 168h OptiGraph
    graph, nodes, es, et, eo = build_pcm_optigraph(
        NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH
    )

    # 3. Extract colored topology
    node_coords, e_intra, e_bound, e_spatial, e_scen = extract_168h_colored_topology(graph, nodes, NS, NT, loads.load_curve)

    # 4. Generate Main Standalone Elongated Figure (700 x 1100)
    println("  - Rendering standalone 168h elongated OptiGraph figure...")
    p_main = plot_elongated_colored_3d(node_coords, e_intra, e_bound, e_spatial, e_scen, NS, NT,
        title_text = "Plasmo.jl 3D OptiGraph Model (168-Hour / 7-Day Horizon)\n[Intra-Day UC vs. Day-Boundary Coupling]"
    )

    # 5. Generate 3-Panel Multi-Scale Comparison Figure (Elongated)
    println("  - Rendering 3-Panel multi-scale comparison figure...")
    p1 = plot_elongated_colored_3d(node_coords, e_intra, e_bound, e_spatial, e_scen, NS, NT,
        title_text = "Day Ahead (168h)\nUnit Commitment"
    )

    # Short Term 72h Layout
    coords_72, e_intra_72, e_bound_72, e_spatial_72, e_scen_72 = extract_168h_colored_topology(graph, nodes, NS, 72, loads.load_curve)
    p2 = plot_elongated_colored_3d(coords_72, e_intra_72, e_bound_72, e_spatial_72, e_scen_72, NS, 72,
        title_text = "Short Term (72h)\nUnit Commitment"
    )

    # Hour Ahead 24h Layout
    coords_24, e_intra_24, e_bound_24, e_spatial_24, e_scen_24 = extract_168h_colored_topology(graph, nodes, NS, 24, loads.load_curve)
    p3 = plot_elongated_colored_3d(coords_24, e_intra_24, e_bound_24, e_spatial_24, e_scen_24, NS, 24,
        title_text = "Hour Ahead (24h)\nEconomic Dispatch"
    )

    combined_fig = Plots.plot(p1, p2, p3, layout = (1, 3), size = (1400, 900))

    # Save to res/ folder
    res_dir = joinpath(@__DIR__, "..", "res")
    mkpath(res_dir)

    png_path = joinpath(res_dir, "polygon_figure.png")
    pdf_path = joinpath(res_dir, "polygon_figure.pdf")
    standalone_png = joinpath(res_dir, "pcm_168h_elongated_detail.png")
    standalone_pdf = joinpath(res_dir, "pcm_168h_elongated_detail.pdf")

    Plots.savefig(combined_fig, png_path)
    Plots.savefig(combined_fig, pdf_path)
    Plots.savefig(p_main, standalone_png)
    Plots.savefig(p_main, standalone_pdf)

    println("✓ Elongated & color-coded 3D OptiGraph figures saved:")
    println("   - $(png_path)")
    println("   - $(pdf_path)")
    println("   - $(standalone_png)")
    println("   - $(standalone_pdf)")

    return p_main
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_168h_detailed_visualizations()
end
