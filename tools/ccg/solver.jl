# Thin backward-compatible wrapper; C&CG core now lives precompiled in `src/algorithms/ccg/`.
if !isdefined(@__MODULE__, :solve_ccg_unit_commitment)
    using ModuleUnitCommitmentToolkit
end
load_runtime_config!()
