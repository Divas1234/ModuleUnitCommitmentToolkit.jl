@testset "PowerSystems case catalog" begin
    using Logging
    using PowerSystems
    catalog = powersystems_case_catalog()

    @test hasproperty(catalog, :ieee6)
    @test hasproperty(catalog, :ieee30)
    @test hasproperty(catalog, :ieee118)
    @test hasproperty(catalog, :rts_gmlc)
    @test catalog.ieee6.case_name == "matpower_case6_sys"
    @test catalog.ieee30.case_name == "matpower_case30_sys"
    @test catalog.ieee118.case_name == "118_bus"

    listed = list_powersystems_cases()
    listed_names = Set(item.alias for item in listed)
    @test all(name in listed_names for name in ("ieee6", "ieee30", "ieee118", "rts_gmlc"))

    system6 = build_system_from_powersystems("ieee6")
    system30 = build_system_from_powersystems(:ieee30)
    system118 = build_system_from_powersystems("ieee118")

    @test_logs min_level = Logging.Debug build_system_from_powersystems("ieee6")

    @test length(collect(get_components(ACBus, system6))) == 6
    @test length(collect(get_components(ACBus, system30))) == 30
    @test length(collect(get_components(ACBus, system118))) == 118

    data6 = load_uc_data(input = :powersystems, case_name = :ieee6, scenario_limit = 1, horizon = 4)
    data30 = load_uc_data(input = :powersystems, case_name = "ieee30", scenario_limit = 1, horizon = 4)
    data118 = load_uc_data(input = :powersystems, case_name = "ieee118", scenario_limit = 1, horizon = 4)

    @test (data6.NB, data6.NG, data6.NL, data6.NT) == (6, 6, 6, 4)
    @test all(isfinite, data6.units.coffi_a)
    @test all(isfinite, data6.units.coffi_b)
    @test all(isfinite, data6.units.coffi_c)
    refcost6, slopes6 = linearizationfuelcurve(data6.units, data6.NG)
    @test all(isfinite, refcost6)
    @test all(isfinite, slopes6)
    @test data30.NB == 30
    @test data118.NB == 118
    @test data118.NG > data30.NG
    @test data118.NL > data30.NL

    # A native PowerSystems renewable component must flow through the same
    # frequency_parameters dictionary as thermal units, while preserving the
    # wind-specific Fcmode/Kw/Rw/Mw/Dw/Tw fields.
    wind_bus = only(filter(bus -> get_number(bus) == 5, collect(get_components(ACBus, system30))))
    wind_generator = RenewableDispatch(; 
        name = "IEEE30 Wind Farm",
        available = true,
        bus = wind_bus,
        active_power = 0.10,
        reactive_power = 0.0,
        rating = 0.20,
        prime_mover_type = PrimeMovers.WT,
        reactive_power_limits = nothing,
        power_factor = 1.0,
        operation_cost = RenewableGenerationCost(nothing),
        base_power = get_base_power(system30),
    )
    add_component!(system30, wind_generator; skip_validation = true)
    wind_frequency_parameters = Dict(
        "IEEE30 Wind Farm" => (Fcmode = 1.0, Kw = 0.08, Rw = 0.10, Mw = 1.50, Dw = 0.40, Tw = 5.0),
    )
    data30_with_wind = load_uc_data(
        input = :powersystems,
        sys = system30,
        scenario_limit = 1,
        frequency_parameters = wind_frequency_parameters,
        horizon = 4,
    )
    @test data30_with_wind.NW == 1
    @test data30_with_wind.winds.Fcmode == [1.0]
    @test data30_with_wind.winds.Kw == [0.08]
    @test data30_with_wind.winds.Rw == [0.10]
    @test data30_with_wind.winds.Mw == [1.50]
    @test data30_with_wind.winds.Dw == [0.40]
    @test data30_with_wind.winds.Tw == [5.0]

    # PowerSystems components are stored in SYSTEM_BASE units. The bridge must
    # not divide these values by the system base a second time.
    native_generators6 = sort(collect(get_components(ThermalStandard, system6)), by = get_name)
    native_lines6 = sort(collect(get_components(Line, system6)), by = get_name)
    @test data6.units.p_max == Float64[get_active_power_limits(generator).max for generator in native_generators6]
    @test data6.lines.p_max == Float64[get_rating(line) for line in native_lines6]
    @test maximum(data6.units.p_max) > 1.0

    empty_winds = (
        index = Int64[],
        Fcmode = Float64[],
        Kw = Float64[],
        Rw = Float64[],
        Mw = Float64[],
        Dw = Float64[],
        Tw = Float64[],
        p_max = Float64[],
    )
    support_fn = isdefined(Main, :wind_frequency_capacity_support) ?
        getfield(Main, :wind_frequency_capacity_support) :
        getfield(ModuleUnitCommitmentToolkit, :wind_frequency_capacity_support)
    @test support_fn(empty_winds) == (inertia = 0.0, damping = 0.0, primary = 0.0)
end
