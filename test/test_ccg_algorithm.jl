@testset "ccg algorithm helpers" begin
    winds_freq_param = [
        1.0 1.0 0.05 0.0 0.0 0.1
        1.0 1.0 0.05 0.0 0.0 0.1
    ]
    winds, _ = genscenario(winds_freq_param, 1; scenario_limit = 4)
    loads = load([1], [1], reshape(fill(1.0, 24), 1, 24))
    data = (winds = winds, loads = loads, NS = winds.scenarios_nums)

    ENV["CCG_INITIAL_POLICY"] = "first"
    @test choose_initial_ccg_scenarios(data, 2) == [1, 2]
    ENV["CCG_INITIAL_POLICY"] = "netload"
    selected = choose_initial_ccg_scenarios(data, 2)
    delete!(ENV, "CCG_INITIAL_POLICY")

    @test length(selected) == 2
    @test issorted(selected)
    @test all(1 .<= selected .<= data.NS)
    @test_throws ArgumentError choose_initial_ccg_scenarios(data, 0)
    @test_throws ArgumentError choose_initial_ccg_scenarios(data, data.NS + 1)

    evaluation = Dict(1 => (recourse_cost = 10.0,), 2 => (recourse_cost = 50.0,), 3 => (recourse_cost = 40.0,), 4 => (recourse_cost = 20.0,))
    worst_probability = [0.1, 0.2, 0.6, 0.1]
    @test choose_ccg_scenarios_to_add(evaluation, [1, 2, 3, 4], 2, worst_probability) == [3, 2]
    @test choose_ccg_scenarios_to_add(evaluation, Int64[], 2, worst_probability) == Int64[]
    @test_throws ArgumentError choose_ccg_scenarios_to_add(evaluation, [1], 0, worst_probability)
    @test_throws ArgumentError choose_ccg_scenarios_to_add(evaluation, [5], 1, worst_probability)

    subset = build_ccg_subset_wind(winds, [1, 4], 0.5)
    @test subset.scenarios_nums == 2
    @test subset.scenarios_prob == 0.5
    @test subset.scenarios_curve == winds.scenarios_curve[[1, 4], :]
    @test_throws ArgumentError build_ccg_subset_wind(winds, [1, 1], 0.5)
end
