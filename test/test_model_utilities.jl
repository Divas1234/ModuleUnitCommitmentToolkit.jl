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
end
