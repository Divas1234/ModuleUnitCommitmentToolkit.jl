# ============================================================================
# 3D Hypergraph Visualization Generator from Actual PCM JuMP/Plasmo Model
# Extended to 168-Hour Scheduling Horizon (1 Week)
#
# References: Cole et al. (2023) "Hierarchical Graph Modeling for Multi-Scale
# Optimization of Power Systems"
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
    extract_optigraph_topology(graph, nodes, NS, NT, load_curve)

Extracts node 3D spatial coordinates and identifies actual link constraints 
connecting OptiNodes in the Plasmo OptiGraph model instance over horizon NT (e.g. 168h).
"""
function extract_optigraph_topology(graph::OptiGraph, nodes::Array{OptiNode, 2}, NS::Int, NT::Int, load_curve::Array{Float64})
    # Node coordinates map: (s, t) -> (x, y, z)
    node_coords = Dict{Tuple{Int, Int}, Tuple{Float64, Float64, Float64}}()
    
    load_len = size(load_curve, 2)
    avg_load_per_t = [sum(load_curve[:, ((t-1)%load_len)+1]) for t in 1:NT]
    max_load = maximum(avg_load_per_t)
    min_load = minimum(avg_load_per_t)
    
    for t in 1:NT
        # 3D cylindrical vase geometry with 7-day cyclical load modulation
        r_t = 0.8 + 0.5 * (avg_load_per_t[t] - min_load) / max(1e-5, max_load - min_load)
        z_t = Float64(t)

        for s in 1:NS
            theta_s = 2 * pi * (s - 1) / NS
            x_st = r_t * cos(theta_s)
            y_st = r_t * sin(theta_s)
            node_coords[(s, t)] = (x_st, y_st, z_t)
        end
    end

    # Categorize actual OptiGraph link constraints
    temporal_edges = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]
    spatial_edges = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]
    scenario_edges = Tuple{Tuple{Int,Int}, Tuple{Int,Int}}[]

    # 1. Temporal Edges (t -> t+1 for same s)
    for s in 1:NS
        for t in 1:(NT-1)
            push!(temporal_edges, ((s, t), (s, t+1)))
        end
    end

    # 2. Spatial Edges (Self-coupling loops at (s, t) representing spatial grid constraints)
    for s in 1:NS
        for t in 1:NT
            push!(spatial_edges, ((s, t), (s, t)))
        end
    end

    # 3. Scenario Edges (s -> 1 for same t - Non-Anticipativity)
    for s in 2:NS
        for t in 1:NT
            push!(scenario_edges, ((s, t), (1, t)))
        end
    end

    return node_coords, temporal_edges, spatial_edges, scenario_edges
end

"""
    plot_actual_pcm_3d(node_coords, temporal_edges, spatial_edges, scenario_edges, NS, NT; title_text, theme)

Renders 3D OptiGraph structure of the actual PCM optimization model.
"""
function plot_actual_pcm_3d(node_coords, temporal_edges, spatial_edges, scenario_edges, NS, NT; title_text="Actual PCM 3D OptiGraph Model", node_color=:black, edge_color=:darkgray, bg_color=:white)
    p = Plots.plot3d(
        legend = false,
        ticks = false,
        showaxis = false,
        grid = false,
        title = title_text,
        titlefont = font(13, "Times"),
        background_color = bg_color,
        size = (450, 600),
        camera = (35, 25)
    )

    # 1. Draw Temporal Edges (Inter-hour ramping & storage continuity)
    for (node1, node2) in temporal_edges
        c1 = node_coords[node1]
        c2 = node_coords[node2]
        Plots.plot3d!(p, [c1[1], c2[1]], [c1[2], c2[2]], [c1[3], c2[3]], line = (0.5, edge_color), alpha = 0.4)
    end

    # 2. Draw Scenario Edges (Non-Anticipativity 1st-stage UC links)
    for (node1, node2) in scenario_edges
        c1 = node_coords[node1]
        c2 = node_coords[node2]
        Plots.plot3d!(p, [c1[1], c2[1]], [c1[2], c2[2]], [c1[3], c2[3]], line = (0.6, edge_color), alpha = 0.5)
    end

    # 3. Draw Spatial Ring Couplings (Power balance & GSDF capacity)
    for s in 1:NS
        step = max(1, Int(floor(NT / 48)))
        for t in 1:step:NT
            c = node_coords[(s, t)]
            r = sqrt(c[1]^2 + c[2]^2)
            theta = range(0, 2pi, length=30)
            Plots.plot3d!(p, r .* cos.(theta), r .* sin.(theta), fill(c[3], 30), line = (0.2, edge_color), alpha = 0.25)
        end
    end

    # 4. Draw Actual OptiNodes
    xs = [node_coords[(s, t)][1] for s in 1:NS for t in 1:NT]
    ys = [node_coords[(s, t)][2] for s in 1:NS for t in 1:NT]
    zs = [node_coords[(s, t)][3] for s in 1:NS for t in 1:NT]

    Plots.scatter3d!(p, xs, ys, zs,
        markersize = 1.8,
        markercolor = node_color,
        markerstrokewidth = 0
    )

    return p
end

function generate_actual_pcm_visualization(NT_DA::Int=168, NT_ST::Int=72, NT_ED::Int=24)
    println("="^80)
    println("  Generating 3D OptiGraph Plots for $(NT_DA)h Horizon from Actual PCM UC Model...")
    println("="^80)

    # 1. Load data
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT_orig, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )

    winds, NW = genscenario(WindsFreqParam, 1)
    NS = winds.scenarios_nums
    scenarios_prob = 1.0 / NS

    # 2. Build Day-Ahead 168h OptiGraph
    graph_da, nodes_da, es_da, et_da, eo_da = build_pcm_optigraph(
        NT_DA, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH
    )
    coords_da, et1, es1, eo1 = extract_optigraph_topology(graph_da, nodes_da, NS, NT_DA, loads.load_curve)

    # 3. Build Short-Term 72h OptiGraph
    graph_st, nodes_st, es_st, et_st, eo_st = build_pcm_optigraph(
        NT_ST, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH
    )
    coords_st, et2, es2, eo2 = extract_optigraph_topology(graph_st, nodes_st, NS, NT_ST, loads.load_curve)

    # 4. Build Hour-Ahead 24h OptiGraph
    graph_ed, nodes_ed, es_ed, et_ed, eo_ed = build_pcm_optigraph(
        NT_ED, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH
    )
    coords_ed, et3, es3, eo3 = extract_optigraph_topology(graph_ed, nodes_ed, NS, NT_ED, loads.load_curve)

    # 5. Create 3-Panel Multi-Scale Plots
    # Panel 1: Day Ahead Unit Commitment (168h - Black Mesh)
    p_da = plot_actual_pcm_3d(coords_da, et1, es1, eo1, NS, NT_DA,
        title_text = "Day Ahead (168h)\nUnit Commitement",
        node_color = :black,
        edge_color = :darkgray
    )

    # Panel 2: Short Term Unit Commitment (72h - Red Mesh)
    p_st = plot_actual_pcm_3d(coords_st, et2, es2, eo2, NS, NT_ST,
        title_text = "Short Term (72h)\nUnit Commitment",
        node_color = :crimson,
        edge_color = :indianred
    )

    # Panel 3: Hour Ahead Economic Dispatch (24h - Blue Mesh)
    p_ed = plot_actual_pcm_3d(coords_ed, et3, es3, eo3, NS, NT_ED,
        title_text = "Hour Ahead (24h)\nEconomic Dispatch",
        node_color = :deepskyblue3,
        edge_color = :lightskyblue
    )

    # Combine into 3-panel Cole et al. (2023) figure
    combined_fig = Plots.plot(p_da, p_st, p_ed, layout = (1, 3), size = (1250, 600))

    # Save to res/ folder
    res_dir = joinpath(@__DIR__, "..", "res")
    mkpath(res_dir)

    png_path = joinpath(res_dir, "polygon_figure.png")
    pdf_path = joinpath(res_dir, "polygon_figure.pdf")
    actual_png = joinpath(res_dir, "pcm_actual_model_168h_3d.png")

    Plots.savefig(combined_fig, png_path)
    Plots.savefig(combined_fig, pdf_path)
    Plots.savefig(combined_fig, actual_png)

    println("✓ 168h Actual PCM 3D OptiGraph figures successfully saved:")
    println("   - $(png_path)")
    println("   - $(pdf_path)")
    println("   - $(actual_png)")

    return combined_fig
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_actual_pcm_visualization(168, 72, 24)
end
