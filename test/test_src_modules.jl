@testset "src base modules" begin
    cfg = config(1, 1, 1, 1, 1, 3, 0.005, 0.005, 1, 1, 1, 1e5, 1e5, 50, 0.01, 0, 0, 0, 1)
    model = Model()
    define_decision_variables!(model, 2, 2, 1, 0, 0, 3, 1, cfg)

    @test haskey(JuMP.object_dictionary(model), :x)
    @test haskey(JuMP.object_dictionary(model), :pg₀)
    @test size(model[:x]) == (2, 2)
    @test size(model[:pg₀]) == (6, 2)
    @test size(model[:Δpw]) == (3, 2)

    @test config isa DataType
    @test unit isa DataType
    @test transmissionline isa DataType
    @test load isa DataType
    @test pss isa DataType
    @test data_centra isa DataType
end
