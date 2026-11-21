@testset "renewable scenario generation" begin
    winds_freq_param = [
        1.0 1.0 0.05 0.0 0.0 0.1
        1.0 1.0 0.05 0.0 0.0 0.1
    ]

    Random.seed!(1234)
    winds, wind_count = genscenario(winds_freq_param, 1; scenario_limit = 6)
    winds_from_new_api, wind_count_from_new_api = generate_wind_scenarios(winds_freq_param, 1; scenario_limit = 6)

    @test wind_count == 2
    @test wind_count_from_new_api == wind_count
    @test winds.scenarios_nums == 6
    @test size(winds.scenarios_curve) == (6, 24)
    @test length(winds.index) == wind_count
    @test length(winds.p_max) == wind_count
    @test winds.p_max == [2.5, 2.5]
    @test all(isfinite, winds.scenarios_curve)
    @test all(0 .<= winds.scenarios_curve .<= 1)
    @test winds.scenarios_prob ≈ 1 / winds.scenarios_nums
    @test winds_from_new_api.scenarios_curve == winds.scenarios_curve
end
