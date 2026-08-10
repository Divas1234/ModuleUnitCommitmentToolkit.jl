using Test

include("../tools/pcm/benchmark_two_scales.jl")
using .PCMTwoScaleBenchmark

@testset "two-scale benchmark layout" begin
    @test scale_label("data/data_118_clustered_pcm.xlsx") == "108_units"
    @test scale_label("data/data_118_clustered_pcm_10x.xlsx") == "1080_units"
    @test normpath(case_output_root("/tmp/pcm", "108_units")) == normpath("/tmp/pcm/108_units")
    @test normpath(report_filename("/tmp/pcm/108_units")) == normpath("/tmp/pcm/108_units/analysis_report.md")
end
