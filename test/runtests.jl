using Pkg

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
if get(ENV, "MODULE_UC_TEST_ACTIVATE_LOCAL_PROJECT", "0") in ("1", "true", "yes")
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

include(joinpath(PROJECT_ROOT, "src", "renewables", "renewables.jl"))
include(joinpath(PROJECT_ROOT, "src", "input_data", "readers.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "constraints", "constraints.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "utilities", "linearization.jl"))
include(joinpath(PROJECT_ROOT, "src", "unit_commitment", "utilities", "decision_variables.jl"))
include(joinpath(PROJECT_ROOT, "tools", "benders", "models", "scuc_model.jl"))
include(joinpath(PROJECT_ROOT, "tools", "benders", "models", "batch_subproblems.jl"))

function ccg_env_bool(name::String, default::Bool)
	value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
	return value in ("1", "true", "yes", "y", "on")
end

include(joinpath(PROJECT_ROOT, "tools", "ccg", "dro_uncertainty.jl"))
include(joinpath(PROJECT_ROOT, "tools", "ccg", "ccg_helpers.jl"))

@testset "module_unitcommitment" begin
	include("test_runtime_config.jl")
	include("test_renewables.jl")
	include("test_data_pipeline.jl")
	include("test_model_utilities.jl")
	include("test_dro_uncertainty.jl")
	include("test_src_modules.jl")
	include("test_benders.jl")
	include("test_ccg_algorithm.jl")
end
