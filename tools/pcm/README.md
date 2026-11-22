# Production Cost Modeling (PCM) Toolkit

PCM is organized along two orthogonal modeling dimensions plus a full-horizon **Benchmark** reference:

| Formulation \ Horizon | Fixed Horizon (No Overlap) | Adaptive Overlap |
| :--- | :--- | :--- |
| **Single-Unit (Physical)** | `standard` | `adaptive_overlap` |
| **Clustered (Homogeneous + PTDF)** | `clustered` (`clustered_pcm`) | `clustered_overlap` (`clustered_adaptive_overlap`) |
| **Full-Horizon Reference** | `benchmark` (`integrated_uc`) — single-shot integrated UC over `intervals × window_hours` |

## Directory Structure
- `src/production_cost/` — Core precompiled library (`formulations/{single_unit,clustered}/`, `horizons/{fixed_rolling.jl,adaptive_overlap/}`, `rolling_engine.jl`, `benchmark_comparison.jl`).
- `tools/pcm/main.jl` — Unified CLI & GUI entrypoint (`PCM_METHOD=...`).
- `tools/pcm/example_run.jl` — Example runner supporting single methods and `--compare-all` / `--compare-fixed` against Benchmark.
- `tools/pcm/benchmark/` — Multi-scale and multi-profile benchmark suite (`run_suite.jl`).
- `tools/pcm/experiments/` — Archived research analysis and offline dataset generation scripts.

## Quick Start
```bash
# Run a single PCM method via unified entrypoint
PCM_METHOD=standard PCM_INTERVALS=2 PCM_WINDOW_HOURS=24 julia --project=. tools/pcm/main.jl

# Compare Fixed-Horizon PCM (standard + clustered) vs Full-Horizon Benchmark
julia --project=. tools/pcm/example_run.jl --compare-fixed --intervals=2 --window=24

# Compare all 4 PCM methods vs Full-Horizon Benchmark
julia --project=. tools/pcm/example_run.jl --compare-all --intervals=2 --window=24
```
