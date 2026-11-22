#!/usr/bin/env julia
"""
PCM unified CLI & GUI entrypoint.

Selects one of the 4 orthogonal PCM methods or the full-horizon Benchmark via
`ENV["PCM_METHOD"]`:
  - `standard`                   : Single-Unit + Fixed Horizon (no cluster, no overlap)
  - `adaptive_overlap`           : Single-Unit + Adaptive Overlap
  - `clustered` / `clustered_pcm`: Clustered + Fixed Horizon
  - `clustered_overlap` / `clustered_adaptive_overlap`: Clustered + Adaptive Overlap
  - `benchmark` / `integrated_uc`: Full-Horizon Integrated UC Reference
"""

if !isdefined(@__MODULE__, :run_pcm)
    using ModuleUnitCommitmentToolkit
end

method = strip(get(ENV, "PCM_METHOD", "standard"))
cfg = PCMConfig()
result = run_pcm(method; cfg = cfg)
println("PCM run completed: method=$(result.method), status=$(result.status), total_cost=$(round(result.total_cost; digits=4)), runtime=$(round(result.runtime_seconds; digits=3))s")
result
