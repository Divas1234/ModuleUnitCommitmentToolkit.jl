using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using PowerSystems
using XLSX
using CSV
using DataFrames
using Dates
include(joinpath(@__DIR__, "..", "ccg", "ccg_solver.jl"))

const PSY = PowerSystems

println("====================================================")
println("Running Benchmark UC comparison with PowerSystems...")
println("====================================================")

# 1. Read Excel data to construct identical PowerSystems System
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

# 2. Build PowerSystems System
sys = System(100.0) # 100 MVA Base Power

# Add Buses
buses = Dict{Int, ACBus}()
NB = Int64(maximum([maximum(DataBranch[:, 2]), maximum(DataBranch[:, 3])]))
for i in 1:NB
    bus = ACBus(;
        number = i,
        name = "Bus $i",
        available = true,
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min=0.95, max=1.05),
        base_voltage = 138.0,
        area = nothing,
        load_zone = nothing
    )
    add_component!(sys, bus; skip_validation = true)
    buses[i] = bus
end

# Add Thermal Generators
NG = size(DataGen, 1)
for i in 1:NG
    id = Int(DataGen[i, 1])
    bus_id = Int(DataGen[i, 2])
    gen = ThermalStandard(;
        name = "Gen$id",
        available = true,
        status = true,
        bus = buses[bus_id],
        active_power = DataGen[i, 13],
        reactive_power = 0.0,
        rating = DataGen[i, 3],
        active_power_limits = (min=DataGen[i, 4], max=DataGen[i, 3]),
        reactive_power_limits = nothing,
        ramp_limits = (up=DataGen[i, 6], down=DataGen[i, 5]),
        operation_cost = ThermalGenerationCost(nothing),
        base_power = 100.0,
        time_limits = (up=DataGen[i, 9], down=DataGen[i, 10]),
        must_run = false,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL
    )
    add_component!(sys, gen; skip_validation = true)
end

# Add Lines
NL = size(DataBranch, 1)
for i in 1:NL
    id = Int(DataBranch[i, 1])
    from = Int(DataBranch[i, 2])
    to = Int(DataBranch[i, 3])
    line = Line(;
        name = "Line$id",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(buses[from], buses[to]),
        r = 0.0,
        x = DataBranch[i, 4],
        b = (from=0.0, to=0.0),
        g = (from=0.0, to=0.0),
        rating = DataBranch[i, 5],
        angle_limits = (min=-1.5, max=1.5)
    )
    add_component!(sys, line; skip_validation = true)
end

# Add PowerLoads
ND = size(DataLoad, 1)
dates = DateTime("2026-07-11T00:00:00"):Hour(1):DateTime("2026-07-11T23:00:00")
load_profile = LoadCurve[:, 2]
time_series_load = SingleTimeSeries("max_active_power", PSY.TimeSeries.TimeArray(dates, load_profile))

for j in 1:ND
    id = Int(DataLoad[j, 1])
    bus_id = Int(DataLoad[j, 2])
    percent = DataLoad[j, 3]
    load = PowerLoad(;
        name = "Load$id",
        available = true,
        bus = buses[bus_id],
        active_power = percent * load_profile[1],
        reactive_power = 0.0,
        base_power = 100.0,
        max_active_power = percent,
        max_reactive_power = 0.0
    )
    add_component!(sys, load; skip_validation = true)
    add_time_series!(sys, load, time_series_load)
end

# Add Renewables
for w in 1:size(WindsFreqParam, 1)
    id = w
    bus_id = 1
    wind = RenewableDispatch(;
        name = "Wind$id",
        available = true,
        bus = buses[bus_id],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 250.0,
        prime_mover_type = PrimeMovers.WT,
        reactive_power_limits = nothing,
        power_factor = 1.0,
        base_power = 100.0,
        operation_cost = RenewableGenerationCost(nothing)
    )
    add_component!(sys, wind; skip_validation = true)
end

# Add Storages
NC = size(StrogeData, 1)
for k in 1:NC
    id = Int(StrogeData[k, 1])
    bus_id = Int(StrogeData[k, 2])
    storage = EnergyReservoirStorage(;
        name = "Storage$id",
        available = true,
        bus = buses[bus_id],
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        storage_capacity = StrogeData[k, 3],
        storage_level_limits = (min=StrogeData[k, 4], max=StrogeData[k, 3]),
        initial_storage_capacity_level = StrogeData[k, 7],
        rating = StrogeData[k, 6],
        active_power = 0.0,
        input_active_power_limits = (min=0.0, max=StrogeData[k, 5]),
        output_active_power_limits = (min=0.0, max=StrogeData[k, 6]),
        efficiency = (in=StrogeData[k, 10], out=StrogeData[k, 11]),
        reactive_power = 0.0,
        reactive_power_limits = nothing,
        base_power = 100.0
    )
    add_component!(sys, storage; skip_validation = true)
end

# 3. Create extension CSV files in a temporary directory
case_dir = mktempdir()

# thermal_uc.csv
df_uc = DataFrame(
    generator_name = ["Gen$i" for i in 1:NG],
    min_uptime = DataGen[:, 9],
    min_downtime = DataGen[:, 10],
    initial_status = DataGen[:, 11],
    initial_hours = DataGen[:, 12],
    initial_power = DataGen[:, 13],
    cost_a = GenCost[:, 4],
    cost_b = GenCost[:, 3],
    cost_c = GenCost[:, 2],
    startup_cost_hot = GenCost[:, 6],
    startup_cost_cold = GenCost[:, 7],
    shutdown_cost = GenCost[:, 5],
    cold_start_time = GenCost[:, 8],
    ramp_up = DataGen[:, 6],
    ramp_down = DataGen[:, 5],
    startup_ramp = DataGen[:, 8],
    shutdown_ramp = DataGen[:, 7]
)
CSV.write(joinpath(case_dir, "thermal_uc.csv"), df_uc)

# frequency_parameters.csv
df_freq = DataFrame(
    device_name = vcat(["Gen$i" for i in 1:NG], ["Wind$i" for i in 1:size(WindsFreqParam, 1)]),
    H = vcat(UnitsFreqParam[:, 2], WindsFreqParam[:, 1]),
    D = vcat(UnitsFreqParam[:, 3], WindsFreqParam[:, 5]),
    K = vcat(UnitsFreqParam[:, 4], WindsFreqParam[:, 2]),
    F = vcat(UnitsFreqParam[:, 5], zeros(size(WindsFreqParam, 1))),
    T = vcat(UnitsFreqParam[:, 6], WindsFreqParam[:, 6]),
    R = vcat(UnitsFreqParam[:, 7], WindsFreqParam[:, 3]),
    Mw = vcat(zeros(NG), WindsFreqParam[:, 4])
)
CSV.write(joinpath(case_dir, "frequency_parameters.csv"), df_freq)

# storage_uc.csv
df_storage = DataFrame(
    storage_name = ["Storage$i" for i in 1:NC],
    initial_soc = StrogeData[:, 7],
    charge_ramp = StrogeData[:, 8],
    discharge_ramp = StrogeData[:, 9],
    self_discharge = StrogeData[:, 12]
)
CSV.write(joinpath(case_dir, "storage_uc.csv"), df_storage)

# renewable_profiles.csv
# In wind_profiles.jl:
# const DEFAULT_WIND_AVAILABILITY_PROFILE = [...]
# There are size(WindsFreqParam, 1) wind generators (Wind1, Wind2) with 2.5 rating each (250 MW).
const DEFAULT_WIND_AVAILABILITY_PROFILE = [
	0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300
	0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042
	0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410
	0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982
]

df_ren = DataFrame(
    generator_name = repeat(["Wind$i" for i in 1:size(WindsFreqParam, 1)], inner=24),
    time = repeat(collect(1:24), size(WindsFreqParam, 1)),
    generation = repeat(vec(DEFAULT_WIND_AVAILABILITY_PROFILE) * 250.0, size(WindsFreqParam, 1))
)
CSV.write(joinpath(case_dir, "renewable_profiles.csv"), df_ren)

# data_centers.csv
ND2 = size(datacentra_Data, 1)
df_dc = DataFrame(
    data_center_name = ["DC$i" for i in 1:ND2],
    bus_name = ["Bus $(Int(datacentra_Data[i, 2]))" for i in 1:ND2],
    p_max = datacentra_Data[:, 3] * 100.0,
    p_min = datacentra_Data[:, 4] * 100.0,
    voltage_regulation = datacentra_Data[:, 5],
    idale = datacentra_Data[:, 6] * 100.0,
    sv_constant = datacentra_Data[:, 7] * 100.0,
    λ = datacentra_Data[:, 8],
    μ = datacentra_Data[:, 9]
)
CSV.write(joinpath(case_dir, "data_centers.csv"), df_dc)

# data_center_workloads.csv
df_dc_wl = DataFrame(
    data_center_name = repeat(["DC$i" for i in 1:ND2], inner=24),
    time = repeat(collect(1:24), ND2),
    workload = fill(0.2, 24 * ND2)
)
CSV.write(joinpath(case_dir, "data_center_workloads.csv"), df_dc_wl)

# 4. Include benchmark UC tools
include(joinpath(@__DIR__, "benchmark_uc.jl"))

# 5. Run both solving methods and compare!
# 5a. Original benchmark from Excel data
println("\n[1/2] Solving UC Benchmark with original Excel reader...")
res_excel = solve_benchmark_uc(; scenario_limit = 5)
obj_excel = res_excel.upper_bound

# 5b. PowerSystems benchmark from serialized System + CSVs
println("\n[2/2] Solving UC Benchmark with PowerSystems.System + CSV adapter...")
res_ps = solve_benchmark_uc_powersystems(sys, case_dir; scenario_limit = 5)
obj_ps = res_ps.upper_bound

println("\n====================================================")
println("Results Comparison:")
println("Original Excel Objective:    ", obj_excel)
println("PowerSystems case Objective: ", obj_ps)
println("Objective Difference:       ", abs(obj_excel - obj_ps))
println("====================================================")

if abs(obj_excel - obj_ps) < 1e-2
    println("SUCCESS: The objectives match perfectly!")
else
    error("FAILURE: Objectives differ!")
end
