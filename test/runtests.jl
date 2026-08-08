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

include("../src/renewables/renewables.jl")
include("../src/input_data/readers.jl")
include("../src/unit_commitment/constraints/constraints.jl")
include("../src/unit_commitment/utilities/linearization.jl")
include("../src/unit_commitment/utilities/decision_variables.jl")
include("../src/api_types.jl")
include("../src/output_reporting.jl")
include("../src/solver_interface.jl")

@testset "module_unitcommitment" begin
    include("test_runtime_config.jl")
    include("test_unified_interface.jl")
    include("test_renewables.jl")
    include("test_data_pipeline.jl")
    include("test_powersystems_reader.jl")
    include("test_powersystems_bridge.jl")
    include("test_powersystems_cases.jl")
    include("test_model_utilities.jl")
    include("test_src_modules.jl")
end
