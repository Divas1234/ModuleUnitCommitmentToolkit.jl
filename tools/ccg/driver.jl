# CCG production entry point.
#%%
# Runtime configuration is loaded transitively through `solver.jl` ->
# `tools/benders/setup.jl`, so `[model]`, `[ccg]`, and `[dro]` TOML sections are
# all applied before Excel data is converted into solver structures.
include("solver.jl")

# CCG has its own scenario limit, but falls back to the Benders limit for
# backward-compatible experiment scripts that only set one scenario variable.
scenario_limit = parse(Int64, get(ENV, "CCG_SCENARIO_LIMIT", get(ENV, "BENDERS_SCENARIO_LIMIT", "20")))
solve_ccg_unit_commitment(; scenario_limit = scenario_limit)
