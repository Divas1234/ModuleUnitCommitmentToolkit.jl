@testset "native PowerSystems input bridge" begin
    using PowerSystems

    system = System(100.0)
    bus1 = ACBus(;
        number = 10,
        name = "Bus 10",
        available = true,
        bustype = ACBusTypes.REF,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.95, max = 1.05),
        base_voltage = 138.0,
        area = nothing,
        load_zone = nothing,
    )
    bus2 = ACBus(;
        number = 20,
        name = "Bus 20",
        available = true,
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.95, max = 1.05),
        base_voltage = 138.0,
        area = nothing,
        load_zone = nothing,
    )
    add_component!(system, bus1; skip_validation = true)
    add_component!(system, bus2; skip_validation = true)

    generator = ThermalStandard(;
        name = "thermal-1",
        available = true,
        status = true,
        bus = bus1,
        active_power = 30.0,
        reactive_power = 0.0,
        rating = 80.0,
        active_power_limits = (min = 10.0, max = 80.0),
        reactive_power_limits = nothing,
        ramp_limits = (up = 25.0, down = 25.0),
        operation_cost = ThermalGenerationCost(nothing),
        base_power = 100.0,
        time_limits = (up = 2.0, down = 2.0),
        must_run = false,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
    )
    add_component!(system, generator; skip_validation = true)

    line = Line(;
        name = "line-1",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(bus1, bus2),
        r = 0.0,
        x = 0.1,
        b = (from = 0.0, to = 0.0),
        g = (from = 0.0, to = 0.0),
        rating = 100.0,
        angle_limits = (min = -1.5, max = 1.5),
    )
    add_component!(system, line; skip_validation = true)

    power_load = PowerLoad(;
        name = "load-1",
        available = true,
        bus = bus2,
        active_power = 50.0,
        reactive_power = 0.0,
        base_power = 100.0,
        max_active_power = 50.0,
        max_reactive_power = 0.0,
    )
    add_component!(system, power_load; skip_validation = true)

    frequency = Dict("thermal-1" => (H = 6.5, D = 1.2, K = 0.4, F = 0.3, T = 0.25, R = 0.05))
    centers = [(bus = 20, p_max = 12.0, p_min = 3.0, idle_power = 1.0, server_energy = 0.5, lambda = 2.0, mu = 4.0, workload = fill(0.5, 4))]
    data = load_uc_data(;
        use_powersystems = true,
        sys = system,
        scenario_limit = 1,
        frequency_parameters = frequency,
        data_centers = centers,
        horizon = 4,
    )

    @test data.NB == 2
    @test data.NG == 1
    @test data.NL == 1
    @test data.ND == 1
    @test data.NT == 4
    @test data.NC == 0
    @test data.ND2 == 1
    @test data.NW == 0
    @test data.units.locatebus == [1]
    @test data.loads.locatebus == [2]
    @test data.lines.from == [1]
    @test data.lines.to == [2]
    @test data.units.Hg == [6.5]
    @test data.units.Dg == [1.2]
    @test data.units.Kg == [0.4]
    @test data.units.Fg == [0.3]
    @test data.units.Tg == [0.25]
    @test data.units.Rg == [0.05]
    @test data.DataCentras.p_max == [0.12]
    @test data.DataCentras.p_min == [0.03]
    @test size(data.DataCentras.computational_power_tasks) == (1, 4)

    # Test automatic frequency parameter generation
    # Test automatic frequency parameter generation.
    freq_gen = generate_frequency_parameters(system)
    @test haskey(freq_gen, "thermal-1")
    @test freq_gen["thermal-1"].H == 6.0      # Coal template default.
    @test freq_gen["thermal-1"].R == 0.05     # Coal template droop.

    # Test name-based overrides
    # Test name-based parameter overrides.
    freq_override = generate_frequency_parameters(system; overrides = Dict("thermal-1" => (H = 9.9, D = 1.0, K = 2.0, F = 3.0, T = 4.0, R = 5.0)))
    @test freq_override["thermal-1"].H == 9.9
    @test freq_override["thermal-1"].R == 5.0
end
