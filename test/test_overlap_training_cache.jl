using Test
using DataFrames

include("../tools/pcm/adaptive_overlap/core/training_data_cache.jl")
using .AdaptiveOverlapTrainingCache

@testset "adaptive overlap training-data cache" begin
    mktempdir() do dir
        input_file = joinpath(dir, "case.xlsx")
        write(input_file, "case-a")
        expected = build_case_metadata(; input_file, load_profile = "smooth", solver = "gurobi",
            network_constraints = "0", window_hours = 24, intervals = 3, min_overlap = 2, max_overlap = 12,
            dimensions = Dict("NB" => 118, "NG" => 108, "ND" => 91, "NL" => 186, "NH" => 0),
            load_curve = reshape(collect(1.0:12.0), 3, 4), wind_curve = reshape(collect(1.0:4.0), 1, 4))
        data = DataFrame(U_norm = [0.5, 0.6], T_dwell_rem = [2.0, 3.0], L_norm = [0.3, 0.4],
            sigma_load = [1.0, 1.2], R_wind_max = [0.04, 0.05], X_delta_norm = [0.0, 0.1],
            X_switch_ratio = [0.0, 0.2], To_star = [6, 8])

        @test load_cached_dataset(dir; expected_metadata = expected) === nothing
        saved = save_cached_dataset(dir, data, expected)
        @test isfile(saved.dataset_path)
        @test isfile(saved.metadata_path)
        @test case_signature(expected) == saved.signature
        cached = load_cached_dataset(dir; expected_metadata = expected, min_samples = 2)
        @test cached !== nothing
        @test cached.To_star == [6, 8]

        changed_profile = build_case_metadata(; input_file, load_profile = "baseline", solver = "gurobi",
            network_constraints = "0", window_hours = 24, intervals = 3, min_overlap = 2, max_overlap = 12,
            dimensions = Dict("NB" => 118, "NG" => 108, "ND" => 91, "NL" => 186, "NH" => 0),
            load_curve = reshape(collect(1.0:12.0), 3, 4), wind_curve = reshape(collect(1.0:4.0), 1, 4))
        @test case_signature(changed_profile) != case_signature(expected)
        @test load_cached_dataset(dir; expected_metadata = changed_profile) === nothing
        @test load_cached_dataset(dir; expected_metadata = expected, min_samples = 3) === nothing
    end
end
