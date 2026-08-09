using Test
using DataFrames

include("../tools/pcm/benchmark_three_methods.jl")
using .PCMThreeMethodBenchmark

@testset "three-method PCM benchmark aggregation" begin
    @test parse_list(" standard, clustered_pcm , adaptive_overlap ") == ["standard", "clustered_pcm", "adaptive_overlap"]
    @test method_equivalent_units("standard", 108, 31) == 108
    @test method_equivalent_units("clustered_pcm", 108, 31) == 31
    @test cost_delta_pct(100.0, 110.0) ≈ 10.0
    @test normalize_solver("Gurobi") == "gurobi"
    @test normalize_solver("auto") == "auto"
    @test_throws ArgumentError normalize_solver("cbc")

    raw = DataFrame(
        profile = ["smooth", "smooth", "smooth", "smooth"],
        method = ["standard", "standard", "clustered_pcm", "adaptive_overlap"],
        status = ["OK", "OK", "OK", "OK"],
        wall_time_sec = [10.0, 12.0, 5.0, 20.0],
        allocated_mb = [100.0, 120.0, 60.0, 200.0],
        peak_rss_mb = [80.0, 90.0, 50.0, 150.0],
        total_cost = [100.0, 102.0, 110.0, 105.0],
        physical_units = [108, 108, 108, 108],
        equivalent_units = [108, 108, 31, 108],
        commitment_integer_variables = [7776, 7776, 2232, 7776],
        cluster_attempts = [0, 0, 3, 0],
        cluster_successes = [0, 0, 2, 0],
        cluster_fallbacks = [0, 0, 1, 0],
        average_overlap_hours = [0.0, 0.0, 0.0, 10.0],
        max_overlap_hours = [0.0, 0.0, 0.0, 10.0],
        ramp_event_intervals = [0, 0, 0, 1])

    summary = aggregate_metrics(raw)
    @test nrow(summary) == 3
    @test only(summary[(summary.profile .== "smooth") .& (summary.method .== "standard"), :median_wall_time_sec]) ≈ 11.0
    @test only(summary[(summary.profile .== "smooth") .& (summary.method .== "clustered_pcm"), :median_total_cost]) ≈ 110.0

    comparison = add_relative_metrics(summary)
    clustered = only(comparison[(comparison.profile .== "smooth") .& (comparison.method .== "clustered_pcm"), :])
    @test clustered.speedup_vs_standard ≈ 2.2
    @test clustered.cost_delta_pct ≈ (110.0 / 101.0 - 1.0) * 100
    @test clustered.integer_reduction_pct ≈ (1.0 - 2232.0 / 7776.0) * 100
    @test clustered.state_reduction_pct ≈ (1.0 - 31.0 / 108.0) * 100

    mktemp() do path, io
        write(io, "1,2,3,4,5,6,7\n8,9,10,11,12,13,14\n")
        close(io)
        @test read_cost_vector(path) == [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0]
    end

    mktempdir() do dir
        write(joinpath(dir, "run.log"), """
Processing scheduling interval 1 of 2...
  Clustered PCM: 108 physical units -> 31 equivalent units (71.3% state reduction; 108 units in non-singleton clusters)
  ✓ True clustered UC completed (31 virtual units)
Processing scheduling interval 2 of 2...
  Clustered PCM: 108 physical units -> 36 equivalent units (66.7% state reduction; 98 units in non-singleton clusters)
  ⚠ True clustered UC failed at residence_flow: insufficient mature off pool; falling back to full unit-network SCUC
""")
        cluster_process = extract_cluster_intermediate(dir, "smooth", 1)
        @test nrow(cluster_process) == 2
        @test cluster_process.equivalent_units == [31, 36]
        @test cluster_process.status == ["completed", "failed"]
        @test cluster_process.failure_stage[2] == "residence_flow"
    end
end
