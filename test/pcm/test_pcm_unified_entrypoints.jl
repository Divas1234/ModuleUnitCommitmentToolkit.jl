using Test

@testset "Unified PCM 2x2 Entrypoints & Config" begin
    # PCMConfig validation at construction boundary
    @test_throws ArgumentError PCMConfig(window_hours = 0)
    @test_throws ArgumentError PCMConfig(intervals = 0)
    @test_throws ArgumentError PCMConfig(performance_mode = "invalid")

    cfg = PCMConfig(window_hours = 24, intervals = 2, load_profile = "baseline", performance_mode = "fast")
    @test cfg.window_hours == 24
    @test cfg.intervals == 2

    # Method spec normalization & PCMAlgorithm alignment
    for (alias, expected) in (
        (:standard, :standard),
        (:adaptive_overlap, :adaptive_overlap),
        (:clustered, :clustered),
        (:clustered_pcm, :clustered),
        (:clustered_overlap, :clustered_overlap),
        (:clustered_adaptive_overlap, :clustered_overlap),
        (:benchmark, :benchmark),
        (:integrated_uc, :benchmark),
    )
        @test pcm_method_spec(alias; cfg = cfg)[1] === expected
        @test PCMAlgorithm(method = alias).method === expected
    end
    @test_throws ArgumentError pcm_method_spec(:unknown_method; cfg = cfg)
    @test_throws ArgumentError PCMAlgorithm(method = :unknown_method)

    # End-to-end smoke test on default Excel case (2x24h fixed-horizon standard, clustered, benchmark)
    data_path = joinpath(PROJECT_ROOT, "data", "data_118.xlsx")
    if isfile(data_path)
        smoke_cfg = PCMConfig(
            window_hours = 24,
            intervals = 2,
            load_profile = "baseline",
            performance_mode = "fast",
            network_constraints = false,
            data_file = data_path,
        )
        res_std = run_pcm(:standard; cfg = smoke_cfg)
        @test res_std.status == "OPTIMAL"
        @test isfinite(res_std.total_cost) && res_std.total_cost > 0
        @test res_std.total_hours == 48
        @test res_std.physical_units > 0

        res_clu = run_pcm(:clustered; cfg = smoke_cfg)
        @test res_clu.status == "OPTIMAL"
        @test isfinite(res_clu.total_cost) && res_clu.total_cost > 0
        @test res_clu.total_hours == 48

        res_bench = run_pcm(:benchmark; cfg = smoke_cfg)
        @test res_bench.status == "OPTIMAL"
        @test isfinite(res_bench.total_cost) && res_bench.total_cost > 0
        @test res_bench.total_hours == 48
    end
end
