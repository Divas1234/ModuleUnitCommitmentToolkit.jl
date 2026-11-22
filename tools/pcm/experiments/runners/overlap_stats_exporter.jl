#!/usr/bin/env julia
# Thin CLI wrapper delegating to `ModuleUnitCommitmentToolkit.run_pcm(:adaptive_overlap)`.
if !isdefined(@__MODULE__, :run_pcm)
    using ModuleUnitCommitmentToolkit
end
run_pcm(:adaptive_overlap; cfg = PCMConfig())
