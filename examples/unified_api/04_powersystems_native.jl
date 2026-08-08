"""
    04_powersystems_native.jl

Demonstrate the unified entry point with a native PowerSystems.System:

1. Build a built-in system with PowerSystemCaseBuilder.
2. Pass data center parameters through data_centers.
3. Pass generator frequency parameters through frequency_parameters.
4. Reuse the same PowerSystems data entry point by changing only algorithm.

This example runs CCG by default. Set UC_ALGORITHM=benchmark or benders to run another algorithm.
"""

using Pkg
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems
using PowerSystemCaseBuilder

const ALGORITHM = Symbol(get(ENV, "UC_ALGORITHM", "ccg"))
const SCENARIO_LIMIT = parse(Int, get(ENV, "UC_SCENARIO_LIMIT", "1"))

# Build a native PowerSystems System.
# If a sys object already exists, skip this step and pass it directly to solve_uc.
const CASE_NAME = "c_sys5_all_components"
println("Building PowerSystems case: ", CASE_NAME)
sys = build_system_from_powersystems(CASE_NAME; case_category = PSITestSystems)

# Frequency parameters are keyed by generator name.
# Use non-zero R values for units without frequency control to avoid fitting division by zero.
frequency_parameters = Dict(
    "Solitude" => (H = 7.0, D = 0.061, K = 0.9, F = 0.15, T = 8.0, R = 0.06),
    "Park City" => (H = 5.5, D = 0.121, K = 0.95, F = 0.35, T = 7.0, R = 0.06),
    "Alta" => (H = 3.5, D = 0.181, K = 0.98, F = 0.25, T = 9.0, R = 0.06),
    "Brighton" => (H = 5.0, D = 0.0, K = 0.0, F = 0.0, T = 0.0, R = 1.0),
    "Sundance" => (H = 5.0, D = 0.0, K = 0.0, F = 0.0, T = 0.0, R = 1.0),
)

# Power values in data_centers use MW; the bridge converts them to internal per-unit values.
data_centers = [
    (
        bus = 3,
        p_max = 0.5,
        p_min = 0.0,
        idle_power = 0.0,
        server_energy = 0.0,
        lambda = 0.0,
        mu = 1.0,
        workload = fill(0.0, 24),
    ),
]

result = solve_uc(
    algorithm = ALGORITHM,
    input = :powersystems,
    sys = sys,
    scenario_limit = SCENARIO_LIMIT,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = 24,
    calibration = (
        MODEL_CONSIDER_BESS = false,
        MODEL_CONSIDER_FREQUENCY_CONTROL = false,
        MODEL_CONSIDER_DATA_CENTER = true,
        CCG_INITIAL_SCENARIOS = 1,
        CCG_SCENARIOS_PER_ITERATION = 1,
        CCG_MAX_ITERATIONS = 1,
        BENDERS_MAX_ITERATIONS = 1,
        BENDERS_PARALLEL_SUBPROBLEMS = false,
    ),
    output_dir = joinpath(PROJECT_ROOT, "output", "examples", "powersystems", String(ALGORITHM)),
    verbosity = :silent,
)

print_uc_result(result)
