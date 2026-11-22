# Thin backward-compatible wrapper; Extensive-Form Benchmark now lives precompiled in `src/algorithms/benchmark/`.
if !isdefined(@__MODULE__, :solve_benchmark_uc)
    using ModuleUnitCommitmentToolkit
end
load_runtime_config!()
