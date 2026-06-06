# Enforce ASCII console output for compatibility.
ENV["JULIA_SHOW_ASCII"] = true

include("ccg_solver.jl")

scenario_limit = parse(Int64, get(ENV, "CCG_SCENARIO_LIMIT", get(ENV, "BENDERS_SCENARIO_LIMIT", "20")))
solve_ccg_unit_commitment(; scenario_limit = scenario_limit)
