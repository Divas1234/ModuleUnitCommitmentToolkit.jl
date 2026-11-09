using Test
using ModuleUnitCommitmentToolkit

function quiet_solve(request::UCSolveRequest)
    return redirect_stdout(devnull) do
        solve_uc(request)
    end
end

@testset "unified algorithm smoke" begin
    root = mktempdir()

    benchmark = quiet_solve(UCSolveRequest(
        algorithm = :benchmark,
        input = :excel,
        scenario_limit = 1,
        calibration = (BENCHMARK_UC_USE_DRO = 0, MODEL_CONSIDER_FREQUENCY_CONTROL = 0),
        output_dir = joinpath(root, "benchmark"),
    ))
    @test benchmark.algorithm == :benchmark
    @test benchmark.status == "OPTIMAL"
    @test benchmark.output_dir == joinpath(root, "benchmark")

    ccg = quiet_solve(UCSolveRequest(
        algorithm = :ccg,
        input = :excel,
        scenario_limit = 1,
        calibration = (
            CCG_INITIAL_SCENARIOS = 1,
            CCG_SCENARIOS_PER_ITERATION = 1,
            CCG_MAX_ITERATIONS = 1,
            CCG_PARALLEL_RECOURSE = 0,
            MODEL_CONSIDER_FREQUENCY_CONTROL = 0,
        ),
        output_dir = joinpath(root, "ccg"),
    ))
    @test ccg.algorithm == :ccg
    @test ccg.status in ("converged", "maximum_iterations")

    benders = quiet_solve(UCSolveRequest(
        algorithm = :benders,
        input = :excel,
        scenario_limit = 1,
        calibration = (
            BENDERS_MAX_ITERATIONS = 1,
            BENDERS_PARALLEL_SUBPROBLEMS = 0,
            MODEL_CONSIDER_FREQUENCY_CONTROL = 0,
        ),
        output_dir = joinpath(root, "benders"),
    ))
    @test benders.algorithm == :benders
    @test benders.status in ("converged", "maximum_iterations", "no_violated_cuts")
end
