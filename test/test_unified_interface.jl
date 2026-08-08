@testset "unified data and solver interface" begin
    @test _normalize_solver_algorithm(:benchmark) == :benchmark
    @test _normalize_solver_algorithm("extensive-form") == :benchmark
    @test _normalize_solver_algorithm("benders") == :benders
    @test _normalize_solver_algorithm(:column_constraint_generation) == :ccg

    @test _normalize_input_source(:excel, nothing, nothing, nothing, "") == :excel
    @test _normalize_input_source("power-systems", nothing, nothing, nothing, "") == :powersystems
    @test _normalize_input_source(:powersystems, nothing, :system, nothing, "case") == :powersystems_csv
    @test _normalize_input_source(:excel, true, :system, nothing, "") == :powersystems
    @test _normalize_input_source(:powersystems, true, :system, nothing, "case") == :powersystems_csv
    @test _normalize_input_source(:excel, false, nothing, nothing, "") == :excel

    @test_throws ArgumentError _normalize_solver_algorithm(:unknown)
    @test_throws ArgumentError _normalize_input_source(:unsupported, nothing, nothing, nothing, "")
    @test_throws ArgumentError _normalize_input_source(:powersystems, false, :system, nothing, "")

    @test _calibration_pairs((model_consider_bess = false, BENDERS_MAX_ITERATIONS = 2)) ==
        ["MODEL_CONSIDER_BESS" => "0", "BENDERS_MAX_ITERATIONS" => "2"]
    @test_throws ArgumentError _calibration_pairs((invalid = [1, 2],))

    data = redirect_stdout(devnull) do
        load_uc_data(input = :excel, scenario_limit = 1)
    end
    @test data.NS == 1
    @test data.NT == 24

    old_value = get(ENV, "MODULE_UC_TEST_CALIBRATION", nothing)
    try
        delete!(ENV, "MODULE_UC_TEST_CALIBRATION")
        result = _run_with_uc_context(
            () -> get(ENV, "MODULE_UC_TEST_CALIBRATION", "missing"),
            (MODULE_UC_TEST_CALIBRATION = 7,),
            nothing,
        )
        @test result == "7"
        @test !haskey(ENV, "MODULE_UC_TEST_CALIBRATION")
    finally
        if old_value === nothing
            delete!(ENV, "MODULE_UC_TEST_CALIBRATION")
        else
            ENV["MODULE_UC_TEST_CALIBRATION"] = old_value
        end
    end
end
