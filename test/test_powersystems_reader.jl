@testset "PowerSystems.jl CSV input adapter" begin
    using PowerSystems
    using CSV
    using DataFrames
    using Dates
    using Random

    PSY = PowerSystems
    TS = PSY.TimeSeries

    # 1. Build a mock PowerSystems.System
    sys = System(100.0) # Base power: 100 MVA
    set_runchecks!(sys, false) # Mock 数据有意使用简化/非物理参数，关闭组件范围校验。

    bus1 = ACBus(; number = 1, name = "Bus 1", available = true, bustype = ACBusTypes.PQ, angle = 0.0, magnitude = 1.0,
        voltage_limits = (min = 0.95, max = 1.05), base_voltage = 138.0, area = nothing, load_zone = nothing)
    add_component!(sys, bus1)

    bus2 = ACBus(; number = 2, name = "Bus 2", available = true, bustype = ACBusTypes.PV, angle = 0.0, magnitude = 1.0,
        voltage_limits = (min = 0.95, max = 1.05), base_voltage = 138.0, area = nothing, load_zone = nothing)
    add_component!(sys, bus2)

    gen1 = ThermalStandard(; name = "Gen1", available = true, status = true, bus = bus1, active_power = 20.0, reactive_power = 10.0,
        rating = 60.0, active_power_limits = (min = 10.0, max = 50.0), reactive_power_limits = (min = -20.0, max = 20.0),
        ramp_limits = (up = 15.0, down = 15.0), operation_cost = ThermalGenerationCost(nothing), base_power = 100.0,
        time_limits = (up = 4.0, down = 4.0), must_run = false, prime_mover_type = PrimeMovers.ST, fuel = ThermalFuels.COAL)
    add_component!(sys, gen1)

    line1 = Line(; name = "Line1", available = true, active_power_flow = 0.0, reactive_power_flow = 0.0, arc = Arc(bus1, bus2), r = 0.01,
        x = 0.1, b = (from = 0.0, to = 0.0), g = (from = 0.0, to = 0.0), rating = 40.0, angle_limits = (min = -1.5, max = 1.5))
    add_component!(sys, line1)

    load1 = PowerLoad(; name = "Load1", available = true, bus = bus2, active_power = 25.0, reactive_power = 15.0,
        base_power = 100.0, max_active_power = 30.0, max_reactive_power = 18.0)
    add_component!(sys, load1)

    storage1 = EnergyReservoirStorage(;
        name = "Storage1", available = true, bus = bus1, prime_mover_type = PrimeMovers.BA, storage_technology_type = StorageTech.OTHER_CHEM,
        storage_capacity = 20.0, storage_level_limits = (min = 2.0, max = 20.0), initial_storage_capacity_level = 10.0, rating = 10.0,
        active_power = 0.0, input_active_power_limits = (min = 0.0, max = 10.0), output_active_power_limits = (min = 0.0, max = 10.0),
        efficiency = (in = 0.9, out = 0.9), reactive_power = 0.0, reactive_power_limits = nothing, base_power = 100.0)
    add_component!(sys, storage1)

    wind1 = RenewableDispatch(;
        name = "Wind1", available = true, bus = bus1, active_power = 5.0, reactive_power = 0.0, rating = 15.0, prime_mover_type = PrimeMovers.WT,
        reactive_power_limits = nothing, power_factor = 1.0, base_power = 100.0, operation_cost = RenewableGenerationCost(nothing))
    add_component!(sys, wind1)

    # Attach SingleTimeSeries to load1
    dates = DateTime("2026-07-11T00:00:00"):Hour(1):DateTime("2026-07-11T23:00:00")
    load_profile = fill(0.8, 24)
    time_series_load = SingleTimeSeries("max_active_power", TS.TimeArray(dates, load_profile))
    add_time_series!(sys, load1, time_series_load)

    # 2. Setup temporary directory with extension CSV files
    temp_dir = mktempdir()

    # UC extensions
    df_uc = DataFrame(generator_name = ["Gen1"], min_uptime = [4.0], min_downtime = [4.0], initial_status = [1.0], initial_hours = [10.0],
        initial_power = [20.0], cost_a = [0.01], cost_b = [10.0], cost_c = [100.0], startup_cost_hot = [50.0], startup_cost_cold = [100.0],
        shutdown_cost = [20.0], cold_start_time = [8.0], ramp_up = [15.0], ramp_down = [15.0], startup_ramp = [20.0], shutdown_ramp = [20.0])
    CSV.write(joinpath(temp_dir, "thermal_uc.csv"), df_uc)

    # Frequency extensions
    df_freq = DataFrame(device_name = ["Gen1", "Wind1"], H = [5.0, 1.0], D = [1.0, 1.0], K = [20.0, 0.05],
        F = [0.3, 0.0], T = [0.2, 0.0], R = [0.05, 0.1], Mw = [0.0, 1.0])
    CSV.write(joinpath(temp_dir, "frequency_parameters.csv"), df_freq)

    # Storage extensions
    df_storage = DataFrame(storage_name = ["Storage1"], initial_soc = [8.0], charge_ramp = [5.0], discharge_ramp = [5.0], self_discharge = [0.001])
    CSV.write(joinpath(temp_dir, "storage_uc.csv"), df_storage)

    # Renewable profiles
    df_ren = DataFrame(generator_name = repeat(["Wind1"], 24), time = collect(1:24), generation = fill(10.0, 24))
    CSV.write(joinpath(temp_dir, "renewable_profiles.csv"), df_ren)

    # Data center extensions
    df_dc = DataFrame(data_center_name = ["DC1"], bus_name = ["Bus 1"], p_max = [10.0], p_min = [2.0],
        voltage_regulation = [0.05], idale = [1.0], sv_constant = [0.1], λ = [10.0], μ = [20.0])
    CSV.write(joinpath(temp_dir, "data_centers.csv"), df_dc)

    # Data center workloads
    df_dc_wl = DataFrame(data_center_name = repeat(["DC1"], 24), time = collect(1:24), workload = fill(0.5, 24))
    CSV.write(joinpath(temp_dir, "data_center_workloads.csv"), df_dc_wl)

    # Enable all relevant sub-components in env config for the test scope
    withenv("MODEL_CONSIDER_BESS" => "1", "MODEL_CONSIDER_FREQUENCY_CONTROL" => "1", "MODEL_CONSIDER_DATA_CENTER" => "1") do
        # 3. Call the adapter
        config_param, units, lines, loads, stroges, winds, NB, NG, NL, ND, NT, NC, ND2, datacentra_data = read_powersystems_case(sys, temp_dir; scenario_limit = 1)

        # 4. Verify outputs
        @test config_param isa config
        @test config_param.is_ConsiderBESS == 1
        @test config_param.is_ConsiderFrequencyControl == 1
        @test config_param.is_ConsiderDataCentra == 1

        @test NB == 2
        @test NG == 1
        @test NL == 1
        @test ND == 1
        @test NT == 24
        @test NC == 1
        @test ND2 == 1

        # Generator fields
        @test units.locatebus == [1]
        @test units.p_max == [50.0 / 100.0]
        @test units.p_min == [10.0 / 100.0]
        @test units.min_shutup_time == [4.0]
        @test units.min_shutdown_time == [4.0]
        @test units.x_0 == [1.0]
        @test units.t_0 == [10.0]
        @test units.p_0 == [20.0 / 100.0]
        @test units.coffi_a ≈ [0.01 * 100.0^2]
        @test units.coffi_b ≈ [10.0 * 100.0]
        @test units.coffi_c == [100.0]
        @test units.coffi_cold_shutup_1 == [50.0]
        @test units.coffi_cold_shutup_2 == [100.0]
        @test units.coffi_cold_shutdown_1 == [20.0]
        @test units.coffi_cold_shutdown_2 == [8.0]
        @test units.ramp_up == [15.0 / 100.0]
        @test units.ramp_down == [15.0 / 100.0]
        @test units.shut_up == [20.0 / 100.0]
        @test units.shut_down == [20.0 / 100.0]

        # Generator frequency response
        @test units.Hg == [5.0]
        @test units.Dg == [1.0]
        @test units.Kg == [20.0]
        @test units.Fg == [0.3]
        @test units.Tg == [0.2]
        @test units.Rg == [0.05]

        # Transmission lines
        @test lines.from == [1]
        @test lines.to == [2]
        @test lines.x == [0.1]
        @test lines.p_max == [40.0 / 100.0]
        @test lines.p_min == [-40.0 / 100.0]

        # Loads
        @test loads.locatebus == [2]
        @test size(loads.load_curve) == (1, 24)
        @test loads.load_curve[1, 1] ≈ 0.8 * 30.0 / 100.0

        # Storage
        @test stroges.locatebus == [1]
        @test stroges.Q_max == [20.0 / 100.0]
        @test stroges.Q_min == [2.0 / 100.0]
        @test stroges.p⁺ == [10.0 / 100.0]
        @test stroges.p⁻ == [10.0 / 100.0]
        @test stroges.P₀ == [8.0 / 100.0]
        @test stroges.γ⁺ == [5.0 / 100.0]
        @test stroges.γ⁻ == [5.0 / 100.0]
        @test stroges.η⁺ == [0.9]
        @test stroges.η⁻ == [0.9]
        @test stroges.δₛ == [0.001]

        # Wind / Renewables
        @test winds.locatebus == [1]
        @test winds.p_max == [15.0 / 100.0]
        @test winds.scenarios_nums == 1
        @test winds.scenarios_prob == 1.0
        @test winds.scenarios_curve[1, 1] ≈ 10.0 / 15.0
        @test winds.Fcmode == [1.0]
        @test winds.Kw == [0.05]
        @test winds.Rw == [0.1]
        @test winds.Mw == [1.0]
        @test winds.Dw == [1.0]
        @test winds.Tw == [0.0]

        # Data centers
        @test datacentra_data.locatebus == [1]
        @test datacentra_data.p_max == [10.0 / 100.0]
        @test datacentra_data.p_min == [2.0 / 100.0]
        @test datacentra_data.voltage_regulation == [0.05]
        @test datacentra_data.idale == [1.0 / 100.0]
        @test datacentra_data.sv_constant == [0.1 / 100.0]
        @test datacentra_data.λ == [10.0]
        @test datacentra_data.μ == [20.0]
        @test datacentra_data.computational_power_tasks[1, :] == fill(0.5, 24)
    end

    # 5. Negative/Error Tests
    # 5a. Missing thermal_uc.csv
    rm(joinpath(temp_dir, "thermal_uc.csv"))
    @test_throws ArgumentError read_powersystems_case(sys, temp_dir)

    # Re-write df_uc
    CSV.write(joinpath(temp_dir, "thermal_uc.csv"), df_uc)

    # 5b. Invalid initial status
    df_uc_bad = copy(df_uc)
    df_uc_bad.initial_status = [2.0]
    CSV.write(joinpath(temp_dir, "thermal_uc.csv"), df_uc_bad)
    @test_throws ArgumentError read_powersystems_case(sys, temp_dir)
end
