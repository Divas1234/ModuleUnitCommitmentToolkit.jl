@testset "model utility functions" begin
    UnitsFreqParam, _, storage_data, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, data_center_data = readxlssheet()
    _, units, _, _, _, _, NG, _, _, _, _, _, _ =
        forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, storage_data, data_center_data)

    refcost, eachslope = linearizationfuelcurve(units, NG)

    @test length(refcost) == NG
    @test size(eachslope) == (3, NG)
    @test all(isfinite, refcost)
    @test all(isfinite, eachslope)
    @test all(refcost .>= 0)
    @test all(eachslope .>= 0)

    freq_cfg = config(1, 1, 1, 1, 1, 3, 0.005, 0.005, 1, 1, 1, 1e5, 1e5, 50, 0.01, 0, 1, 0, 1)
    freq_model = Model()
    define_decision_variables!(freq_model, 2, NG, 0, 0, 0, 1, 0, freq_cfg)
    freq_constraints = add_frequency_constraints!(freq_model, 2, NG, 0, 1, units, nothing, freq_cfg, 0.01)

    @test freq_constraints !== nothing
    @test length(vec(freq_constraints.rocof)) == 2
    @test length(vec(freq_constraints.nadir)) >= 2
    @test length(vec(freq_constraints.qss)) == 2
    @test length(vec(freq_constraints.sfr)) == 6

    # Regression: unified curtailment penalties across objectives and cost summary
    penalty_cfg = config(1, 1, 1, 1, 1, 3, 0.005, 0.005, 1, 1, 1, 250.0, 75.0, 50, 0.01, 0, 0, 0, 1)
    @test uc_load_curtailment_penalty(penalty_cfg) == 250.0 * 1e4
    @test uc_wind_curtailment_penalty(penalty_cfg) == 75.0

    cost_summary = compute_uc_cost_summary(
        1, 1, 1, 1, 1,
        penalty_cfg, 1.0,
        zeros(1, 1), zeros(1, 1), zeros(1, 1, 3), zeros(1, 1),
        zeros(1, 1), zeros(1, 1), fill(2.0, 1, 1), fill(3.0, 1, 1),
        zeros(3, 1), zeros(1, 1),
    )
    @test cost_summary.load_curtailment_cost == 2.0 * uc_load_curtailment_penalty(penalty_cfg)
    @test cost_summary.wind_curtailment_cost == 3.0 * uc_wind_curtailment_penalty(penalty_cfg)

    # Regression: validate_inputs checks real struct fields without FieldError
    data = redirect_stdout(devnull) do
        load_uc_data(input = :excel, scenario_limit = 1)
    end
    @test validate_inputs(
        data.NT, data.NB, data.NG, data.ND, data.NC, data.ND2,
        data.units, data.loads, data.winds, data.lines, data.data_centers,
        data.config_param, data.psses, data.full_scenario_probability, data.NL,
    )
    @test !validate_inputs(
        data.NT, data.NB, data.NG, data.ND + 1, data.NC, data.ND2,
        data.units, data.loads, data.winds, data.lines, data.data_centers,
        data.config_param, data.psses, data.full_scenario_probability, data.NL,
    )
    @test !validate_inputs(
        data.NT, data.NB, data.NG, data.ND, data.NC, data.ND2,
        data.units, data.loads, data.winds, data.lines, data.data_centers,
        data.config_param, data.psses, data.full_scenario_probability, data.NL + 1,
    )
    @test !validate_inputs(
        data.NT, data.NB, data.NG, data.ND, data.NC, data.ND2,
        data.units, data.loads, data.winds, data.lines, data.data_centers,
        data.config_param, data.psses, 0.0, data.NL,
    )
end
