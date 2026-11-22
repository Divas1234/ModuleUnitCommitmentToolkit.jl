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
    @test "MODEL_IS_NETWORK_CON" in known_uc_calibration_keys()
    @test "BENCHMARK_UC_USE_DRO" in known_uc_calibration_keys()
    @test_throws ArgumentError _calibration_pairs((NONEXISTENT_KEY = 1,); validate_keys = true)
    @test_throws ArgumentError UCSolveRequest(calibration = (MODEL_CONSIDER_WIND = false,))
    err_msg = try
        UCSolveRequest(calibration = (MODEL_CONSIDER_WIND = false,))
        ""
    catch err
        sprint(showerror, err)
    end
    @test occursin("MODEL_IS_WIND_UNIT_CON", err_msg)

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

    # Extensibility: task-local optimizer injection and Excel data_file / horizon on UCInputSpec
    sentinel_opt = :mock_optimizer_factory
    @test with_uc_optimizer(() -> default_uc_optimizer(), sentinel_opt) === sentinel_opt
    excel_req = UCSolveRequest(input = :excel, horizon = 6, data_file = "data/data.xlsx", optimizer = sentinel_opt)
    @test excel_req.input.horizon == 6
    @test excel_req.input.data_file == "data/data.xlsx"
    @test excel_req.optimizer === sentinel_opt

    # P0: Strongly-typed UCProblemData container & compatibility aliases
    prob = UCProblemData((
        config_param = :cfg, units = :u, lines = :l, loads = :d,
        psses = :s, winds = :w, data_centers = :dc,
        NB = 6, NG = 3, NL = 7, ND = 3, NT = 24, NC = 1, ND2 = 0, NW = 2, NS = 5,
    ))
    @test prob.storages === :s
    @test prob.psses === :s
    @test prob.DataCentras === :dc
    @test prob[:NT] == 24

    # P1: AbstractUCAlgorithm hierarchy & PCM unified routing
    @test BenchmarkUCAlgorithm() isa AbstractUCAlgorithm
    @test BendersAlgorithm(fast_direct = true).fast_direct == true
    @test CCGAlgorithm() isa AbstractUCAlgorithm
    pcm_alg = PCMAlgorithm(method = :clustered_adaptive_overlap, profile = :extreme_ramp, intervals = 3, window_hours = 24)
    @test pcm_alg isa AbstractUCAlgorithm
    @test_throws ArgumentError PCMAlgorithm(method = :nonexistent)

    # P1: Canonical ASCII JuMP variable accessor (uc_variable / has_uc_variable)
    m_probe = Model()
    @variable(m_probe, pg₀[1:2, 1:2] >= 0)
    @variable(m_probe, Δpd[1:2, 1:2] >= 0)
    @test has_uc_variable(m_probe, :p_gen)
    @test has_uc_variable(m_probe, :pg₀)
    @test has_uc_variable(m_probe, :load_curtail)
    @test !has_uc_variable(m_probe, :wind_curtail)
    @test uc_variable(m_probe, :p_gen) === m_probe[:pg₀]
    @test uc_variable(m_probe, :load_curtail) === m_probe[:Δpd]

    # P1: Centralized deprecation registry
    @test LEGACY_NAMING_MIGRATION[:boundrycondition] == :boundary_condition
    @test LEGACY_NAMING_MIGRATION[:psses] == :storages
end
