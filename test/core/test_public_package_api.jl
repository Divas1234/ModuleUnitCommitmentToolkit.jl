using Test

@testset "Public Package Boundary (using ModuleUnitCommitmentToolkit)" begin
    # Verify real precompiled package loading, exported API, and standalone tool entrypoints
    # in an isolated Julia process so unexported Main-scope symbols cannot mask missing exports.
    script = """
    using ModuleUnitCommitmentToolkit, Test
    @test isdefined(Main, :SUC_scucmodel)
    @test isdefined(Main, :run_pcm)
    @test isdefined(Main, :run_pcm_benchmark)
    @test isdefined(Main, :compare_pcm_methods)
    @test isdefined(Main, :PCMConfig)
    @test isdefined(Main, :PCMAlgorithm)
    @test isdefined(Main, :solve_uc)
    @test isdefined(Main, :validate_inputs)
    @test PCMAlgorithm(method = :clustered_overlap).method === :clustered_overlap
    @test PCMAlgorithm(method = :benchmark).method === :benchmark
    include(joinpath($(repr(PROJECT_ROOT)), "tools", "benders", "setup.jl"))
    @test process_memory_mb() > 0.0
    include(joinpath($(repr(PROJECT_ROOT)), "tools", "ccg", "solver.jl"))
    """
    cmd = `$(Base.julia_cmd()) --project=$(PROJECT_ROOT) -e $script`
    @test success(pipeline(cmd; stdout = devnull, stderr = stderr))
end
