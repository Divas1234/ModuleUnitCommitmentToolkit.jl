@testset "data input and formatting" begin
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

    @test size(UnitsFreqParam, 2) == 7
    @test size(WindsFreqParam, 2) == 6
    @test size(DataGen, 1) > 0
    @test size(DataBranch, 1) > 0
    @test size(LoadCurve, 1) >= 24

    config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
        DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)
    winds, _ = genscenario(WindsFreqParam, 1; scenario_limit = 3)

    @test config_param isa config
    @test NG == length(units.index)
    @test NL == length(lines.index)
    @test ND == length(loads.index)
    @test NC == length(psses.index)
    @test ND2 == length(DataCentras.index)
    @test NT <= size(LoadCurve, 1)
    @test size(loads.load_curve) == (ND, NT)
    @test all(isfinite, loads.load_curve)
    @test all(loads.load_curve .>= 0)
    @test all(units.p_max .>= units.p_min)
    @test all(lines.p_max .>= 0)
    workload = data_center_workload_profile(DataCentras, NT, ND2)
    @test size(workload) == (ND2, NT)
    @test all(isfinite, workload)
    @test all(workload .>= 0)
    response_peak = vec(maximum(DataCentras.idale .+ 1.5 .* DataCentras.sv_constant ./ DataCentras.μ .* workload; dims = 2))
    @test all(isfinite, response_peak)
    @test all(DataCentras.p_max .>= 0)

    redirect_stdout(devnull) do
        return boundarycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param; show_plots = false)
    end
    @test true
end
