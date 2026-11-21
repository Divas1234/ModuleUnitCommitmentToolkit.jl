@testset "data input and formatting" begin
    UnitsFreqParam, WindsFreqParam, storage_data, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, data_center_data = readxlssheet()

    @test size(UnitsFreqParam, 2) == 7
    @test size(WindsFreqParam, 2) == 6
    @test size(DataGen, 1) > 0
    @test size(DataBranch, 1) > 0
    @test size(LoadCurve, 1) == 24

    config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, data_centers =
        forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, storage_data, data_center_data)
    winds, _ = genscenario(WindsFreqParam, 1; scenario_limit = 3)

    @test config_param isa config
    @test NG == length(units.index)
    @test NL == length(lines.index)
    @test ND == length(loads.index)
    @test NC == length(psses.index)
    @test ND2 == length(data_centers.index)
    @test NT == 24
    @test size(loads.load_curve) == (ND, NT)
    @test all(units.p_max .>= units.p_min)
    @test all(lines.p_max .>= 0)
    workload = data_center_workload_profile(data_centers, NT, ND2)
    response_peak = vec(maximum(data_centers.idle_power .+ 1.5 .* data_centers.sv_constant ./ data_centers.μ .* workload; dims = 2))
    @test all(data_centers.p_max .>= response_peak)

    redirect_stdout(devnull) do
        return boundarycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param; show_plots = false)
    end
    @test true
end
