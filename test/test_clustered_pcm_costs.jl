using Test

if !isdefined(@__MODULE__, :check_var_exists)
    include("../src/unitcommitment_model_modules/tests_lib/_check_variable_exit.jl")
end

@testset "clustered PCM initial state and cost parity" begin
    variable_probe = Model()
    @variable(variable_probe, ph_probe[1:1] >= 0)
    @test check_var_exists(variable_probe, "ph_probe")
    @test !check_var_exists(variable_probe, "missing_probe")

    units = (index = [1, 2], locatebus = [1, 1], p_min = [10.0, 10.0], p_max = [50.0, 50.0],
        ramp_up = [20.0, 20.0], ramp_down = [20.0, 20.0], shut_up = [30.0, 30.0], shut_down = [30.0, 30.0],
        min_shutup_time = [4.0, 4.0], min_shutdown_time = [3.0, 3.0], x_0 = [1.0, 0.0],
        t_0 = [1.0, 0.0], t_1 = [0.0, 2.0], p_0 = [20.0, 0.0],
        coffi_a = [0.1, 0.1], coffi_b = [10.0, 10.0], coffi_c = [2.0, 2.0],
        coffi_cold_shutup_1 = [100.0, 100.0], coffi_cold_shutdown_1 = [20.0, 20.0],
        coffi_cold_shutup_2 = [0.0, 0.0], coffi_cold_shutdown_2 = [0.0, 0.0])
    clusters = [ClusterSpec(id = 1, unit_indices = [1, 2], min_up = 4, min_down = 3)]

    initial = _pcm_initial_states(clusters[1], units)
    @test [state.duration for state in initial] == [3, 1]

    coeffs = clustered_pcm_cost_coefficients(units, clusters)
    @test coeffs.startup == [100.0]
    @test coeffs.shutdown == [20.0]
    @test coeffs.refcost[1] ≈ 0.1 * 10.0^2 + 10.0 * 10.0 + 2.0

    config = (is_CoalPrice = 1, is_LoadsCuttingCoefficient = 100_000.0, is_WindsCuttingCoefficient = 100_000.0)
    clustered_cost = clustered_pcm_economic_cost(config, coeffs, [2.0], [1.0], [0.0], reshape([10.0, 0.0, 0.0], 1, 1, 3), [5.0], [3.0], [0.0], [0.0])
    physical_cost = physical_pcm_economic_cost(config, units, reshape([1.0, 1.0], 2, 1), reshape([1.0, 0.0], 2, 1), zeros(2, 1), reshape([15.0, 15.0], 2, 1), reshape([2.5, 2.5], 2, 1), reshape([1.5, 1.5], 2, 1), [0.0], [0.0])
    @test clustered_cost[1, 1:5] ≈ physical_cost[1, 1:5]
end
