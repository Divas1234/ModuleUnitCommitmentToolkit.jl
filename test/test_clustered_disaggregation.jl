using .ClusteredDisaggregation

mkunits(; pmax = (60.0, 60.0), ramp = (100.0, 100.0), buses = (1, 1)) = [PhysicalUnitData(; id = i, cluster = 1, bus = buses[i], p_min = 0.0,
                                                                             p_max = pmax[i], ramp_up = ramp[i], ramp_down = ramp[i],
                                                                             startup_ramp = pmax[i], shutdown_ramp = pmax[i],
                                                                             initial_duration = 3, min_up = 2, min_down = 2) for i ∈ 1:2]
aspairs(q, m) = [p=>m[p.id] for p ∈ q.paths]

@testset "cluster residence and network disaggregation" begin
    c=ClusterSpec(id = 1, unit_indices = [1, 2], min_up = 2, min_down = 2)
    init=[InitialUnitState(unit = i, on = false, duration = 3) for i ∈ 1:2]
    q=check_cluster_trajectory_feasibility(c, [1, 2, 2, 1], [1, 1, 0, 0], [0, 0, 0, 1], init)
    @test q.feasible
    @test !check_cluster_trajectory_feasibility(c, [1], [1], [0], [InitialUnitState(unit = i, on = false, duration = 1) for i ∈ 1:2]).feasible
    @test check_cluster_trajectory_feasibility(
        c, [1], [1], [0], [InitialUnitState(unit = 1, on = false, duration = 1), InitialUnitState(unit = 2, on = false, duration = 3)]).feasible
    stop=check_cluster_trajectory_feasibility(c, [1], [0], [1], [InitialUnitState(unit = i, on = true, duration = 1) for i ∈ 1:2])
    @test !stop.feasible&&stop.conflict_type==:minimum_up_time
    edge=check_cluster_trajectory_feasibility(ClusterSpec(id = 2, unit_indices = [1], min_up = 1, min_down = 1), [1, 0],
        [1, 0], [0, 1], [InitialUnitState(unit = 1, on = false, duration = 1)])
    @test edge.feasible
    swap=check_cluster_trajectory_feasibility(
        c, [1], [1], [1], [InitialUnitState(unit = 1, on = true, duration = 3), InitialUnitState(unit = 2, on = false, duration = 3)])
    @test swap.feasible
    paths=decompose_state_flow_to_paths(c, q, 4)
    @test [sum(p.u[t] for p ∈ paths) for t ∈ 1:4]==[1, 2, 2, 1]
    @test [sum(p.y[t] for p ∈ paths) for t ∈ 1:4]==[1, 1, 0, 0]
    @test [sum(p.z[t] for p ∈ paths) for t ∈ 1:4]==[0, 0, 0, 1]
    s=ClusterSchedule(cluster = 1, commitment = [1, 2, 2, 1], startup = [1, 1, 0, 0], shutdown = [0, 0, 0, 1], power = [40.0, 90.0, 100.0, 50.0])
    units=mkunits()
    m=assign_paths_to_physical_units(c, paths, units)
    @test m!==nothing
    r=solve_unit_disaggregation(s, aspairs(q, m), units; network_data = NetworkData(buses = [1], fixed_injection = reshape(-s.power, 1, :)))
    @test r.feasible
    @test validate_disaggregation(r, s, units).valid
    cs=ClusterSchedule(cluster = 1, commitment = [2], startup = [2], shutdown = [0], power = [130.0])
    cq=check_cluster_trajectory_feasibility(c, [2], [2], [0], init)
    cm=assign_paths_to_physical_units(c, cq.paths, units)
    cr=solve_unit_disaggregation(cs, aspairs(cq, cm), units; network_data = NetworkData(buses = [1], fixed_injection = reshape([-130.0], 1, 1)))
    @test !cr.feasible&&cr.diagnostic&&!isempty(cr.feedback.dispatch_deviation)
    slow=mkunits(ramp = (10.0, 10.0))
    rs=ClusterSchedule(cluster = 1, commitment = [2, 2, 2], startup = [2, 0, 0], shutdown = [0, 0, 0], power = [20.0, 40.0, 100.0])
    rq=check_cluster_trajectory_feasibility(c, [2, 2, 2], [2, 0, 0], [0, 0, 0], init)
    rm=assign_paths_to_physical_units(c, rq.paths, slow)
    rr=solve_unit_disaggregation(rs, aspairs(rq, rm), slow; network_data = NetworkData(buses = [1], fixed_injection = reshape(
        [
            -20.0, -40.0, -100.0], 1, 3)))
    @test !rr.feasible
    @test rr.diagnostic
    nu=mkunits(buses = (1, 2))
    ns=ClusterSchedule(cluster = 1, commitment = [2], startup = [2], shutdown = [0], power = [100.0])
    nq=check_cluster_trajectory_feasibility(c, [2], [2], [0], init)
    nm=assign_paths_to_physical_units(c, nq.paths, nu)
    net=NetworkData(buses = [1, 2], ptdf = reshape([1.0, 0.0], 1, 2), line_limits = [30.0], fixed_injection = reshape([-100.0, 0.0], 2, 1))
    nr=solve_unit_disaggregation(ns, aspairs(nq, nm), nu; network_data = net)
    @test !nr.feasible&&nr.feedback.failure_stage==:network
    @test nr.feedback.affected_lines==[1]&&nr.feedback.affected_periods==[1]
end
