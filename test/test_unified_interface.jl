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

    # Extensibility: pluggable algorithm registry
    @test :benchmark in registered_uc_algorithms()
    @test :benders in registered_uc_algorithms()
    @test :ccg in registered_uc_algorithms()
    try
        register_uc_algorithm!(:custom_test_algo, req -> (status = "CUSTOM_OK", upper_bound = 0.0, lower_bound = 0.0, gap = 0.0); aliases = ["custom-alias"])
        @test _normalize_solver_algorithm("custom-alias") == :custom_test_algo
        @test :custom_test_algo in registered_uc_algorithms()
        custom_res = _solve_uc_selected(UCSolveRequest(algorithm = "custom-alias", input = :excel, scenario_limit = 1))
        @test custom_res.status == "CUSTOM_OK"
    finally
        unregister_uc_algorithm!(:custom_test_algo)
    end
    @test !(:custom_test_algo in registered_uc_algorithms())

    # Extensibility: pluggable variable, objective, and constraint hook registries
    try
        clear_all_uc_hooks!()
        register_uc_variable_hook!(:demo_var_hook, (m, ctx) -> nothing)
        register_uc_objective_hook!(:demo_obj_hook, (m, ctx) -> nothing)
        register_uc_constraint_hook!(:demo_hook, (m, ctx) -> :hook_called)
        @test registered_uc_variable_hooks() == [:demo_var_hook]
        @test registered_uc_objective_hooks() == [:demo_obj_hook]
        @test registered_uc_constraint_hooks() == [:demo_hook]
    finally
        clear_all_uc_hooks!()
    end

    # Extensibility: task-local optimizer injection and Excel data_file / horizon on UCInputSpec
    sentinel_opt = :mock_optimizer_factory
    @test with_uc_optimizer(() -> default_uc_optimizer(), sentinel_opt) === sentinel_opt
    excel_req = UCSolveRequest(input = :excel, horizon = 6, data_file = "data/data.xlsx", optimizer = sentinel_opt)
    @test excel_req.input.horizon == 6
    @test excel_req.input.data_file == "data/data.xlsx"
    @test excel_req.optimizer === sentinel_opt
end
