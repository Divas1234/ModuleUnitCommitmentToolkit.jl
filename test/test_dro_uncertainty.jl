@testset "Wasserstein DRO utilities" begin
    winds_freq_param = [
        1.0 1.0 0.05 0.0 0.0 0.1
        1.0 1.0 0.05 0.0 0.0 0.1
    ]
    winds, _ = genscenario(winds_freq_param, 1; scenario_limit = 4)

    dro_model = build_renewable_dro_model(winds)
    distance_matrix = dro_model.distance_matrix

    @test dro_model.metric == "wasserstein"
    @test dro_model.scenario_count == 4
    @test length(dro_model.nominal_probability) == 4
    @test sum(dro_model.nominal_probability) ≈ 1.0
    @test size(distance_matrix) == (4, 4)
    @test distance_matrix ≈ transpose(distance_matrix)
    @test all(diag(distance_matrix) .≈ 0.0)
    @test maximum(distance_matrix) <= 1.0 + 1e-10
    @test minimum(distance_matrix) >= -1e-10

    active_probability = active_nominal_probability(dro_model, [1, 3])
    active_distance = active_wasserstein_distance(dro_model, [1, 3])
    @test active_probability ≈ [0.5, 0.5]
    @test size(active_distance) == (2, 2)

    costs = [10.0, 12.0, 40.0, 13.0]
    nominal_value = dot(dro_model.nominal_probability, costs)
    value_at_zero, probability_at_zero = worst_case_expected_value(costs, dro_model.nominal_probability, 0.0, distance_matrix)
    value_at_radius, probability_at_radius = worst_case_expected_value(costs, dro_model.nominal_probability, 0.05, distance_matrix)

    @test probability_at_zero ≈ dro_model.nominal_probability
    @test value_at_zero ≈ nominal_value
    @test sum(probability_at_radius) ≈ 1.0
    @test all(probability_at_radius .>= -1e-8)
    @test value_at_radius >= nominal_value - 1e-6

    @test_throws ArgumentError renewable_wasserstein_distance_matrix(winds; power = 0.0)
    @test_throws ArgumentError active_nominal_probability(dro_model, Int64[])
    @test_throws ArgumentError active_wasserstein_distance(dro_model, [1, 1])
    @test_throws ArgumentError worst_case_probabilities(costs, dro_model.nominal_probability, -0.1, distance_matrix)
    @test_throws ArgumentError worst_case_probabilities(costs[1:3], dro_model.nominal_probability, 0.05, distance_matrix)
    @test_throws ArgumentError worst_case_probabilities(costs, dro_model.nominal_probability, 0.05, distance_matrix[1:3, 1:3])
end
