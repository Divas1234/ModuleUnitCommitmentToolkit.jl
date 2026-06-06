# Quick Wasserstein DRO CCG example.
#
# Run from the repository root:
#   julia examples/ccg/run_wasserstein_dro_ccg.jl

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
cd(PROJECT_ROOT)

ENV["MODULE_UC_CONFIG_FILE"] = get(
	ENV,
	"MODULE_UC_CONFIG_FILE",
	joinpath(PROJECT_ROOT, "examples", "ccg", "runtime_config_quick.toml"),
)

println("Running Wasserstein DRO CCG example")
println("  config file: ", ENV["MODULE_UC_CONFIG_FILE"])

include(joinpath(PROJECT_ROOT, "tools", "ccg", "driver.jl"))
