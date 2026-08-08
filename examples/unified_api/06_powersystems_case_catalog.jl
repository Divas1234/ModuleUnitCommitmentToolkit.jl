"""
    06_powersystems_case_catalog.jl

Unified PowerSystems case catalog example.

This program demonstrates four tasks:

1. Print the stable case catalog maintained by the toolkit.
2. Build native PowerSystems.System objects using `:ieee6`, `:ieee30`, or `:ieee118` aliases.
3. Verify that cases of different sizes convert to the same data type through `load_uc_data`.
4. Optionally solve the selected case with one algorithm.

By default, only construction and data bridging run to avoid starting a large optimization.
Set `UC_RUN_SOLVE=1` to call `solve_uc`.

Environment variables:

- `UC_CASE=ieee6|ieee30|ieee118`, default `ieee6`;
- `UC_ALGORITHM=benchmark|benders|ccg`, default `benchmark`;
- `UC_RUN_SOLVE=0|1`, default `0`;
- `UC_SCENARIO_LIMIT`, default `1`;
- `UC_HORIZON`, default `24`.
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems

const CASE_ALIAS = Symbol(get(ENV, "UC_CASE", "ieee6"))
const ALGORITHM = Symbol(get(ENV, "UC_ALGORITHM", "benchmark"))
const RUN_SOLVE = lowercase(get(ENV, "UC_RUN_SOLVE", "1")) in ("1", "true", "yes")
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))
const HORIZON = parse(Int, get(ENV, "UC_HORIZON", "24"))

println("Available curated PowerSystems cases:")
for case in list_powersystems_cases()
    println("  ", rpad(case.alias, 22), " -> ", case.case_name, " | ", case.description)
end

case = getproperty(powersystems_case_catalog(), CASE_ALIAS)
println("\nSelected case: ", case.alias, " (", case.description, ")")
sys = build_system_from_powersystems(CASE_ALIAS)

println("System dimensions:")
println("  buses      = ", length(collect(get_components(ACBus, sys))))
println("  generators = ", length(collect(get_components(ThermalStandard, sys))))
println("  branches   = ", length(collect(get_components(ACBranch, sys))))
println("  loads      = ", length(collect(get_components(PowerLoad, sys))))

data = load_uc_data(input = :powersystems, case_name = CASE_ALIAS, scenario_limit = SCENARIO_LIMIT, horizon = HORIZON)
println("Unified data dimensions: NB=$(data.NB), NG=$(data.NG), NL=$(data.NL), ND=$(data.ND), NT=$(data.NT)")

if RUN_SOLVE
    result = solve_uc(
        algorithm = ALGORITHM,
        input = :powersystems,
        case_name = CASE_ALIAS,
        scenario_limit = SCENARIO_LIMIT,
        horizon = HORIZON,
        calibration = (
            MODEL_CONSIDER_BESS = false,
            MODEL_CONSIDER_FREQUENCY_CONTROL = false,
            MODEL_CONSIDER_DATA_CENTER = false,
            CCG_INITIAL_SCENARIOS = 1,
            CCG_SCENARIOS_PER_ITERATION = 1,
            CCG_MAX_ITERATIONS = 1,
            BENDERS_MAX_ITERATIONS = 1,
            BENDERS_PARALLEL_SUBPROBLEMS = false,
        ),
        output_dir = joinpath(PROJECT_ROOT, "output", "examples", "powersystems", case.alias, String(ALGORITHM)),
        verbosity = :summary,
    )
    print_uc_result(result; detail = true)
else
    println("Set UC_RUN_SOLVE=1 to run ", ALGORITHM, " on ", CASE_ALIAS, ".")
end
