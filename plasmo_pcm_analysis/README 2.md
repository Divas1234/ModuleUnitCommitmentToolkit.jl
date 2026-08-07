# Plasmo.jl 3D Hypergraph Modeling & Structural Analysis for PCM Model

This module implements a 3D hypergraph model structure analysis for the Stochastic Unit Commitment (PCM) model on branch `pcm`, referencing Cole et al. (2023) *"Hierarchical Graph Modeling for Multi-Scale Optimization of Power Systems"*.

## Files Overview
- `build_plasmo_pcm.jl`: Constructs the 3D Plasmo `OptiGraph` tensor $\mathcal{G} = (\mathcal{V}, \mathcal{E})$ spanning Space $\times$ Time $\times$ Scenario dimensions.
- `graph_analyzer.jl`: Computes topological and structural metrics, node/edge distributions, and matrix coupling density.
- `run_analysis.jl`: Executable entry script to build the graph, perform analysis, print terminal summaries, and output `pcm_3d_graph_report.md`.
- `pcm_3d_graph_report.md`: Detailed markdown report with mathematical structure breakdown, 3D coupling metrics, and multi-scale algorithmic decomposition strategies.

## Usage
Run the analysis using Julia in the `plasmo_pcm_analysis` environment:

```bash
julia --project=plasmo_pcm_analysis plasmo_pcm_analysis/run_analysis.jl
```
