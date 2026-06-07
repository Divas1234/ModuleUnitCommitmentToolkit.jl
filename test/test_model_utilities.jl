@testset "model utility functions" begin
	UnitsFreqParam, _, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data =
		readxlssheet()
	_, units, _, _, _, _, NG, _, _, _, _, _, _ =
		forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

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
	@test length(vec(freq_constraints.qss)) == 2
	@test length(vec(freq_constraints.nadir)) == 2
	@test length(vec(freq_constraints.primary)) == 2
end
