@testset "IEEE 30-bus frequency and data-center demo" begin
    demo_path = joinpath(@__DIR__, "..", "examples", "unified_api", "07_ieee30_frequency_datacenter_uc.jl")
    @test isfile(demo_path)
    if isfile(demo_path)
        source = read(demo_path, String)
        @test occursin("const CASE_NAME = :ieee30", source)
        @test occursin("MODEL_CONSIDER_FREQUENCY_CONTROL", source)
        @test occursin("MODEL_CONSIDER_DATA_CENTER", source)
        @test occursin("generate_frequency_parameters", source)
        @test occursin("data_centers", source)
    end
end
