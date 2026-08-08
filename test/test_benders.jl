@testset "benders helper modules" begin
    model = Model()
    @variable(model, x[1:2, 1:2] >= 0)
    @variable(model, u[1:2, 1:2] >= 0)
    @variable(model, v[1:2, 1:2] >= 0)

    vars = build_decision_variables(; x = x, u = u, v = v)
    @test vars.x === x
    @test vars.u === u
    @test vars.v === v
    @test size(vars.pgₖ) == (0, 0, 0)
    @test vars.θ === nothing
    @test_throws ErrorException build_decision_variables(; not_a_field = x)

    constraints = build_constraints()
    @test isempty(constraints.balance_constr)
    @test isempty(constraints.winds_curt_constr)
    @test_throws ErrorException build_constraints(; not_a_constraint = ConstraintRef[])

    coeff = build_dual_cuts_expr_coefficient(; rhs = [1.0, 2.0], dual_coeffVector = [0.1, 0.2])
    @test coeff.rhs == [1.0, 2.0]
    @test coeff.dual_coeffVector == [0.1, 0.2]
    @test coeff.x === nothing
    @test_throws ErrorException build_dual_cuts_expr_coefficient(; unknown = 1.0)

    winds_freq_param = [
        1.0 1.0 0.05 0.0 0.0 0.1
        1.0 1.0 0.05 0.0 0.0 0.1
    ]
    winds, _ = genscenario(winds_freq_param, 1; scenario_limit = 3)
    single = build_single_scenario_wind(winds, 2, 1.0)
    mean_wind = build_mean_scenario_wind(winds, 1.0)

    @test single.scenarios_nums == 1
    @test size(single.scenarios_curve) == (1, 24)
    @test single.scenarios_curve[1, :] == winds.scenarios_curve[2, :]
    @test mean_wind.scenarios_nums == 1
    @test vec(mean_wind.scenarios_curve) ≈ vec(sum(winds.scenarios_curve; dims = 1)) ./ winds.scenarios_nums
end
