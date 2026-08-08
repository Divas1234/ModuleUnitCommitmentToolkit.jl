"""
    05_benders_named_setup.jl

Benders has two invocation levels:

* application level: prefer solve_uc(algorithm=:benders, ...);
* algorithm debugging level: call main() to obtain BendersSetup and access named fields.

This program demonstrates the second approach and the migration away from the legacy 20-item positional tuple.
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

# The low-level Benders example needs main and multiple_bender_decomposition_scuc.
# Production application code should use solve_uc instead of these includes.
include(joinpath(PROJECT_ROOT, "tools", "benders", "setup.jl"))

const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const MAX_ITERATIONS = get(ENV, "BENDERS_MAX_ITERATIONS", "5")

# main returns BendersSetup instead of an anonymous positional tuple.
setup = main(input = :excel, scenario_limit = SCENARIO_LIMIT)

# Prefer named fields so changes in field order cannot silently misalign values.
master_model = setup.master_model
sub_model = setup.sub_model
master_struct = setup.master_struct
batch_subproblems = setup.batch_subproblems
winds = setup.winds
config_param = setup.config_param
NG = setup.NG
NT = setup.NT
ND = setup.ND
NL = setup.NL

println("Benders setup dimensions:")
println("  NB = ", setup.NB, ", NG = ", setup.NG, ", NL = ", setup.NL)
println("  ND = ", setup.ND, ", NS = ", setup.NS, ", NT = ", setup.NT)
println("  NC = ", setup.NC, ", ND2 = ", setup.ND2)

# Use the compatibility iterator only when maintaining legacy programs.
# It preserves the historical 20-item order but excludes the new setup.data field.
legacy_values = collect(setup)
@assert length(legacy_values) == 20
println("legacy compatibility values = ", length(legacy_values))

# Low-level Benders solving still requires models and dimensions in the algorithm signature.
# The named object improves setup readability and compatibility migration.
result = withenv("BENDERS_MAX_ITERATIONS" => MAX_ITERATIONS, "BENDERS_PARALLEL_SUBPROBLEMS" => "0") do
    return multiple_bender_decomposition_scuc(
        master_model,
        sub_model,
        master_struct,
        batch_subproblems,
        winds,
        config_param,
        NG,
        NT,
        length(winds.index),
        ND,
        NL,
    )
end

println("status      = ", result.status)
println("upper_bound = ", result.upper_bound)
println("lower_bound = ", result.lower_bound)
println("gap         = ", result.gap)
