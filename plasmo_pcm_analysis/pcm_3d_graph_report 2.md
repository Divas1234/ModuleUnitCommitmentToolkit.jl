# Plasmo.jl 3D Hypergraph Structure Analysis Report for PCM Model (168-Hour Horizon)

> **Reference Methodology**: Cole et al. (2023) *“Hierarchical Graph Modeling for Multi-Scale Optimization of Power Systems”*  
> **Generated Timestamp**: 2026-07-21T22:51:23.261  
> **Horizon**: 168 Hours (1 Week / 7 Days)  
> **Branch**: `pcm`

---

## 1. Executive Summary

This report presents a formal **three-dimensional hypergraph analysis** of the Stochastic Unit Commitment (PCM) model extended to a **168-hour (1-week)** scheduling horizon using **`Plasmo.jl`**. Modern power system operations span multiple spatial, temporal, and stochastic scales. Following the graph abstraction in **Cole et al. (2023)**, the optimization problem is structured as an **`OptiGraph` tensor** G = (V, E) spanning:
- **Spatial Dimension (S)**: 6 Buses, 3 Thermal Units, Transmission Grid
- **Temporal Dimension (T)**: 168 Hours horizon (1 Week)
- **Stochastic Dimension (Omega)**: 5 Wind/Solar Scenarios

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
| **Spatial Nodes** | S | 6 Buses / 3 Units | Power grid spatial topology & bus balance |
| **Temporal Horizon** | T | 168 Hours | 168-Hour (1-week) operational dispatch periods |
| **Stochastic Scenarios** | Omega | 5 Scenarios | Wind power uncertainty realizations |
| **Total OptiNodes |V|** | |V| = NS x NT | **840** | Subproblem OptiNodes (5 scenarios x 168 hours) |

---

## 4. Quantitative Graph Topology & Problem Scale

| Topological Metric | Plasmo.jl OptiGraph Value | Description |
| :--- | :--- | :--- |
| **Total OptiNodes |V|** | **840** | Subproblems partitioned by (s, t) grid |
| **Total Variables** | **42840** | Continuous & binary decision variables |
| **Intra-Node Constraints** | **46200** | Generator Pmin/Pmax, PWL cost, storage bounds |
| **Inter-Node Coupling Edges |E|** | **32898** | Coupling OptiEdges across space, time, and scenarios |
| **Total Problem Constraints** | **79098** | Combined model constraint count |
| **Avg. Node Subproblem Size** | **51.0 vars / 55.0 cons** | Average size per subproblem OptiNode |
| **Inter-Node Sparsity** | **0.0039%** | Coupling hyperedge matrix density |

---

## 5. Three-Dimensional Coupling Edge Breakdown (OptiEdges)

The coupling constraints (OptiEdges) link local OptiNodes across the three primary axes:

```mermaid
graph TD
    A[168h Plasmo 3D OptiGraph G] --> B[Spatial Couplings E_S: 13440 edges (40.85%)]
    A --> C[Temporal Couplings E_T: 13410 edges (40.76%)]
    A --> D[Scenario Couplings E_Omega: 6048 edges (18.38%)]
    
    B --> B1[Bus Power Balance]
    B --> B2[GSDF Line Flow Limits]
    B --> B3[System Reserve Req.]

    C --> C1[Generator Ramp Up/Down (Intra-Day vs. Day-Boundary)]
    C --> C2[Unit Status Transition (Intra-Day vs. Day-Boundary)]
    C --> C3[ESS SOC Inventory (Continuous across 168h)]

    D --> D1[First-stage UC Non-Anticipativity (168h)]
```

### Coupling Distribution Details:
1. **Spatial Couplings (E_S)**: **13440** edges (40.85%)
   - Bus power balance, transmission line flow limits (GSDF), and system spinning reserves.
2. **Temporal Couplings (E_T)**: **13410** edges (40.76%)
   - Generator ramp-rate limits, unit startup/shutdown transitions, and ESS energy SOC continuity across 168 hours.
3. **Stochastic Couplings (E_Omega)**: **6048** edges (18.38%)
   - Non-anticipativity constraints enforcing identical first-stage unit commitment decisions (x_{g,t}) across scenarios s = 1...NS.

---

## 6. Multi-Scale Algorithmic Decomposition Strategies (Cole et al. 2023)

Based on the 3D hypergraph structure of the PCM model over 168 hours, Cole et al. (2023) highlight three distinct decomposition paradigms:

### A. Scenario Partitioning (Benders / Progressive Hedging)
- **Coupling Bottleneck**: Concentrated exclusively in the **6048** Non-Anticipativity OptiEdges (E_Omega).
- **Decomposition Effect**: Removing E_Omega decouples the 168h problem into **5** completely independent 168-hour deterministic UC subproblems.
- **Suitability**: **Very High**. Excellent for parallel implementation across CPU clusters.

### B. Temporal Partitioning (Dynamic Programming / Dantzig-Wolfe)
- **Coupling Bottleneck**: **13410** temporal edges (E_T) connecting adjacent hours t-1 -> t.
- **Decomposition Effect**: Removing E_T decouples the model into 168 hourly spatial dispatch subproblems.
- **Suitability**: High for rolling-horizon or long-term multi-stage planning models.

### C. Spatial Partitioning (ADMM / Network Tearing)
- **Coupling Bottleneck**: **13440** spatial edges (E_S) representing transmission limits and power balance.
- **Decomposition Effect**: Decouples grid into regional/zonal subproblems.
- **Suitability**: High for multi-regional co-optimization and distributed market clearing.
