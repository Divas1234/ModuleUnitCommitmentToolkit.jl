# Thin backward-compatible wrapper; Benders core now lives precompiled in `src/algorithms/benders/`.
if !isdefined(@__MODULE__, :build_benders_setup)
    using ModuleUnitCommitmentToolkit
end
load_runtime_config!()
const main = build_benders_setup
