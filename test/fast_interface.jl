using Test
using ModuleUnitCommitmentToolkit

@testset "fast public interface" begin
    spec = UCInputSpec(input = :excel, scenario_limit = 1)
    @test spec.source == :excel
    @test spec.scenario_limit == 1

    request = UCSolveRequest(
        algorithm = "extensive-form",
        input = :excel,
        scenario_limit = 1,
        calibration = (MODEL_CONSIDER_BESS = false,),
        output_dir = "/tmp/module-uc-interface-test",
    )
    @test request.algorithm == :benchmark
    @test request.input.source == :excel
    @test request.output_dir == "/tmp/module-uc-interface-test"
    @test request.verbosity == :detailed

    @test_throws ArgumentError UCSolveRequest(algorithm = :unknown)
    @test_throws ArgumentError UCSolveRequest(verbosity = :unknown)

    data = redirect_stdout(devnull) do
        load_uc_data(spec)
    end
    @test data.NS == 1
    @test data.NT == 24

    details = (status = "OPTIMAL", upper_bound = 1.0, lower_bound = 1.0, gap = 0.0)
    result = UCSolveResult(:benchmark, :excel, "/tmp/output", details)
    @test result.status == "OPTIMAL"
    @test result[:gap] == 0.0

    rendered = sprint() do io
        print_uc_result(result; io = io, diagnostics = 2)
    end
    @test occursin("UNIFIED UC SOLVE RESULT", rendered)
    @test occursin("hidden_messages", rendered)

    detailed_output_dir = mktempdir()
    detailed_result = UCSolveResult(
        :ccg,
        :excel,
        detailed_output_dir,
        (
            status = "converged",
            upper_bound = 12.0,
            lower_bound = 11.5,
            gap = 0.041,
            active_scenarios = [1, 2],
            history = [
                (iteration = 1, active_scenarios = 1, lower_bound = 10.0, upper_bound = 13.0, gap = 0.3, added_scenarios = [2]),
                (iteration = 2, active_scenarios = 2, lower_bound = 11.5, upper_bound = 12.0, gap = 0.041, added_scenarios = Int[]),
            ],
            cost_summary = (startup_cost = 1.0, total_cost = 12.0),
            data = (NB = 3, NG = 2, NL = 1, ND = 2, NT = 24, NW = 1, NS = 2, NC = 0, ND2 = 0),
        ),
    )
    detailed_rendered = sprint() do io
        print_uc_result(detailed_result; io = io, detail = true)
    end
    @test occursin("[Input data]", detailed_rendered)
    @test occursin("[Optimization details]", detailed_rendered)
    @test occursin("DataFrame", detailed_rendered)
    @test occursin("[Iteration history]", detailed_rendered)
    @test occursin("startup_cost", detailed_rendered)
    @test isfile(joinpath(detailed_output_dir, "result", "01_request.csv"))
    @test isfile(joinpath(detailed_output_dir, "result", "04_input_data.csv"))
    @test isfile(joinpath(detailed_output_dir, "result", "07_iteration_history.csv"))
    @test isfile(joinpath(detailed_output_dir, "result", "08_cost_breakdown.csv"))

    setup = BendersSetup(
        ntuple(_ -> nothing, 11)...,
        ntuple(i -> Int64(i), 8)...,
        nothing,
        :named_data,
    )
    @test setup.data == :named_data
    @test length(collect(setup)) == 20
end
