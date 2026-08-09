if !isdefined(@__MODULE__, :_PCM_CLUSTERED_ADAPTER_INCLUDED)
    const _PCM_CLUSTERED_ADAPTER_INCLUDED = true
    # adapter 外层已有幂等保护，直接连接模块定义文件，避免条件入口中断
    # Language Server 的静态引用链。
    include("../../../src/unit_commitment/clustered_pcm/disaggregation.jl")
    using .ClusteredDisaggregation
    using GLPK

    function pcm_cluster_key(units, i; digits = 8)
        v=(units.p_min[i], units.p_max[i], units.ramp_up[i], units.ramp_down[i], units.shut_up[i], units.shut_down[i],
            units.min_shutup_time[i], units.min_shutdown_time[i], units.coffi_a[i], units.coffi_b[i], units.coffi_c[i])
        (bus = Int(units.locatebus[i]), parameters = round.(Float64.(v); digits = digits))
    end

    """Form same-bus homogeneous clusters; heterogeneous units remain singleton clusters."""
    function build_pcm_clusters(units; digits = 8)
        grouped=Dict{Any, Vector{Int}}()
        for i ∈ eachindex(units.index)
            push!(get!(grouped, pcm_cluster_key(units, i; digits = digits), Int[]), i)
        end
        groups=sort!(collect(values(grouped)); by = first)
        [ClusterSpec(; id = g, unit_indices = idx, min_up = max(1, round(Int, units.min_shutup_time[first(idx)])),
             min_down = max(1, round(Int, units.min_shutdown_time[first(idx)]))) for (g, idx) ∈ enumerate(groups)]
    end

    function _pcm_initial_states(c, units)
        [begin
             on=units.x_0[i]>0.5
             remaining=on ? units.t_0[i] : units.t_1[i]
             minimum=on ? c.min_up : c.min_down
             InitialUnitState(; unit = i, on = on, duration = max(0, minimum-round(Int, remaining)))
         end
         for i ∈ c.unit_indices]
    end

    function _pcm_physical_units(clusters, units)
        cid=Dict(i=>c.id for c ∈ clusters for i ∈ c.unit_indices)
        [begin
             c=clusters[cid[i]]
             PhysicalUnitData(; id = i, cluster = c.id, bus = Int(units.locatebus[i]), p_min = Float64(units.p_min[i]),
                 p_max = Float64(units.p_max[i]), ramp_up = Float64(units.ramp_up[i]), ramp_down = Float64(units.ramp_down[i]),
                 startup_ramp = Float64(units.shut_up[i]), shutdown_ramp = Float64(units.shut_down[i]), initial_on = units.x_0[i]>0.5,
                 initial_duration = begin
                     on = units.x_0[i]>0.5
                     minimum = on ? c.min_up : c.min_down
                     max(0, minimum-round(Int, on ? units.t_0[i] : units.t_1[i]))
                 end, initial_power = Float64(units.p_0[i]),
                 min_up = c.min_up, min_down = c.min_down, marginal_cost = Float64(units.coffi_b[i]))
         end
         for i ∈ eachindex(units.index)]
    end

    function _pcm_fallback_paths(c, x, y, z, units)
        paths=AnonymousUnitPath[]
        for (local_id, i) ∈ enumerate(c.unit_indices)
            on0=units.x_0[i]>0.5
            minimum=on0 ? c.min_up : c.min_down
            age=max(0, minimum-round(Int, on0 ? units.t_0[i] : units.t_1[i]))
            ages=Int[]
            states=Symbol[]
            for t ∈ axes(x, 2)
                age=(y[i, t]>0||z[i, t]>0) ? 1 : age+1
                push!(ages, age)
                push!(states, x[i, t]>0 ? (age>=c.min_up ? :ON_MATURE : Symbol("ON_$(age)")) : (age>=c.min_down ? :OFF_MATURE : Symbol("OFF_$(age)")))
            end
            push!(paths,
                AnonymousUnitPath(; id = local_id, initial_on = on0, initial_duration = age,
                    u = vec(x[i, :]), y = vec(y[i, :]), z = vec(z[i, :]), age = ages, states = states))
        end
        paths
    end

    """Apply residence-flow, physical path assignment, and PTDF dispatch to a solved PCM window."""
    function apply_clustered_pcm_optimization!(results, units, loads, winds, lines, config_param, NB, NL; optimizer = GLPK.Optimizer,
            tolerance = 1e-7, strict = true, stroges = nothing, data_centers = nothing, hydros = nothing)
        x=round.(Int, results["x₀"])
        y=round.(Int, results["u₀"])
        z=round.(Int, results["v₀"])
        NG, T=size(x)
        NS=max(1, size(results["p₀"], 1)÷NG)
        clusters=build_pcm_clusters(units)
        physical=_pcm_physical_units(clusters, units)
        checks=Dict{Int, TrajectoryCheckResult}()
        maps=Dict{Int, Dict{Int, Int}}()
        operating_paths=Dict{Int, Vector{AnonymousUnitPath}}()
        residence_diagnostic=false
        for c ∈ clusters
            q=check_cluster_trajectory_feasibility(c, vec(sum(x[c.unit_indices, :]; dims = 1)), vec(sum(y[c.unit_indices, :]; dims = 1)),
                vec(sum(z[c.unit_indices, :]; dims = 1)), _pcm_initial_states(c, units))
            checks[c.id]=q
            if !q.feasible
                strict&&return (feasible = false, stage = :residence_flow, clusters = clusters, checks = checks, results = nothing, feedback = q)
                residence_diagnostic=true
                fallback=_pcm_fallback_paths(c, x, y, z, units)
                q=TrajectoryCheckResult(; feasible = true, state_flow = (fallback = true,), paths = fallback,
                    diagnostic_message = "PCM physical trajectory fallback after: $(q.diagnostic_message)", warnings = [q.diagnostic_message])
                checks[c.id]=q
            end
            # The solved PCM unit trajectories are an integral path decomposition
            # and retain the only identity mapping guaranteed to match p[i,t].
            paths=_pcm_fallback_paths(c, x, y, z, units)
            operating_paths[c.id]=paths
            maps[c.id]=Dict(paths[k].id=>c.unit_indices[k] for k ∈ eachindex(paths))
        end
        assigned=[p=>maps[c.id][p.id] for c ∈ clusters for p ∈ operating_paths[c.id]]
        disaggregated=UnitDisaggregationResult[]
        # Network constraints are deferred from the compact master to this
        # physical-unit stage, after unit identities have been recovered.
        gsdf=(config_param.is_NetWorkCon==1&&NL>0) ? calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, length(loads.locatebus)) :
             zeros(0, NB)
        limits=NL>0&&gsdf!==nothing ? min.(abs.(Float64.(lines.p_min)), abs.(Float64.(lines.p_max))) : Float64[]
        all_strictly_feasible=!residence_diagnostic
        network_feasible=true
        for scenario ∈ 1:NS
            rows=((scenario - 1) * NG + 1):(scenario * NG)
            schedules=[ClusterSchedule(; cluster = c.id, commitment = vec(sum(x[c.unit_indices, :]; dims = 1)),
                           startup = vec(sum(y[c.unit_indices, :]; dims = 1)), shutdown = vec(sum(z[c.unit_indices, :]; dims = 1)),
                           power = vec(sum(results["p₀"][first(rows) - 1 .+ c.unit_indices, :]; dims = 1)),
                           reserve = vec(sum(results["seq_sr⁺"][first(rows) - 1 .+ c.unit_indices, :]; dims = 1))) for c ∈ clusters]
            fixed=zeros(Float64, NB, T)
            ND=length(loads.locatebus)
            NW=length(winds.index)
            for t ∈ 1:T, d ∈ 1:ND

                fixed[Int(loads.locatebus[d]), t]-=loads.load_curve[d, t]-results["pᵨ"][(scenario - 1) * ND + d, t]
            end
            for t ∈ 1:T, w ∈ 1:NW

                # Match the legacy PCM network constraint, which maps wind rows
                # through `winds.index` rather than `winds.locatebus`.
                fixed[Int(winds.index[w]), t]+=winds.scenarios_curve[scenario, t]*winds.p_max[w]-results["pᵩ"][(scenario - 1) * NW + w, t]
            end
            if stroges!==nothing && haskey(results, "pss_charge_p⁺")
                NC=length(stroges.locatebus)
                for t ∈ 1:T, c ∈ 1:NC

                    fixed[Int(stroges.locatebus[c]), t]+=results["pss_charge_p⁻"][(scenario - 1) * NC + c, t]-results["pss_charge_p⁺"][(scenario - 1) * NC + c, t]
                end
            end
            if data_centers!==nothing && haskey(results, "dc_p")
                ND2=length(data_centers.locatebus)
                for t ∈ 1:T, c ∈ 1:ND2

                    fixed[Int(data_centers.locatebus[c]), t]-=results["dc_p"][(scenario - 1) * ND2 + c, t]
                end
            end
            if hydros!==nothing && haskey(results, "hydros_output")
                NH=length(hydros.locatebus)
                for t ∈ 1:T, h ∈ 1:NH

                    fixed[Int(hydros.locatebus[h]), t]+=results["hydros_output"][(scenario - 1) * NH + h, t]
                end
            end
            # Capture any remaining modeled injection at the slack bus.
            residual=-vec(sum(results["p₀"][rows, :]; dims = 1))-vec(sum(fixed; dims = 1))
            fixed[1, :].+=residual
            net=NetworkData(; buses = collect(1:NB), ptdf = gsdf===nothing ? zeros(0, NB) : Matrix{Float64}(gsdf), line_limits = limits, fixed_injection = fixed)
            original_power=Matrix{Float64}(results["p₀"][rows, :])
            buspos=Dict(bus=>i for (i, bus) ∈ enumerate(net.buses))
            direct_flow=[sum(net.ptdf[l, buspos[physical[i].bus]]*original_power[i, t] for i ∈ 1:NG) +
                         sum(net.ptdf[l, b]*fixed[b, t] for b ∈ eachindex(net.buses)) for l ∈ axes(net.ptdf, 1), t ∈ 1:T]
            direct_violation=maximum([max(0.0, abs(direct_flow[l, t])-limits[l]) for l ∈ axes(net.ptdf, 1), t ∈ 1:T]; init = 0.0)
            if direct_violation<=tolerance
                r=UnitDisaggregationResult(; feasible = true, commitment = x, startup = y, shutdown = z,
                    power = original_power, reserve = Matrix{Float64}(results["seq_sr⁺"][rows, :]),
                    line_flow = direct_flow, assignment = Dict(p.id=>id for (p, id) ∈ assigned),
                    feedback = DisaggregationFeedback(; feasible = true, message = "physical PCM trajectory and direct PTDF check feasible"))
            else
                r=solve_unit_disaggregation(schedules, assigned, physical; network_data = net, optimizer = optimizer, tolerance = tolerance)
            end
            push!(disaggregated, r)
            if !r.feasible
                all_strictly_feasible=false
                # `solve_unit_disaggregation` is called only after the direct
                # physical PTDF certificate has found an overload.
                network_feasible=false
                println("    Cluster diagnostic scenario $scenario: stage=$(r.feedback.failure_stage), periods=$(r.feedback.affected_periods), lines=$(r.feedback.affected_lines), dispatch_deviations=$(length(r.feedback.dispatch_deviation))")
                strict&&return (feasible = false, stage = r.feedback.failure_stage, clusters = clusters,
                    checks = checks, results = disaggregated, feedback = r.feedback)
            else
                results["p₀"][rows, :].=r.power
                results["seq_sr⁺"][rows, :].=r.reserve
            end
        end
        results["cluster_ids"]=Float64.([only(c.id for c ∈ clusters if i in c.unit_indices) for i ∈ 1:NG])
        results["cluster_disaggregation_feasible"]=fill(all_strictly_feasible ? 1.0 : 0.0, NS, 1)
        (feasible = true, strictly_feasible = all_strictly_feasible, network_feasible = network_feasible,
            stage = all_strictly_feasible ? :complete : :diagnostic_complete, clusters = clusters, checks = checks,
            results = disaggregated, feedback = all_strictly_feasible ? nothing : disaggregated[end].feedback)
    end
end
