"""
    02_input_spec_and_data.jl

Demonstrate two forms of the unified data entry point:

1. Construct UCInputSpec and pass it to load_uc_data.
2. Call load_uc_data(; ...) directly with keywords.

This example does not start an optimizer; it checks the data object and key dimensions.
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "2"))

# UCInputSpec is a stable input contract.
# It groups the data source, scenario count, PowerSystems object, data centers, and
# frequency parameters so applications can validate and record them before solving.
spec = UCInputSpec(
    input = :excel,
    scenario_limit = SCENARIO_LIMIT,
    horizon = 24,
)

println("Input specification:")
println("  source         = ", spec.source)
println("  scenario_limit = ", spec.scenario_limit)
println("  horizon        = ", spec.horizon)
println("  case_name      = ", spec.case_name)

# load_uc_data(spec) returns a NamedTuple instead of a positional tuple.
# Fields such as data.NG and data.NS can be accessed without remembering field order.
data_from_spec = redirect_stdout(devnull) do
    load_uc_data(spec)
end

println("Data loaded through UCInputSpec:")
println("  buses             = ", data_from_spec.NB)
println("  generators        = ", data_from_spec.NG)
println("  lines             = ", data_from_spec.NL)
println("  load nodes        = ", data_from_spec.ND)
println("  wind generators   = ", data_from_spec.NW)
println("  scenarios         = ", data_from_spec.NS)
println("  horizon           = ", data_from_spec.NT)
println("  scenario prob.    = ", data_from_spec.full_scenario_probability)

# A direct keyword call is convenient for one-off reads.
# The same parameters should produce a structure aligned with data_from_spec.
data_direct = redirect_stdout(devnull) do
    load_uc_data(input = :excel, scenario_limit = SCENARIO_LIMIT, horizon = 24)
end

@assert data_direct.NS == data_from_spec.NS
@assert data_direct.NT == data_from_spec.NT
println("Direct keyword data entry matches UCInputSpec data entry.")
