@testset "PCM branch data and solver interface" begin
    @test _normalize_solver_algorithm(:pcm) == :pcm
    @test _normalize_solver_algorithm("adaptive-pcm") == :pcm
    @test _normalize_solver_algorithm("rolling pcm") == :pcm
    @test_throws ArgumentError _normalize_solver_algorithm(:benchmark)
    @test_throws ArgumentError _normalize_solver_algorithm(:benders)
    @test_throws ArgumentError _normalize_solver_algorithm(:ccg)

    @test _normalize_input_source(:excel, nothing, nothing, nothing, "") == :excel
    @test _normalize_input_source("power-systems", nothing, nothing, nothing, "") == :powersystems
    @test _normalize_input_source(:powersystems, nothing, :system, nothing, "case") == :powersystems_csv
    @test _normalize_input_source(:excel, true, :system, nothing, "") == :powersystems
    @test _normalize_input_source(:powersystems, true, :system, nothing, "case") == :powersystems_csv
    @test _normalize_input_source(:excel, false, nothing, nothing, "") == :excel

    @test_throws ArgumentError _normalize_input_source(:unsupported, nothing, nothing, nothing, "")
    @test_throws ArgumentError _normalize_input_source(:powersystems, false, :system, nothing, "")

    data = redirect_stdout(devnull) do
        load_uc_data(input = :excel, scenario_limit = 1)
    end
    @test data.NS == 1
    @test data.NT == 24

    request = UCSolveRequest(algorithm = :pcm, input = :excel, scenario_limit = 1)
    @test request.algorithm == :pcm
    @test request.input.source == :excel
    @test_throws ArgumentError solve_uc(request)
end
