using Test
using DataFrames
using CSV

@testset "Clustered Adaptive Overlap PCM" begin
    project_root = normpath(joinpath(@__DIR__, ".."))
    main_script = joinpath(project_root, "tools", "pcm", "main.jl")

    @testset "Method Dispatcher Selection" begin
        # Verify ENV["PCM_METHOD"]="clustered_adaptive_overlap" properly selects the runner
        withenv(
            "PCM_METHOD" => "clustered_adaptive_overlap",
            "PCM_INTERVALS" => "2",
            "PCM_WINDOW_HOURS" => "24",
            "PCM_LOAD_PROFILE" => "baseline",
            "PCM_SOLVER" => "auto",
            "PCM_OVERLAP_MODE" => "decay",
            "MODULE_UC_DATA_FILE" => joinpath(project_root, "data", "data_118.xlsx")
        ) do
            # Test that main.jl executes without error
            @test isfile(main_script)
            
            output_dir = joinpath(project_root, "output", "details_schedule_results", "clustered_adaptive_pcm_simulation_results")
            # Clear pre-existing output to verify fresh generation
            rm(output_dir; force = true, recursive = true)

            redirect_stdout(devnull) do
                include(main_script)
            end

            # Verify exported results
            csv_path = joinpath(output_dir, "overlap_window_statistics.csv")
            txt_path = joinpath(output_dir, "overlap_window_summary.txt")
            cost_path = joinpath(output_dir, "total_scheduled_results.csv")

            @test isfile(csv_path)
            @test isfile(txt_path)
            @test isfile(cost_path)

            stats = CSV.read(csv_path, DataFrame)
            @test nrow(stats) == 2
            @test "Final_Adaptive_Overlap_h" in names(stats)
            @test all(stats.Optimization_Status .== "OK")
            @test all(stats.Final_Adaptive_Overlap_h .>= 2)
            @test all(stats.Final_Adaptive_Overlap_h .<= 12)
        end
    end
end
