@testset "runtime config loader" begin
    include(joinpath(PROJECT_ROOT, "src", "runtime_config.jl"))

    tmp_config = tempname() * ".toml"
    write(tmp_config, """
                      		[demo]
                      		MODULE_UC_TEST_VALUE = 7
                      		MODULE_UC_TEST_BOOL = true
                      		MODULE_UC_TEST_EMPTY = ""
                      		""")

    delete!(ENV, "MODULE_UC_TEST_VALUE")
    delete!(ENV, "MODULE_UC_TEST_BOOL")
    delete!(ENV, "MODULE_UC_TEST_EMPTY")

    result = load_runtime_config!(; config_path = tmp_config)
    @test "MODULE_UC_TEST_VALUE" in result.applied
    @test ENV["MODULE_UC_TEST_VALUE"] == "7"
    @test ENV["MODULE_UC_TEST_BOOL"] == "1"
    @test !haskey(ENV, "MODULE_UC_TEST_EMPTY")

    ENV["MODULE_UC_TEST_VALUE"] = "99"
    result = load_runtime_config!(; config_path = tmp_config)
    @test "MODULE_UC_TEST_VALUE" in result.skipped
    @test ENV["MODULE_UC_TEST_VALUE"] == "99"

    load_runtime_config!(; config_path = tmp_config, override = true)
    @test ENV["MODULE_UC_TEST_VALUE"] == "7"

    delete!(ENV, "MODULE_UC_TEST_VALUE")
    delete!(ENV, "MODULE_UC_TEST_BOOL")
    delete!(ENV, "MODULE_UC_TEST_EMPTY")
    rm(tmp_config; force = true)
end

@testset "model config from env" begin
    old_values = Dict{String, Union{Nothing, String}}("MODEL_CONSIDER_BESS" => get(ENV, "MODEL_CONSIDER_BESS", nothing),
        "MODEL_LOAD_CUTTING_COEFFICIENT" => get(ENV, "MODEL_LOAD_CUTTING_COEFFICIENT", nothing),
        "MODEL_CONSIDER_MULTI_CUTS" => get(ENV, "MODEL_CONSIDER_MULTI_CUTS", nothing))

    ENV["MODEL_CONSIDER_BESS"] = "1"
    ENV["MODEL_LOAD_CUTTING_COEFFICIENT"] = "123.5"
    ENV["MODEL_CONSIDER_MULTI_CUTS"] = "0"
    cfg = config_from_env()
    @test cfg.is_ConsiderBESS == 1
    @test cfg.is_LoadsCuttingCoefficient == 123.5
    @test cfg.is_ConsiderMultiCUTs == 0

    for (key, value) ∈ old_values
        if value === nothing
            delete!(ENV, key)
        else
            ENV[key] = value
        end
    end
end
