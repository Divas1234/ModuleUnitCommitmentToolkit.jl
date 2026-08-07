# ============================================================================
# Main Analysis Runner for Plasmo.jl 3D PCM Graph Modeling (168-Hour Horizon)
#
# References: Cole et al. (2023) "Hierarchical Graph Modeling for Multi-Scale
# Optimization of Power Systems"
# ============================================================================

import Pkg
Pkg.activate(@__DIR__)

using JuMP
using Plasmo
using DataFrames
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
include("plot_168h_detailed_3d_graph.jl")

function run_pcm_3d_analysis()
    println("="^80)
    println("  Running Plasmo.jl 3D OptiGraph Analysis & Visualization for PCM Model (NT=168h)")
    println("  Workspace: ", pwd())
    println("="^80)

    # 1. Load Excel Data
    println("\n[1/5] Reading PCM input data...")
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()

    # 2. Format input parameters
    println("[2/5] Processing input data for 168h graph construction...")
    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT_orig, NC, ND2, NH, DataCentras, hydros = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data, HydroData, HydroCurve
    )

    NT = 168  # Extended 168-hour (1 week) scheduling horizon
    winds, NW = genscenario(WindsFreqParam, 1)
    NS = winds.scenarios_nums
    scenarios_prob = 1.0 / NS

    # 3. Build 3D Plasmo OptiGraph for 168h
    println("[3/5] Constructing 168h 3D Plasmo OptiGraph (Space x Time x Scenario)...")
    graph, nodes, spatial_edges, temporal_edges, scenario_edges = build_pcm_optigraph(
        NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH
    )

    # 4. Analyze OptiGraph Metrics
    println("[4/5] Computing 3D graph topological metrics for 168h horizon...")
    metrics = analyze_optigraph(graph, nodes, spatial_edges, temporal_edges, scenario_edges, NS, NT, NG, NB)

    # Output to terminal
    print_graph_analysis_summary(metrics)

    # 5. Generate Elongated & Color-Coded 3D Graph Visualization Figures
    println("[5/5] Generating elongated & color-coded 3D OptiGraph visualization figures...")
    generate_168h_detailed_visualizations()

    # Generate Markdown Reports in both module directory and res/ directory
    report_file1 = joinpath(@__DIR__, "pcm_3d_graph_report.md")
    res_dir = joinpath(@__DIR__, "..", "res")
    mkpath(res_dir)
    report_file2 = joinpath(res_dir, "pcm_3d_graph_report.md")

    write_markdown_report(report_file1, metrics)
    write_markdown_report(report_file2, metrics)
    println("✓ 168h Analysis & Color-Coded 3D Visualization complete! Output saved to:")
    println("   - $(report_file1)")
    println("   - $(report_file2)")
    println("   - $(joinpath(res_dir, "polygon_figure.png"))")
    println("   - $(joinpath(res_dir, "polygon_figure.pdf"))")
    println("   - $(joinpath(res_dir, "pcm_168h_elongated_detail.png"))")

    return graph, metrics
end

function write_markdown_report(filepath::String, m::Dict)
    buses_val = m[:buses]
    gens_val = m[:generators]
    tdim_val = m[:temporal_dim]
    sdim_val = m[:scenario_dim]
    nnodes_val = m[:num_nodes]
    tvars_val = m[:total_vars]
    tnodecons_val = m[:total_node_cons]
    nlinks_val = m[:num_link_constraints]
    tcons_val = m[:total_constraints]
    avars_val = m[:avg_vars]
    acons_val = m[:avg_cons]
    sedge_val = m[:spatial_edges]
    spct_val = m[:spatial_pct]
    tedge_val = m[:temporal_edges]
    tpct_val = m[:temporal_pct]
    oedge_val = m[:scenario_edges]
    opct_val = m[:scenario_pct]
    density_val = m[:coupling_density_pct]

    content = """# Plasmo.jl 3D Hypergraph Structure Analysis Report for PCM Model (168-Hour Horizon)

> **Reference Methodology**: Cole et al. (2023) *“Hierarchical Graph Modeling for Multi-Scale Optimization of Power Systems”*  
> **Generated Timestamp**: $(Dates.now())  
> **Horizon**: 168 Hours (1 Week / 7 Days)  
> **Branch**: `pcm`

---

## 1. Executive Summary

This report presents a formal **three-dimensional hypergraph analysis** of the Stochastic Unit Commitment (PCM) model extended to a **168-hour (1-week)** scheduling horizon using **`Plasmo.jl`**. Modern power system operations span multiple spatial, temporal, and stochastic scales. Following the graph abstraction in **Cole et al. (2023)**, the optimization problem is structured as an **`OptiGraph` tensor** G = (V, E) spanning:
- **Spatial Dimension (S)**: $(buses_val) Buses, $(gens_val) Thermal Units, Transmission Grid
- **Temporal Dimension (T)**: $(tdim_val) Hours horizon (1 Week)
- **Stochastic Dimension (Omega)**: $(sdim_val) Wind/Solar Scenarios

---

## 2. 168-Hour Elongated 3D Tensor Graph Visualization

![3D Multi-Scale OptiGraph Layout](polygon_figure.png)

### Constraint Color-Coding Key:
- Crimson Red: Intra-Day UC Temporal Constraints (Ramping & Status transitions within Days 1..7).
- Bright Gold / Amber (Thick): Day-Boundary Coupling Constraints (t = 24d -> 24d+1).
- Cyan / Deep Blue: Spatial Grid Constraints (Bus balance & GSDF line capacity limits).
- Purple: Stochastic Scenario Constraints (First-Stage UC Non-Anticipativity).

---

## 3. 3D Tensor Graph Dimensions & Scale

| Metric Dimension | Parameter Symbol | Value | Scale Description |
| :--- | :--- | :--- | :--- |
| **Spatial Nodes** | S | $(buses_val) Buses / $(gens_val) Units | Power grid spatial topology & bus balance |
| **Temporal Horizon** | T | $(tdim_val) Hours | 168-Hour (1-week) operational dispatch periods |
| **Stochastic Scenarios** | Omega | $(sdim_val) Scenarios | Wind power uncertainty realizations |
| **Total OptiNodes |V|** | |V| = NS x NT | **$(nnodes_val)** | Subproblem OptiNodes (5 scenarios x 168 hours) |

---

## 4. Quantitative Graph Topology & Problem Scale

| Topological Metric | Plasmo.jl OptiGraph Value | Description |
| :--- | :--- | :--- |
| **Total OptiNodes |V|** | **$(nnodes_val)** | Subproblems partitioned by (s, t) grid |
| **Total Variables** | **$(tvars_val)** | Continuous & binary decision variables |
| **Intra-Node Constraints** | **$(tnodecons_val)** | Generator Pmin/Pmax, PWL cost, storage bounds |
| **Inter-Node Coupling Edges |E|** | **$(nlinks_val)** | Coupling OptiEdges across space, time, and scenarios |
| **Total Problem Constraints** | **$(tcons_val)** | Combined model constraint count |
| **Avg. Node Subproblem Size** | **$(avars_val) vars / $(acons_val) cons** | Average size per subproblem OptiNode |
| **Inter-Node Sparsity** | **$(density_val)%** | Coupling hyperedge matrix density |

---

## 5. Three-Dimensional Coupling Edge Breakdown (OptiEdges)

The coupling constraints (OptiEdges) link local OptiNodes across the three primary axes:

```mermaid
graph TD
    A[168h Plasmo 3D OptiGraph G] --> B[Spatial Couplings E_S: $(sedge_val) edges ($(spct_val)%)]
    A --> C[Temporal Couplings E_T: $(tedge_val) edges ($(tpct_val)%)]
    A --> D[Scenario Couplings E_Omega: $(oedge_val) edges ($(opct_val)%)]
    
    B --> B1[Bus Power Balance]
    B --> B2[GSDF Line Flow Limits]
    B --> B3[System Reserve Req.]

    C --> C1[Generator Ramp Up/Down (Intra-Day vs. Day-Boundary)]
    C --> C2[Unit Status Transition (Intra-Day vs. Day-Boundary)]
    C --> C3[ESS SOC Inventory (Continuous across 168h)]

    D --> D1[First-stage UC Non-Anticipativity (168h)]
```

### Coupling Distribution Details:
1. **Spatial Couplings (E_S)**: **$(sedge_val)** edges ($(spct_val)%)
   - Bus power balance, transmission line flow limits (GSDF), and system spinning reserves.
2. **Temporal Couplings (E_T)**: **$(tedge_val)** edges ($(tpct_val)%)
   - Generator ramp-rate limits, unit startup/shutdown transitions, and ESS energy SOC continuity across 168 hours.
3. **Stochastic Couplings (E_Omega)**: **$(oedge_val)** edges ($(opct_val)%)
   - Non-anticipativity constraints enforcing identical first-stage unit commitment decisions (x_{g,t}) across scenarios s = 1...NS.

---

## 6. Multi-Scale Algorithmic Decomposition Strategies (Cole et al. 2023)

Based on the 3D hypergraph structure of the PCM model over 168 hours, Cole et al. (2023) highlight three distinct decomposition paradigms:

### A. Scenario Partitioning (Benders / Progressive Hedging)
- **Coupling Bottleneck**: Concentrated exclusively in the **$(oedge_val)** Non-Anticipativity OptiEdges (E_Omega).
- **Decomposition Effect**: Removing E_Omega decouples the 168h problem into **$(sdim_val)** completely independent 168-hour deterministic UC subproblems.
- **Suitability**: **Very High**. Excellent for parallel implementation across CPU clusters.

### B. Temporal Partitioning (Dynamic Programming / Dantzig-Wolfe)
- **Coupling Bottleneck**: **$(tedge_val)** temporal edges (E_T) connecting adjacent hours t-1 -> t.
- **Decomposition Effect**: Removing E_T decouples the model into $(tdim_val) hourly spatial dispatch subproblems.
- **Suitability**: High for rolling-horizon or long-term multi-stage planning models.

### C. Spatial Partitioning (ADMM / Network Tearing)
- **Coupling Bottleneck**: **$(sedge_val)** spatial edges (E_S) representing transmission limits and power balance.
- **Decomposition Effect**: Decouples grid into regional/zonal subproblems.
- **Suitability**: High for multi-regional co-optimization and distributed market clearing.
"""
    write(filepath, content)
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_pcm_3d_analysis()
end
