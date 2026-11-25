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
    result = UCSolveResult(:benchmark, :excel, "/tmp/output", details; runtime_seconds = 0.25)
    @test result.status == "OPTIMAL"
    @test result.objective == 1.0
    @test result.lower_bound == 1.0
    @test result.gap == 0.0
    @test result.runtime_seconds == 0.25
    @test result.upper_bound == 1.0
    @test result[:gap] == 0.0

    pcm_result = UCSolveResult(:pcm_standard, :excel, "/tmp/output", (status = "OPTIMAL", total_cost = 42.5, runtime_seconds = 1.5))
    @test pcm_result.objective == 42.5
    @test pcm_result.lower_bound === nothing
    @test pcm_result.runtime_seconds == 1.5

    bench_result = UCSolveResult(:benchmark, :excel, "/tmp/output", (status = "OPTIMAL", cost_summary = (total_cost = 99.0,)))
    @test bench_result.objective == 99.0

    prob = UCProblemData(data)
    @test UCProblemData(prob) === prob
    @test hasmethod(ModuleUnitCommitmentToolkit.apply_scuc_constraints!, Tuple{ModuleUnitCommitmentToolkit.JuMP.Model, UCProblemData, Any, Any, Any})
    @test hasmethod(ModuleUnitCommitmentToolkit.bd_subfunction, Tuple{UCProblemData})
    @test hasmethod(ModuleUnitCommitmentToolkit.each_period_scucmodel_modules, Tuple{UCProblemData})

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

    # #7: Task-local SolverOptions isolation & UCSolveRequest wiring
    @test current_solver_options() === nothing
    opts_a = SolverOptions(mip_gap = 0.02, threads = 2, time_limit = 30.0, silent = true)
    opts_b = SolverOptions(mip_gap = 0.05, threads = 1, silent = false)
    req_with_opts = UCSolveRequest(algorithm = :benchmark, solver_options = opts_a)
    @test req_with_opts.solver_options == opts_a
    with_solver_options(opts_a) do
        @test current_solver_options() == opts_a
        with_solver_options(opts_b) do
            @test current_solver_options() == opts_b
        end
        @test current_solver_options() == opts_a
    end
    @test current_solver_options() === nothing

    # #8: Multiple-dispatch device_net_injection default fallback
    dummy_m = ModuleUnitCommitmentToolkit.JuMP.Model()
    @test device_net_injection(dummy_m, nothing, 1, 1, [0.5, -0.5]) == 0.0
    @test device_net_injection(dummy_m, :custom_unregistered, 1, 1, [0.5, -0.5]) == 0.0

    # #9: Multi-area H-D frequency parameter extraction and MILP cut injection
    u_multi = deepcopy(data.units)
    @test u_multi.area == ones(Int, length(u_multi.index))
    @test data.winds.area == ones(Int, length(data.winds.index))
    u_multi.area = [i == 1 ? 1 : 2 for i in eachindex(u_multi.index)]
    area_params = extract_uc_hd_parameters_by_area(u_multi, data.winds, Dict(1 => 10.0, 2 => 15.0))
    @test sort(collect(keys(area_params))) == [1, 2]
    @test area_params[1].area_id == 1
    @test area_params[2].area_id == 2
    m_hd = ModuleUnitCommitmentToolkit.JuMP.Model()
    ModuleUnitCommitmentToolkit.JuMP.@variable(m_hd, x[1:data.NG, 1:2], Bin)
    area_constrs = add_multi_area_hd_frequency_constraints!(
        m_hd, Int64(2), prob.NG, prob.NC, prob.NS, u_multi, prob.storages, prob.config_param, Dict(1 => 10.0, 2 => 15.0);
        winds = prob.winds, max_cuts = 3,
    )
    @test sort(collect(keys(area_constrs))) == [1, 2]
    @test area_constrs[1].unit_indices == [1]
    @test area_constrs[2].unit_indices == collect(2:data.NG)

    # #2: ASCII UCScheduleResult wrapper with Unicode dict-key compatibility
    sched = UCScheduleResult(Dict{String, Any}(
        "x₀" => [1.0 0.0],
        "u₀" => [1.0 0.0],
        "v₀" => [0.0 1.0],
        "p₀" => [50.0 0.0],
        "pᵨ" => [0.0 2.0],
        "pᵩ" => [1.5 0.0],
        "seq_sr⁺" => [5.0 0.0],
        "seq_sr⁻" => [3.0 0.0],
        "total_cost" => 1234.5,
    ))
    @test sched.commitment == [1.0 0.0]
    @test sched.load_shed == [0.0 2.0]
    @test sched.wind_curtail == [1.5 0.0]
    @test sched.total_cost == 1234.5
    @test sched["x₀"] == [1.0 0.0]
    @test haskey(sched, "pᵨ")
    @test UCScheduleResult(sched) === sched

    # Strengthened Benders: per-group Jensen partitioning & frequency commitment logic cuts
    @test ModuleUnitCommitmentToolkit._min_cardinality_for_threshold([3.0, 2.0, 1.0], 4.5) == 2
    @test ModuleUnitCommitmentToolkit._min_cardinality_for_threshold([3.0, 2.0, 1.0], 0.0) == 0
    covers = Set{BitVector}()
    ModuleUnitCommitmentToolkit._collect_cover_logic_masks!(covers, [5.0, 2.0, 1.0], 5.5)
    @test BitVector([true, false, false]) in covers  # unit 1 is mandatory (2 + 1 = 3 < 5.5)

    setup_j = redirect_stdout(devnull) do
        build_benders_setup(; input = :excel, scenario_limit = 4)
    end
    @test setup_j.jensen_groups !== nothing
    @test length(setup_j.jensen_groups) == 3  # 1 global + 2 quantile groups
    @test setup_j.jensen_groups[1].scenarios == [1, 2, 3, 4]
    @test sort(vcat(setup_j.jensen_groups[2].scenarios, setup_j.jensen_groups[3].scenarios)) == [1, 2, 3, 4]
end
