@testset "true clustered PCM similarity grouping" begin
    units = (index = collect(1:5), locatebus = [1, 1, 1, 2, 1], p_min = [20.0, 20.0, 55.0, 20.0, 20.0], p_max = [100.0, 100.0, 100.0, 100.0, 100.0],
        ramp_up = [40.0, 40.0, 40.0, 40.0, 10.0], ramp_down = [40.0, 40.0, 40.0, 40.0, 10.0], min_shutup_time = [2.0, 2.0, 2.0, 2.0, 2.0],
        min_shutdown_time = [2.0, 2.0, 2.0, 2.0, 2.0], shut_up = fill(100.0, 5), shut_down = fill(100.0, 5),
        coffi_a = fill(0.01, 5), coffi_b = fill(10.0, 5), coffi_c = fill(1.0, 5), x_0 = zeros(5), p_0 = zeros(5))

    clusters = build_similar_pcm_clusters(units; require_same_bus = true)
    memberships = [sort(c.unit_indices) for c ∈ clusters]

    @test [1, 2] in memberships
    @test [3] in memberships       # different minimum-output characteristic
    @test [4] in memberships       # different network location
    @test [5] in memberships       # different normalized ramp characteristic
    @test sum(length, memberships) == length(units.index)

    copperplate = build_similar_pcm_clusters(units)
    copperplate_memberships = [sort(c.unit_indices) for c ∈ copperplate]
    @test [1, 2, 4] in copperplate_memberships # network-free PCM may cluster identical cross-bus units
end
