#!/usr/bin/env julia
# Thin CLI wrapper delegating to `ModuleUnitCommitmentToolkit.run_pcm(:clustered_overlap)`.
if !isdefined(@__MODULE__, :run_pcm)
    using ModuleUnitCommitmentToolkit
end
run_pcm(:clustered_overlap; cfg = PCMConfig())
