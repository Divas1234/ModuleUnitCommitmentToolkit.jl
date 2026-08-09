module ClusteredDisaggregation
using JuMP, GLPK
import MathOptInterface as MOI

export ClusterSpec, InitialUnitState, PhysicalUnitData, NetworkData, ClusterSchedule, AnonymousUnitPath, TrajectoryCheckResult,
       DisaggregationFeedback, UnitDisaggregationResult, check_cluster_trajectory_feasibility, decompose_state_flow_to_paths,
       assign_paths_to_physical_units, solve_unit_disaggregation, run_cluster_disaggregation, validate_disaggregation

Base.@kwdef struct ClusterSpec
    id::Int
    unit_indices::Vector{Int}
    min_up::Int
    min_down::Int
    enforce_terminal_residence::Bool=false
end
Base.@kwdef struct InitialUnitState
    unit::Int
    on::Bool
    duration::Int
end
Base.@kwdef struct PhysicalUnitData
    id::Int
    cluster::Int
    bus::Int
    p_min::Float64
    p_max::Float64
    ramp_up::Float64=Inf
    ramp_down::Float64=Inf
    startup_ramp::Float64=Inf
    shutdown_ramp::Float64=Inf
    initial_on::Bool=false
    initial_duration::Int=0
    initial_power::Float64=0.0
    min_up::Int=1
    min_down::Int=1
    marginal_cost::Float64=0.0
    availability::Vector{Bool}=Bool[]
    must_run::Vector{Bool}=Bool[]
    must_off::Vector{Bool}=Bool[]
end
Base.@kwdef struct NetworkData
    buses::Vector{Int}
    ptdf::Matrix{Float64}=zeros(0, length(buses))
    line_limits::Vector{Float64}=Float64[]
    fixed_injection::Matrix{Float64}=zeros(length(buses), 0)
    line_names::Vector{String}=String[]
end
Base.@kwdef struct ClusterSchedule
    cluster::Int
    commitment::Vector{Int}
    startup::Vector{Int}
    shutdown::Vector{Int}
    power::Vector{Float64}
    reserve::Vector{Float64}=zeros(length(commitment))
end
Base.@kwdef struct AnonymousUnitPath
    id::Int
    initial_on::Bool
    initial_duration::Int
    u::Vector{Int}
    y::Vector{Int}
    z::Vector{Int}
    age::Vector{Int}
    states::Vector{Symbol}
end
Base.@kwdef struct TrajectoryCheckResult
    feasible::Bool
    conflict_cluster::Union{Nothing, Int}=nothing
    conflict_period::Union{Nothing, Int}=nothing
    conflict_type::Union{Nothing, Symbol}=nothing
    state_flow::Any=nothing
    paths::Vector{AnonymousUnitPath}=AnonymousUnitPath[]
    diagnostic_message::String=""
    suggested_cuts::Vector{NamedTuple}=NamedTuple[]
    warnings::Vector{String}=String[]
end
Base.@kwdef struct DisaggregationFeedback
    feasible::Bool
    failure_stage::Symbol=:none
    affected_clusters::Vector{Int}=Int[]
    affected_periods::Vector{Int}=Int[]
    affected_buses::Vector{Int}=Int[]
    affected_lines::Vector{Int}=Int[]
    commitment_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
    startup_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
    shutdown_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
    dispatch_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
    suggested_cuts::Vector{NamedTuple}=NamedTuple[]
    suggested_cluster_splits::Vector{NamedTuple}=NamedTuple[]
    message::String=""
end
Base.@kwdef struct UnitDisaggregationResult
    feasible::Bool
    diagnostic::Bool=false
    commitment::Matrix{Int}=zeros(Int, 0, 0)
    startup::Matrix{Int}=zeros(Int, 0, 0)
    shutdown::Matrix{Int}=zeros(Int, 0, 0)
    power::Matrix{Float64}=zeros(0, 0)
    reserve::Matrix{Float64}=zeros(0, 0)
    line_flow::Matrix{Float64}=zeros(0, 0)
    assignment::Dict{Int, Int}=Dict()
    feedback::DisaggregationFeedback=DisaggregationFeedback(feasible = true)
end

function _bad(c, t, k, msg, w, cuts = NamedTuple[])
    TrajectoryCheckResult(; feasible = false, conflict_cluster = c.id, conflict_period = t,
        conflict_type = k, diagnostic_message = msg, warnings = w, suggested_cuts = cuts)
end

"""
O(NT) construction of an integral flow over ON(a), ON(L+), OFF(a), OFF(D+) states.
"""
function check_cluster_trajectory_feasibility(c::ClusterSpec, U0, Y0, Z0, initial = nothing)
    U, Y, Z=Int.(U0), Int.(Y0), Int.(Z0)
    T=length(U)
    N=length(c.unit_indices)
    w=String[]
    length(Y)==T==length(Z) || throw(ArgumentError("U/Y/Z horizon mismatch"))
    min(c.min_up, c.min_down)>=1 || throw(ArgumentError("minimum times must be >= 1"))
    if initial===nothing
        push!(w, "initial residence distribution missing; inferred initial count and assumed mature states")
        n0=T==0 ? 0 : U[1]-Y[1]+Z[1]
        initial=[InitialUnitState(; unit = c.unit_indices[i], on = i<=n0, duration = i<=n0 ? c.min_up : c.min_down) for i ∈ 1:N]
    else
        initial=collect(initial)
    end
    length(initial)==N || throw(ArgumentError("one initial state per unit is required"))
    any(s->s.duration<0, initial) && throw(ArgumentError("negative initial duration"))
    on=[s.on for s ∈ initial]
    age=[s.duration for s ∈ initial]
    n0=count(on)
    u=zeros(Int, N, T)
    y=zeros(Int, N, T)
    z=zeros(Int, N, T)
    ages=zeros(Int, N, T)
    states=fill(:OFF_MATURE, N, T)
    arcs=NamedTuple[]
    for t ∈ 1:T
        prev=t==1 ? n0 : U[t - 1]
        (0<=U[t]<=N && Y[t]>=0 && Z[t]>=0) || return _bad(c, t, :count_bounds, "count outside valid bounds", w)
        U[t]==prev+Y[t]-Z[t] || return _bad(c, t, :state_balance, "U[$t] does not satisfy U[t]-U[t-1]=Y[t]-Z[t]", w)
        starts=[i for i ∈ 1:N if !on[i]&&age[i]>=c.min_down]
        stops=[i for i ∈ 1:N if on[i]&&age[i]>=c.min_up]
        length(starts)>=Y[t] || return _bad(c, t, :minimum_down_time, "insufficient mature off pool", w,
            [(type = :mature_off_pool, cluster = c.id, period = t, required = Y[t], available = length(starts))])
        length(stops)>=Z[t] || return _bad(c, t, :minimum_up_time, "insufficient mature on pool", w,
            [(type = :mature_on_pool, cluster = c.id, period = t, required = Z[t], available = length(stops))])
        ss, ds=Set(starts[1:Y[t]]), Set(stops[1:Z[t]])
        for i ∈ 1:N
            oldon, oldage=on[i], age[i]
            if i in ss
                on[i]=true
                age[i]=1
                y[i, t]=1
            elseif i in ds
                on[i]=false
                age[i]=1
                z[i, t]=1
            else
                age[i]+=1
            end
            u[i, t]=on[i]
            ages[i, t]=age[i]
            states[i, t]=on[i] ? (age[i]>=c.min_up ? :ON_MATURE : Symbol("ON_$(age[i])")) :
                         (age[i]>=c.min_down ? :OFF_MATURE : Symbol("OFF_$(age[i])"))
            from=oldon ? (oldage>=c.min_up ? :ON_MATURE : Symbol("ON_$(oldage)")) : (oldage>=c.min_down ? :OFF_MATURE : Symbol("OFF_$(oldage)"))
            push!(arcs, (period = t, unit = i, from = from, to = states[i, t], flow = 1.0, startup = y[i, t], shutdown = z[i, t]))
        end
    end
    if c.enforce_terminal_residence && T>0
        any(i->age[i]<(on[i] ? c.min_up : c.min_down), 1:N) && return _bad(c, T, :terminal_residence, "unfinished terminal residence", w)
    end
    paths=[AnonymousUnitPath(; id = i, initial_on = initial[i].on, initial_duration = initial[i].duration, u = vec(u[i, :]),
               y = vec(y[i, :]), z = vec(z[i, :]), age = vec(ages[i, :]), states = vec(states[i, :])) for i ∈ 1:N]
    counts=Dict{Tuple{Int, Symbol}, Float64}()
    for t ∈ 1:T, i ∈ 1:N

        counts[(t, states[i, t])]=get(counts, (t, states[i, t]), 0.0)+1
    end
    TrajectoryCheckResult(; feasible = true, state_flow = (arcs = arcs, state_counts = counts, target = (U = U, Y = Y, Z = Z), initial = initial),
        paths = paths, diagnostic_message = "integral state flow found", warnings = w)
end

decompose_state_flow_to_paths(::ClusterSpec, r::TrajectoryCheckResult, h::Integer) = r.feasible && (isempty(r.paths)||length(r.paths[1].u)==h) ?
                                                                                     r.paths : throw(ArgumentError(r.diagnostic_message))

_flag(v, t, d) = isempty(v) ? d : v[t]
function _compatible(p, u)
    p.initial_on==u.initial_on || return false
    p.initial_duration<=u.initial_duration || return false
    for t ∈ eachindex(p.u)
        (!_flag(u.availability, t, true)&&p.u[t]==1) && return false
        (_flag(u.must_run, t, false)&&p.u[t]==0) && return false
        (_flag(u.must_off, t, false)&&p.u[t]==1) && return false
    end
    true
end

"""
Deterministic maximum bipartite matching; returns path-id => physical-unit-id.
"""
function assign_paths_to_physical_units(c::ClusterSpec, paths, data, network = nothing)
    units=[data[i] for i ∈ c.unit_indices]
    length(units)==length(paths)||throw(ArgumentError("path/unit count mismatch"))
    match=Dict{Int, Int}()
    function aug(pi, seen)
        for j ∈ sortperm(units; by = u->(u.bus, u.marginal_cost, u.id))
            (j in seen||!_compatible(paths[pi], units[j]))&&continue
            push!(seen, j)
            old=get(match, j, 0)
            if old==0||aug(old, seen)
                match[j]=pi
                return true
            end
        end
        false
    end
    all(aug(i, Set{Int}()) for i ∈ eachindex(paths)) || return nothing
    Dict(paths[pi].id=>units[j].id for (j, pi) ∈ match)
end

function _dispatch(schedules, pathpairs, units, net, diag, optimizer)
    I, T, C=length(units), length(first(schedules).power), length(schedules)
    pos=Dict(u.id=>i for (i, u) ∈ enumerate(units))
    bpos=Dict(b=>i for (i, b) ∈ enumerate(net.buses))
    U=zeros(Int, I, T)
    Y=similar(U)
    Z=similar(U)
    for (p, id) ∈ pathpairs
        i       = pos[id]
        U[i, :] .= p.u
        Y[i, :] .= p.y
        Z[i, :] .= p.z
    end
    m=Model(optimizer)
    set_silent(m)
    @variable(m, p[1:I, 1:T]>=0)
    @variable(m, r[1:I, 1:T]>=0)
    @variable(m, bp[1:T]>=0)
    @variable(m, bm[1:T]>=0)
    L=size(net.ptdf, 1)
    @variable(m, lp[1:L, 1:T]>=0)
    @variable(m, lm[1:L, 1:T]>=0)
    if diag
        @variable(m, dp[1:C, 1:T]>=0)
        @variable(m, dm[1:C, 1:T]>=0)
    end
    for i ∈ 1:I, t ∈ 1:T

        @constraint(m, p[i, t]>=units[i].p_min*U[i, t])
        @constraint(m, p[i, t]+r[i, t]<=units[i].p_max*U[i, t])
        prev=t==1 ? units[i].initial_power : p[i, t - 1]
        pu=t==1 ? Int(units[i].initial_on) : U[i, t - 1]
        @constraint(m, p[i, t]-prev<=units[i].ramp_up*pu+units[i].startup_ramp*Y[i, t]+units[i].p_max*(1-pu))
        @constraint(m, prev-p[i, t]<=units[i].ramp_down*U[i, t]+units[i].shutdown_ramp*Z[i, t]+units[i].p_max*(1-U[i, t]))
    end
    for (c, s) ∈ enumerate(schedules), t ∈ 1:T

        idx=findall(u->u.cluster==s.cluster, units)
        diag ? @constraint(m, sum(p[i, t] for i ∈ idx)==s.power[t]+dp[c, t]-dm[c, t]) : @constraint(m, sum(p[i, t] for i ∈ idx)==s.power[t])
        @constraint(m, sum(r[i, t] for i ∈ idx)>=s.reserve[t])
    end
    fixed=size(net.fixed_injection, 2)==0 ? zeros(length(net.buses), T) : net.fixed_injection
    size(fixed)==(length(net.buses), T)||throw(ArgumentError("fixed_injection dimensions"))
    flows=Matrix{AffExpr}(undef, L, T)
    for t ∈ 1:T
        @constraint(m, sum(p[:, t])+sum(fixed[:, t])+bp[t]-bm[t]==0)
        for l ∈ 1:L
            flows[l, t]=@expression(m,
                sum(net.ptdf[l, bpos[units[i].bus]]*p[i, t] for i ∈ 1:I)+sum(net.ptdf[l, b]*fixed[b, t] for b ∈ eachindex(net.buses)))
            @constraint(m, flows[l, t]<=net.line_limits[l]+lp[l, t])
            @constraint(m, -flows[l, t]<=net.line_limits[l]+lm[l, t])
        end
    end
    mapdev=diag ? sum(dp)+sum(dm) : 0
    @objective(m, Min, 1e12*(sum(bp)+sum(bm))+1e9*(sum(lp)+sum(lm))+1e6*mapdev+sum(units[i].marginal_cost*p[i, t] for i ∈ 1:I, t ∈ 1:T))
    optimize!(m)
    termination_status(m) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) || return nothing
    (U = U, Y = Y, Z = Z, p = value.(p), r = value.(r), flow = value.(flows), balance = value.(bp) .+ value.(bm),
        line = value.(lp) .+ value.(lm), dev = diag ? value.(dp) .- value.(dm) : zeros(C, T))
end

function solve_unit_disaggregation(sol, assigned, data, bus = nothing, line = nothing, load = nothing, ptdf = nothing;
        network_data = nothing, optimizer = GLPK.Optimizer, tolerance = 1e-7)
    schedules=sol isa ClusterSchedule ? [sol] : collect(sol)
    units=collect(data)
    net=network_data===nothing ?
        NetworkData(; buses = collect(bus), ptdf = Matrix(ptdf), line_limits = Float64.(line), fixed_injection = -Matrix(load)) : network_data
    pairs=Dict{AnonymousUnitPath, Int}()
    for x ∈ assigned
        x isa Pair ? pairs[x.first]=x.second : pairs[x.path]=x.unit
    end
    a=_dispatch(schedules, pairs, units, net, false, optimizer)
    diagnostic=a===nothing||maximum(a.balance; init = 0.0)>tolerance||maximum(a.line; init = 0.0)>tolerance
    diagnostic&&(a=_dispatch(schedules, pairs, units, net, true, optimizer))
    a===nothing&&return UnitDisaggregationResult(; feasible = false, diagnostic = true,
        feedback = DisaggregationFeedback(; feasible = false, failure_stage = :solver, message = "solver failed"))
    lines=unique([l for l ∈ axes(a.line, 1), t ∈ axes(a.line, 2) if a.line[l, t]>tolerance])
    periods=unique(vcat(
        [t for t ∈ eachindex(a.balance) if a.balance[t]>tolerance], [t for l ∈ axes(a.line, 1), t ∈ axes(a.line, 2) if a.line[l, t]>tolerance],
        [t for c ∈ axes(a.dev, 1), t ∈ axes(a.dev, 2) if abs(a.dev[c, t])>tolerance]))
    dev=Dict((schedules[c].cluster, t)=>a.dev[c, t] for c ∈ axes(a.dev, 1), t ∈ axes(a.dev, 2) if abs(a.dev[c, t])>tolerance)
    # A diagnostic redispatch may change cluster-level P while preserving the
    # already accepted U/Y/Z paths.  This is a valid network-constrained physical
    # disaggregation whenever the hard balance and line slacks are zero.
    feasible=maximum(a.balance; init = 0.0)<=tolerance&&maximum(a.line; init = 0.0)<=tolerance
    capacity_conflict=false
    for schedule ∈ schedules
        cluster_units=findall(unit->unit.cluster==schedule.cluster, units)
        for t ∈ eachindex(schedule.power)
            capacity_conflict |= schedule.power[t]>sum(units[i].p_max*a.U[i, t] for i ∈ cluster_units)+tolerance
        end
    end
    stage=!isempty(lines) ? :network :
          !isempty(dev) ? (feasible ? :physical_redispatch : (capacity_conflict ? :capacity : :ramp)) :
          maximum(a.balance; init = 0.0)>tolerance ? :balance : :none
    bpos=Dict(b=>i for (i, b) ∈ enumerate(net.buses))
    buses=unique(units[i].bus for i ∈ eachindex(units) if any(l->l<=size(net.ptdf, 1)&&abs(net.ptdf[l, bpos[units[i].bus]])>tolerance, lines))
    fb=DisaggregationFeedback(; feasible = feasible,
        failure_stage = stage,
        affected_clusters = unique(first.(keys(dev))),
        affected_periods = periods,
        affected_buses = collect(buses),
        affected_lines = lines,
        dispatch_deviation = dev,
        suggested_cluster_splits = [(cluster = c, reason = :heterogeneous_dispatch) for c ∈ unique(first.(keys(dev)))],
        message = feasible ? (isempty(dev) ? "strict disaggregation feasible" : "network-constrained physical redispatch feasible") :
                  "diagnostic relaxation identified $stage")
    UnitDisaggregationResult(; feasible = feasible, diagnostic = diagnostic, commitment = a.U, startup = a.Y, shutdown = a.Z, power = a.p,
        reserve = a.r, line_flow = a.flow, assignment = Dict(p.id=>id for (p, id) ∈ pairs), feedback = fb)
end

function validate_disaggregation(r, schedules, units; tolerance = 1e-7)
    schedules=schedules isa ClusterSchedule ? [schedules] : schedules
    e=Dict(:commitment=>0.0, :startup=>0.0, :shutdown=>0.0, :power=>0.0, :line=>0.0)
    for s ∈ schedules, t ∈ eachindex(s.commitment)

        idx=findall(u->u.cluster==s.cluster, units)
        e[:commitment]=max(e[:commitment], abs(sum(r.commitment[idx, t])-s.commitment[t]))
        e[:startup]=max(e[:startup], abs(sum(r.startup[idx, t])-s.startup[t]))
        e[:shutdown]=max(e[:shutdown], abs(sum(r.shutdown[idx, t])-s.shutdown[t]))
        e[:power]=max(e[:power], abs(sum(r.power[idx, t])-s.power[t]))
    end
    (valid = e[:commitment]==0&&e[:startup]==0&&e[:shutdown]==0&&e[:power]<=tolerance, errors = e)
end

function run_cluster_disaggregation(clusters, schedules, initial, units, network; optimizer = GLPK.Optimizer, tolerance = 1e-7, max_iterations = 1)
    checks=Dict{Int, TrajectoryCheckResult}()
    assigned=Pair{AnonymousUnitPath, Int}[]
    for c ∈ clusters
        s=only(filter(x->x.cluster==c.id, schedules))
        q=check_cluster_trajectory_feasibility(c, s.commitment, s.startup, s.shutdown, get(initial, c.id, nothing))
        checks[c.id]=q
        q.feasible||return (feasible = false,
            checks = checks,
            result = nothing,
            feedback = DisaggregationFeedback(; feasible = false, failure_stage = :residence_flow, affected_clusters = [c.id],
                affected_periods = [q.conflict_period], suggested_cuts = q.suggested_cuts, message = q.diagnostic_message))
        m=assign_paths_to_physical_units(c, q.paths, units, network)
        m===nothing&&return (feasible = false,
            checks = checks,
            result = nothing,
            feedback = DisaggregationFeedback(; feasible = false, failure_stage = :physical_assignment, affected_clusters = [c.id],
                suggested_cluster_splits = [(cluster = c.id, reason = :incompatible_units)], message = "path assignment infeasible"))
        append!(assigned, [p=>m[p.id] for p ∈ q.paths])
    end
    r=solve_unit_disaggregation(schedules, assigned, units; network_data = network, optimizer = optimizer, tolerance = tolerance)
    (feasible = r.feasible, checks = checks, result = r, feedback = r.feedback)
end
end
