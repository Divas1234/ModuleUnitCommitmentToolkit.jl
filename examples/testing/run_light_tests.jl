# Run the lightweight project test suite from examples.
#
# Run from the repository root:
#   julia examples/testing/run_light_tests.jl

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
cd(PROJECT_ROOT)

include(joinpath(PROJECT_ROOT, "test", "runtests.jl"))
