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

    @test_throws ArgumentError UCSolveRequest(algorithm = :unknown)

    data = redirect_stdout(devnull) do
        load_uc_data(spec)
    end
    @test data.NS == 1
    @test data.NT == 24

    details = (status = "OPTIMAL", upper_bound = 1.0, lower_bound = 1.0, gap = 0.0)
    result = UCSolveResult(:benchmark, :excel, "/tmp/output", details)
    @test result.status == "OPTIMAL"
    @test result[:gap] == 0.0

    setup = BendersSetup(
        ntuple(_ -> nothing, 11)...,
        ntuple(i -> Int64(i), 8)...,
        nothing,
        :named_data,
    )
    @test setup.data == :named_data
    @test length(collect(setup)) == 20
end
