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

    @test _clustered_pcm_up_ramp_limit(2, 0, 10.0, 30.0) == 20.0
    @test _clustered_pcm_up_ramp_limit(0, 2, 10.0, 30.0) == 60.0
    @test _clustered_pcm_down_ramp_limit(2, 0, 10.0, 30.0) == 20.0
    @test _clustered_pcm_down_ramp_limit(0, 2, 10.0, 30.0) == 60.0
end

@testset "clustered residence-output product hull" begin
    m=Model(GLPK.Optimizer)
    c=ClusterSpec(id=1,unit_indices=[1,2],min_up=2,min_down=2)
    units=(p_min=[10.0,10.0],p_max=[50.0,50.0],ramp_up=[20.0,20.0],
        ramp_down=[20.0,20.0],shut_up=[30.0,30.0],shut_down=[30.0,30.0],
        x_0=[1.0,0.0],t_0=[3.0,0.0],t_1=[0.0,3.0],p_0=[30.0,0.0])
    @variable(m,0<=U[1:1,1:3]<=2,Int); @variable(m,0<=Y[1:1,1:3]<=2,Int)
    @variable(m,0<=Z[1:1,1:3]<=2,Int); @variable(m,P[1:1,1:3]>=0)
    add_cluster_residence_output_product_hull!(m,[c],units,3,U,Y,Z,P; bins=5)
    @constraint(m,U[1,:].==[1,2,1]); @constraint(m,Y[1,:].==[0,1,0])
    @constraint(m,Z[1,:].==[0,0,1]); @objective(m,Min,sum(P))
    optimize!(m)
    @test termination_status(m)==MOI.OPTIMAL
    @test value.(P)[1,1]>=10.0
end

@testset "clustered residence-output extended hull" begin
    m = Model(GLPK.Optimizer)
    c = ClusterSpec(id=1, unit_indices=[1, 2], min_up=2, min_down=2)
    units = (p_min=[10.0, 10.0], p_max=[50.0, 50.0], ramp_up=[20.0, 20.0],
        ramp_down=[20.0, 20.0], shut_up=[30.0, 30.0], shut_down=[30.0, 30.0],
        x_0=[1.0, 0.0], t_0=[3.0, 0.0], t_1=[0.0, 3.0], p_0=[30.0, 0.0])
    @variable(m, 0<=U[1:1, 1:3]<=2, Int)
    @variable(m, 0<=Y[1:1, 1:3]<=2, Int)
    @variable(m, 0<=Z[1:1, 1:3]<=2, Int)
    @variable(m, P[1:1, 1:3]>=0)
    add_cluster_residence_power_flow_hull!(m, [c], units, 3, U, Y, Z, P)
    withenv("PCM_CLUSTER_OUTPUT_BINS"=>"5") do
        add_cluster_output_state_flow_hull!(m, [c], units, 3, U, Y, Z, P)
    end
    @constraint(m, U[1, :].==[1, 2, 1])
    @constraint(m, Y[1, :].==[0, 1, 0])
    @constraint(m, Z[1, :].==[0, 0, 1])
    @objective(m, Min, sum(P))
    optimize!(m)
    @test termination_status(m)==MOI.OPTIMAL
    @test round.(Int, value.(U))==reshape([1, 2, 1], 1, :)
end

@testset "residence certificate prioritizes mature cohorts" begin
    c = ClusterSpec(id = 1, unit_indices = [1, 2, 3], min_up = 3, min_down = 2)
    initial = [
        InitialUnitState(unit = 1, on = false, duration = 2),
        InitialUnitState(unit = 2, on = false, duration = 6),
        InitialUnitState(unit = 3, on = true, duration = 5),
    ]
    q = check_cluster_trajectory_feasibility(c, [2, 2, 1], [1, 0, 0], [0, 0, 1], initial)
    @test q.feasible
    # The oldest offline cohort is started first, preserving more future freedom.
    @test q.paths[2].y[1] == 1
    @test q.paths[1].y[1] == 0
end
