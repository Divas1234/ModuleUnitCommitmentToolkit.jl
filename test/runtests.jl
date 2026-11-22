const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
if get(ENV, "MODULE_UC_TEST_ACTIVATE_LOCAL_PROJECT", "0") in ("1", "true", "yes")
    using Pkg
    Pkg.activate(joinpath(PROJECT_ROOT, ".pkg"))
end

using Test
using LinearAlgebra
using Random
using JuMP
using Gurobi
using MathOptInterface
using XLSX
using Distributions

const MOI = MathOptInterface

include(joinpath(PROJECT_ROOT, "src", "core", "runtime_config.jl"))
include(joinpath(PROJECT_ROOT, "src", "core", "optimizer_config.jl"))
include(joinpath(PROJECT_ROOT, "src", "core", "deprecations.jl"))
include(joinpath(PROJECT_ROOT, "src", "renewables", "renewables.jl"))
include(joinpath(PROJECT_ROOT, "src", "input_data", "readers.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "constraints", "constraints.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "utilities", "linearization.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "utilities", "decision_variables.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "utilities", "export_results.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "validation", "validation.jl"))
include(joinpath(PROJECT_ROOT, "tools", "benders", "models", "scuc_model.jl"))
include(joinpath(PROJECT_ROOT, "tools", "benders", "models", "batch_subproblems.jl"))

ccg_env_bool(name::String, default::Bool) = uc_env_bool(name, default)

include(joinpath(PROJECT_ROOT, "tools", "ccg", "dro_uncertainty.jl"))
include(joinpath(PROJECT_ROOT, "tools", "ccg", "helpers.jl"))
include(joinpath(PROJECT_ROOT, "src", "core", "api_types.jl"))
include(joinpath(PROJECT_ROOT, "src", "core", "output_reporting.jl"))
include(joinpath(PROJECT_ROOT, "src", "core", "solver_interface.jl"))
include(joinpath(PROJECT_ROOT, "src", "production_cost", "entry.jl"))

@testset "module_unitcommitment" begin
    include("core/test_runtime_config.jl")
    include("core/test_unified_interface.jl")
    include("core/test_renewables.jl")
    include("core/test_data_pipeline.jl")
    include("powersystems/test_powersystems_reader.jl")
    include("powersystems/test_powersystems_bridge.jl")
    include("powersystems/test_powersystems_cases.jl")
    include("powersystems/test_ieee30_demo.jl")
    include("core/test_model_utilities.jl")
    include("core/test_hd_frequency_region.jl")
    include("algorithms/test_dro_uncertainty.jl")
    include("core/test_src_modules.jl")
    include("algorithms/test_benders.jl")
    include("algorithms/test_ccg_algorithm.jl")
    include("pcm/test_clustered_disaggregation.jl")
    include("pcm/test_clustered_pcm_adapter.jl")
    include("pcm/test_clustered_pcm_solver.jl")
    include("pcm/test_clustered_pcm_costs.jl")
    include("pcm/test_pcm_three_method_benchmark.jl")
    include("pcm/test_pcm_two_scale_benchmark.jl")
    include("pcm/test_overlap_training_cache.jl")
    include("pcm/test_clustered_adaptive_overlap.jl")
    include("pcm/test_pcm_unified_entrypoints.jl")
end
