"""
    07_ieee30_frequency_datacenter_uc.jl

Complete PowerSystems 30-bus unit commitment example.

This example splits a realistic application call into seven stages:

1. Select the `:ieee30` case through the unified entry point.
2. Read and print system boundaries, including buses, generators, branches, and loads.
3. Generate frequency parameters for all conventional generators and show H/D/K/F/T/R.
4. Add a wind generator and a flexible data center load at selected buses.
5. Configure virtual inertia, damping, and primary frequency response for wind power.
6. Check normalized model data and effective configuration through `load_uc_data`.
7. Call the unified UC entry point with `UCSolveRequest` and print layered results.

Input checks:

- All input boundaries and effective bridged configuration are first converted to `DataFrame` objects.
- DataFrames are printed as tables and saved under the run's `input/` directory before solving.
- Input snapshots and algorithm results are stored separately for reproducibility and review.

Run:

```bash
julia --project=. examples/unified_api/07_ieee30_frequency_datacenter_uc.jl
```

Optional environment variables:

- `UC_ALGORITHM=benchmark|benders|ccg`, default `benchmark`;
- `UC_HORIZON=4`, suitable for a quick smoke test; default `24`;
- `UC_SCENARIO_LIMIT=1`, default `1`;
- `UC_RUN_SOLVE=0`, construct and bridge data without starting optimization;
- `UC_FREQUENCY_CONTINGENCY_FRACTION=0.05`, disturbance fraction of reference capacity;
- `UC_WIND_PENETRATION=0.05`, wind capacity fraction of conventional generator rating;

Notes:

- Native PowerSystems components already use the system base per-unit system.
- The example adds wind at 5% penetration through `RenewableDispatch` on Bus 5 and configures
  `Fcmode/Kw/Rw/Mw/Dw/Tw` through the same `frequency_parameters` dictionary.
- Power parameters in `data_centers` use MW; the bridge converts them to internal per-unit values.
- Frequency control and data center constraints are explicitly enabled through `calibration`.
- The example uses `verbosity=:silent`, prints input boundaries itself, and then prints
  `UCSolveResult` to keep lower-level algorithm logs out of the application report.
"""

using Pkg
using Dates

# Use the project root as the active environment from either the repository root or examples directory.
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
Pkg.activate(PROJECT_ROOT)

using ModuleUnitCommitmentToolkit
using PowerSystems
using DataFrames
using CSV

"""Parse an environment variable as a positive integer and fail early with a clear error."""
function positive_int_env(name::AbstractString, default::Int)
    value = tryparse(Int, get(ENV, name, string(default)))
    value === nothing || value > 0 || throw(ArgumentError("$name must be a positive integer"))
    return value
end

"""Parse an environment variable as a ratio within the specified bounds."""
function bounded_float_env(name::AbstractString, default::Float64, lower::Float64, upper::Float64)
    value = tryparse(Float64, get(ENV, name, string(default)))
    value === nothing && throw(ArgumentError("$name must be a floating-point number"))
    lower <= value <= upper || throw(ArgumentError("$name must be in [$lower, $upper]"))
    return value
end

"""Parse an environment variable as a Boolean controlling whether optimization runs."""
function bool_env(name::AbstractString, default::Bool)
    value = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    value in ("1", "true", "yes", "y", "on") && return true
    value in ("0", "false", "no", "n", "off") && return false
    throw(ArgumentError("$name must be one of 0/1/true/false"))
end

"""Print a consistent section heading to separate input reports and solve results."""
function print_section(title::AbstractString)
    separator = repeat("=", 100)
    println("\n", separator)
    println("[", title, "]")
    println(separator)
end

"""Print an input table and save it as a CSV snapshot for the current run."""
function show_and_write_dataframe(df::DataFrame, name::AbstractString, input_dir::AbstractString)
    csv_path = joinpath(input_dir, string(name, ".csv"))
    CSV.write(csv_path, df)
    println("\n[", name, "]")
    show(stdout, MIME("text/plain"), df; allrows = true, allcols = true)
    println()
    println("saved_csv       : ", csv_path)
    return csv_path
end

const CASE_NAME = :ieee30
const ALGORITHM = Symbol(lowercase(get(ENV, "UC_ALGORITHM", "benchmark")))
const HORIZON = positive_int_env("UC_HORIZON", 24)
const SCENARIO_LIMIT = positive_int_env("UC_SCENARIO_LIMIT", 1)
const RUN_SOLVE = bool_env("UC_RUN_SOLVE", true)
const FREQUENCY_CONTINGENCY_FRACTION = bounded_float_env(
    "UC_FREQUENCY_CONTINGENCY_FRACTION", 0.05, 0.0, 1.0,
)
const WIND_PENETRATION = bounded_float_env("UC_WIND_PENETRATION", 0.05, 0.0, 1.0)
const OUTPUT_BASE_DIR = joinpath(
    PROJECT_ROOT, "output", "examples", "powersystems", "ieee30", String(ALGORITHM),
)
const RUN_ID = Dates.format(now(), "yyyymmdd_HHMMSS")
const RUN_OUTPUT_DIR = joinpath(OUTPUT_BASE_DIR, RUN_ID)
const INPUT_OUTPUT_DIR = joinpath(RUN_OUTPUT_DIR, "input")
mkpath(INPUT_OUTPUT_DIR)

ALGORITHM in (:benchmark, :benders, :ccg) ||
    throw(ArgumentError("UC_ALGORITHM must be benchmark, benders, or ccg"))

print_section("1. Select Case and Unified Entry Point")
case_entry = getproperty(powersystems_case_catalog(), CASE_NAME)
println("case alias       : ", CASE_NAME)
println("canonical case   : ", case_entry.case_name)
println("description      : ", case_entry.description)
println("algorithm        : ", ALGORITHM)
println("horizon          : ", HORIZON, " hours")
println("scenario_limit   : ", SCENARIO_LIMIT)
println("frequency fault  : ", FREQUENCY_CONTINGENCY_FRACTION, " of reference capacity")
println("wind penetration : ", WIND_PENETRATION, " of thermal ratings")
println("input snapshot   : ", INPUT_OUTPUT_DIR)

# Use the toolkit's unified entry point instead of calling PowerSystemCaseBuilder.build_system directly.
# The unified entry point resolves aliases, suppresses low-level rating diagnostics, and returns a native System.
sys = build_system_from_powersystems(CASE_NAME)
system_base = Float64(get_base_power(sys))

buses = sort(collect(get_components(ACBus, sys)), by = get_number)
thermal_generators = sort(collect(get_components(ThermalStandard, sys)), by = get_name)
thermal_capacity_pu = sum(Float64(get_rating(generator)) for generator in thermal_generators)
wind_rating_pu = thermal_capacity_pu * WIND_PENETRATION
wind_initial_pu = wind_rating_pu * 0.40

# Add a dispatchable wind generator to the native PowerSystems system.
# `RenewableDispatch` allows the unit to be curtailed in UC. The native MATPOWER components
# are already in SYSTEM_BASE pu, so the new component also uses pu. Wind capacity is computed
# from conventional generator rating using `UC_WIND_PENETRATION`, with initial output at 40% capacity.
const WIND_NAME = "IEEE30 Wind Farm"
const WIND_BUS = 5
wind_bus = only(filter(bus -> get_number(bus) == WIND_BUS, collect(get_components(ACBus, sys))))
wind_generator = RenewableDispatch(;
    name = WIND_NAME,
    available = true,
    bus = wind_bus,
    active_power = wind_initial_pu,
    reactive_power = 0.0,
    rating = wind_rating_pu,
    prime_mover_type = PrimeMovers.WT,
    reactive_power_limits = nothing,
    power_factor = 1.0,
    operation_cost = RenewableGenerationCost(nothing),
    base_power = system_base,
)
add_component!(sys, wind_generator)

wind_generators = sort(collect(get_components(RenewableGen, sys)), by = get_name)
branches = sort(collect(get_components(ACBranch, sys)), by = get_name)
power_loads = sort(collect(get_components(PowerLoad, sys)), by = get_name)

print_section("2. PowerSystems System Boundary")
println("system base power: ", system_base, " MVA")
println("buses            : ", length(buses))
println("thermal units    : ", length(thermal_generators))
println("thermal capacity : ", thermal_capacity_pu, " pu / ", thermal_capacity_pu * system_base, " MW")
println("wind units       : ", length(wind_generators))
println("AC branches      : ", length(branches))
println("power loads      : ", length(power_loads))

bus_df = DataFrame(
    number = [get_number(bus) for bus in buses],
    name = [get_name(bus) for bus in buses],
    type = [string(get_bustype(bus)) for bus in buses],
    base_voltage_kV = [Float64(get_base_voltage(bus)) for bus in buses],
)
show_and_write_dataframe(bus_df, "01_buses", INPUT_OUTPUT_DIR)

# Save both the original PowerSystems pmax and the UC pmax selected by the bridge.
# If native active_power_limits.max is zero, UC pmax falls back to a positive generator rating;
# displaying both fields makes source and effective model values easy to compare.
thermal_boundary_df = DataFrame(
    name = String[],
    bus = Int[],
    p_min_pu = Float64[],
    source_p_max_pu = Float64[],
    uc_p_max_pu = Float64[],
    rating_pu = Float64[],
    initial_pu = Float64[],
)
for generator in thermal_generators
    limits = get_active_power_limits(generator)
    source_p_max = Float64(limits.max)
    rating_pu = max(Float64(get_rating(generator)), 0.0)
    uc_p_max = source_p_max > 0.0 ? source_p_max : rating_pu
    push!(thermal_boundary_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        Float64(limits.min),
        source_p_max,
        uc_p_max,
        rating_pu,
        Float64(getproperty(generator, :active_power)),
    ))
end
show_and_write_dataframe(thermal_boundary_df, "02_thermal_generators", INPUT_OUTPUT_DIR)

wind_boundary_df = DataFrame(
    name = [get_name(generator) for generator in wind_generators],
    bus = [get_number(get_bus(generator)) for generator in wind_generators],
    active_power_pu = [Float64(getproperty(generator, :active_power)) for generator in wind_generators],
    rating_pu = [Float64(get_rating(generator)) for generator in wind_generators],
    rating_MW = [Float64(get_rating(generator)) * system_base for generator in wind_generators],
    penetration = fill(WIND_PENETRATION, length(wind_generators)),
)
show_and_write_dataframe(wind_boundary_df, "03_wind_generators", INPUT_OUTPUT_DIR)

branch_df = DataFrame(
    name = String[],
    from_bus = Int[],
    to_bus = Int[],
    x_pu = Float64[],
    rating_pu = Float64[],
    rating_MW = Float64[],
)
for branch in branches
    arc = get_arc(branch)
    rating_pu = Float64(get_rating(branch))
    push!(branch_df, (
        get_name(branch),
        get_number(get_from(arc)),
        get_number(get_to(arc)),
        Float64(get_x(branch)),
        rating_pu,
        rating_pu * system_base,
    ))
end
show_and_write_dataframe(branch_df, "04_branches", INPUT_OUTPUT_DIR)

load_df = DataFrame(
    name = [get_name(power_load) for power_load in power_loads],
    bus = [get_number(get_bus(power_load)) for power_load in power_loads],
    max_active_power_pu = [Float64(get_max_active_power(power_load)) for power_load in power_loads],
    max_active_power_MW = [Float64(get_max_active_power(power_load)) * system_base for power_load in power_loads],
)
show_and_write_dataframe(load_df, "05_loads", INPUT_OUTPUT_DIR)

print_section("3. Frequency Parameter Configuration")

# Generate the complete parameter dictionary first, then apply one physically interpretable
# parameter set to all conventional units. This avoids dependence on complete MATPOWER fuel fields
# and prevents zero K/R values from disabling governor response.
frequency_overrides = Dict{String, NamedTuple}(
    get_name(generator) => (H = 5.0, D = 0.08, K = 0.95, F = 0.30, T = 7.0, R = 0.05)
    for generator in thermal_generators
)
thermal_frequency_parameters = generate_frequency_parameters(sys; overrides = frequency_overrides)

# Wind uses six fields independent of thermal units:
# Fcmode=1 enables virtual inertia/damping; Kw/Rw are primary response gain/droop;
# Mw/Dw/Tw are equivalent inertia, damping, and response time constants.
wind_frequency_parameters = Dict{String, NamedTuple}(
    WIND_NAME => (Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0),
)
frequency_parameters = merge(thermal_frequency_parameters, wind_frequency_parameters)

thermal_frequency_df = DataFrame(
    name = String[],
    bus = Int[],
    H_s = Float64[],
    D = Float64[],
    K = Float64[],
    F = Float64[],
    T_s = Float64[],
    R = Float64[],
)
for generator in thermal_generators
    parameter = frequency_parameters[get_name(generator)]
    push!(thermal_frequency_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        parameter.H,
        parameter.D,
        parameter.K,
        parameter.F,
        parameter.T,
        parameter.R,
    ))
end
show_and_write_dataframe(thermal_frequency_df, "06_thermal_frequency_parameters", INPUT_OUTPUT_DIR)

wind_frequency_df = DataFrame(
    name = String[],
    bus = Int[],
    Fcmode = Float64[],
    Kw = Float64[],
    Rw = Float64[],
    Mw = Float64[],
    Dw = Float64[],
    Tw_s = Float64[],
)
for generator in wind_generators
    parameter = frequency_parameters[get_name(generator)]
    push!(wind_frequency_df, (
        get_name(generator),
        get_number(get_bus(generator)),
        parameter.Fcmode,
        parameter.Kw,
        parameter.Rw,
        parameter.Mw,
        parameter.Dw,
        parameter.Tw,
    ))
end
show_and_write_dataframe(wind_frequency_df, "07_wind_frequency_parameters", INPUT_OUTPUT_DIR)

print_section("4. Data Center Attachment")

# Data center bus values use native PowerSystems bus numbers rather than internal contiguous indices.
# p_max, p_min, idle_power, and server_energy use MW; the bridge converts them to pu.
# workload is relative and is normalized internally by the data center response model.
const DATA_CENTER_BUS = 5
data_centers = [(
    bus = DATA_CENTER_BUS,
    p_max = 20.0,
    p_min = 0.0,
    idle_power = 1.0,
    server_energy = 0.05,
    lambda = 1.0,
    mu = 1.0,
    workload = fill(0.10, HORIZON),
)]

println("data center count : ", length(data_centers))
data_center_df = DataFrame(
    center_id = collect(1:length(data_centers)),
    bus = [center.bus for center in data_centers],
    p_min_MW = [center.p_min for center in data_centers],
    p_max_MW = [center.p_max for center in data_centers],
    idle_power_MW = [center.idle_power for center in data_centers],
    server_energy = [center.server_energy for center in data_centers],
    lambda = [center.lambda for center in data_centers],
    mu = [center.mu for center in data_centers],
    workload_mean = [sum(center.workload) / length(center.workload) for center in data_centers],
    workload_min = [minimum(center.workload) for center in data_centers],
    workload_max = [maximum(center.workload) for center in data_centers],
)
show_and_write_dataframe(data_center_df, "08_data_centers", INPUT_OUTPUT_DIR)

# The unified interface temporarily converts calibration to environment variables for this solve.
# The two key switches must be explicitly true; otherwise the model skips the mounted constraints.
const CALIBRATION = (
    MODEL_CONSIDER_FREQUENCY_CONTROL = true,
    MODEL_CONSIDER_DATA_CENTER = true,
    MODEL_CONSIDER_BESS = false,
    # The demonstration contingency size is controlled by an entry environment variable;
    # use the actual N-1 contingency for formal studies.
    FREQUENCY_CONTINGENCY_FRACTION = FREQUENCY_CONTINGENCY_FRACTION,
    MODEL_MAX_ITERATIONS_NUM = 5,
    CCG_INITIAL_SCENARIOS = 1,
    CCG_SCENARIOS_PER_ITERATION = 1,
    CCG_MAX_ITERATIONS = 3,
    BENDERS_MAX_ITERATIONS = 3,
    BENDERS_PARALLEL_SUBPROBLEMS = false,
)

# To print the effective configuration before solving, load a temporary data snapshot with
# the same calibration as solve_uc. This keeps the displayed and optimized configurations aligned.
function calibration_env_pairs(calibration)
    return [
        uppercase(string(key)) => (value isa Bool ? (value ? "1" : "0") : string(value))
        for (key, value) in pairs(calibration)
    ]
end

request = UCSolveRequest(
    algorithm = ALGORITHM,
    input = :powersystems,
    sys = sys,
    scenario_limit = SCENARIO_LIMIT,
    frequency_parameters = frequency_parameters,
    data_centers = data_centers,
    horizon = HORIZON,
    calibration = CALIBRATION,
    output_dir = RUN_OUTPUT_DIR,
    # Solve silently, then print layered inputs and results from this example to keep lower-level logs separate.
    verbosity = :silent,
)

data = withenv(calibration_env_pairs(CALIBRATION)...) do
    load_uc_data(request.input)
end

print_section("5. Unified UC Data and Effective Configuration")
dimensions_df = DataFrame(
    parameter = [
        "system_base_MVA", "NB", "NG", "NL", "ND", "NT", "ND2", "NW", "NS",
        "thermal_capacity_pu", "wind_penetration", "frequency_contingency_fraction",
    ],
    value = Any[
        system_base, data.NB, data.NG, data.NL, data.ND, data.NT, data.ND2, data.NW, data.NS,
        thermal_capacity_pu, WIND_PENETRATION, FREQUENCY_CONTINGENCY_FRACTION,
    ],
)
show_and_write_dataframe(dimensions_df, "09_model_dimensions", INPUT_OUTPUT_DIR)

config_fields = fieldnames(typeof(data.config_param))
config_df = DataFrame(
    parameter = [string(field) for field in config_fields],
    value = Any[getfield(data.config_param, field) for field in config_fields],
)
show_and_write_dataframe(config_df, "10_effective_config", INPUT_OUTPUT_DIR)

wind_capacity_df = DataFrame(
    wind_id = collect(1:length(data.winds.p_max)),
    p_max_pu = Float64.(data.winds.p_max),
    p_max_MW = Float64.(data.winds.p_max .* system_base),
    Fcmode = Float64.(data.winds.Fcmode),
    Kw = Float64.(data.winds.Kw),
    Rw = Float64.(data.winds.Rw),
    Mw = Float64.(data.winds.Mw),
    Dw = Float64.(data.winds.Dw),
    Tw_s = Float64.(data.winds.Tw),
)
show_and_write_dataframe(wind_capacity_df, "11_unified_wind_parameters", INPUT_OUTPUT_DIR)

wind_scenario_values = vec(permutedims(data.winds.scenarios_curve))
wind_availability_df = DataFrame(
    scenario = repeat(1:data.NS, inner = data.NT),
    time = repeat(1:data.NT, data.NS),
    availability = Float64.(wind_scenario_values),
)
show_and_write_dataframe(wind_availability_df, "12_wind_availability", INPUT_OUTPUT_DIR)

println("\ninput snapshots saved before solve: ", INPUT_OUTPUT_DIR)

if RUN_SOLVE
    print_section("6. Start Unified UC Solve")
    println("algorithm: ", request.algorithm)
    println("output_dir: ", request.output_dir)
    println("frequency control: enabled")
    println("data center model: enabled")

    # The solver routes request.algorithm to benchmark, Benders, or CCG internally.
    # Callers do not need to include algorithm scripts or assemble positional tuples.
    # Pass the same run_id to scheduling export logic so input snapshots and
    # benchmark_uc/<run_id>/scheduling/ share one timestamp for grouped archiving.
    result = withenv("MODULE_UC_RUN_ID" => RUN_ID) do
        solve_uc(request)
    end

    # detail=true prints status, bounds, gap, model size, iteration history, cost breakdown, and diagnostics.
    print_uc_result(result; detail = true)
else
    println("\nUC_RUN_SOLVE=0: case construction and data bridging completed; optimization was not started.")
end