if !isdefined(@__MODULE__, :_TRUE_CLUSTERED_PCM_MASTER_INCLUDED)
    const _TRUE_CLUSTERED_PCM_MASTER_INCLUDED=true
    include("adapter.jl")
    using JuMP
    using Statistics
    import MathOptInterface as MOI

    _clustered_pcm_up_ramp_limit(previous_online, startups, ramp_up, startup_ramp) =
        ramp_up * previous_online + startup_ramp * startups
    _clustered_pcm_down_ramp_limit(current_online, shutdowns, ramp_down, shutdown_ramp) =
        ramp_down * current_online + shutdown_ramp * shutdowns

    """
    建立运行特性可互换的火电机组等价类。

    默认容差有意设置得很严格。仅归一化比例相似并不能保持 UC 可行域；
    绝对容量、启停爬坡、成本或初始开停状态不同，都不应直接聚合；窗口边界的
    剩余驻留时间不扩展主问题，而在求解后通过单机解群可行性校核。
    无网络约束时允许跨母线聚类；网络约束启用时必须保持同母线注入。
    """
    function build_similar_pcm_clusters(units; ratio_tol = 1e-6, ramp_tol = 1e-6, cost_tol = 1e-6, require_same_bus::Bool = false)
        groups=Vector{Vector{Int}}()
        startup_cost(i) = hasproperty(units, :coffi_cold_shutup_1) ? units.coffi_cold_shutup_1[i] : 0.0
        shutdown_cost(i) = hasproperty(units, :coffi_cold_shutdown_1) ? units.coffi_cold_shutdown_1[i] : 0.0
        feature(i) = (units.p_min[i]/max(units.p_max[i], eps()), units.ramp_up[i]/max(units.p_max[i], eps()),
            units.ramp_down[i]/max(units.p_max[i], eps()), units.coffi_a[i], units.coffi_b[i], units.coffi_c[i],
            startup_cost(i), shutdown_cost(i))
        for i ∈ eachindex(units.index)
            placed=false
            fi=feature(i)
            for g ∈ groups
                j=first(g)
                fj=feature(j)
                scale(x, y) = max(1.0, abs(x), abs(y))
                close(x, y, tol) = abs(x-y)<=tol*scale(x, y)
                compatible=(!require_same_bus || units.locatebus[i]==units.locatebus[j]) &&
                           round(Int, units.min_shutup_time[i])==round(Int, units.min_shutup_time[j]) &&
                           round(Int, units.min_shutdown_time[i])==round(Int, units.min_shutdown_time[j]) &&
                           abs(fi[1]-fj[1])<=ratio_tol &&
                           max(abs(fi[2]-fj[2]), abs(fi[3]-fj[3]))<=ramp_tol &&
                           all(abs(fi[k]-fj[k])<=cost_tol*max(1.0, abs(fj[k])) for k ∈ 4:length(fi)) &&
                           close(units.p_min[i], units.p_min[j], ratio_tol) &&
                           close(units.p_max[i], units.p_max[j], ratio_tol) &&
                           close(units.ramp_up[i], units.ramp_up[j], ramp_tol) &&
                           close(units.ramp_down[i], units.ramp_down[j], ramp_tol) &&
                           close(units.shut_up[i], units.shut_up[j], ramp_tol) &&
                           close(units.shut_down[i], units.shut_down[j], ramp_tol) &&
                           close(units.coffi_a[i], units.coffi_a[j], cost_tol) &&
                           close(units.coffi_c[i], units.coffi_c[j], cost_tol) &&
                           units.x_0[i]==units.x_0[j] &&
                           close(units.p_0[i], units.p_0[j], ratio_tol)
                compatible&&(push!(g, i); placed = true; break)
            end
            placed||push!(groups, [i])
        end
        [ClusterSpec(; id = k, unit_indices = g, min_up = max(1, maximum(round.(Int, units.min_shutup_time[g]))),
             min_down = max(1, maximum(round.(Int, units.min_shutdown_time[g])))) for (k, g) ∈ enumerate(groups)]
    end

    function solve_true_clustered_pcm_window(NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH; optimizer = Gurobi.Optimizer,
            tolerance = 1e-5, feedback_lines = Int[], iteration = 1, max_iterations = 6)
        # The clustered master is copper-plate by default. Bus identity is only
        # part of homogeneity when network constraints are actually represented.
        clusters=build_similar_pcm_clusters(units; require_same_bus = config_param.is_NetWorkCon == 1)
        C=length(clusters)
        clustered_units=sum(length(c.unit_indices) for c ∈ clusters if length(c.unit_indices)>1)
        println("  Clustered PCM: $NG physical units -> $C equivalent units " *
                "($(round(100 * (NG - C) / max(NG, 1); digits = 1))% state reduction; $clustered_units units in non-singleton clusters)")
        NW=length(winds.index)
        NS=winds.scenarios_nums
        NS==1||return (feasible = false, stage = :unsupported_scenarios, message = "true clustered master currently requires one PCM scenario")
        n=[length(c.unit_indices) for c ∈ clusters]
        coeffs=clustered_pcm_cost_coefficients(units, clusters)
        pmin=coeffs.pmin
        pmax=coeffs.pmax
        ru=[minimum(units.ramp_up[c.unit_indices]) for c ∈ clusters]
        rd=[minimum(units.ramp_down[c.unit_indices]) for c ∈ clusters]
        sr=[minimum(units.shut_up[c.unit_indices]) for c ∈ clusters]
        dr=[minimum(units.shut_down[c.unit_indices]) for c ∈ clusters]
        block=(pmax .- pmin) ./ 3
        refcost=coeffs.refcost
        slopes=coeffs.eachslope
        suc=coeffs.startup
        sdc=coeffs.shutdown
        U0=[count(i->units.x_0[i]>0.5, c.unit_indices) for c ∈ clusters]
        m=Model(optimizer)
        set_silent(m)
        pcm_solver_name() == "gurobi" && set_optimizer_attribute(m, "MIPGap", 0.015)
        # Integer counts replace per-unit binaries. For a cluster of n identical
        # units, U/Y/Z record how many are online/starting/stopping at each hour.
        @variable(m, 0<=U[g = 1:C, t = 1:NT]<=n[g], Int)
        @variable(m, 0<=Y[g = 1:C, t = 1:NT]<=n[g], Int)
        @variable(m, 0<=Z[g = 1:C, t = 1:NT]<=n[g], Int)
        @variable(m, P[1:C, 1:NT]>=0)
        @variable(m, R[1:C, 1:NT]>=0)
        @variable(m, Rdown[1:C, 1:NT]>=0)
        @variable(m, Q[1:C, 1:NT, 1:3]>=0)
        @variable(m, ls[1:ND, 1:NT]>=0)
        @variable(m, wc[1:NW, 1:NT]>=0)
        @variable(m, H[1:NH, 1:NT]>=0)
        for g ∈ 1:C, t ∈ 1:NT

            prev=t==1 ? U0[g] : U[g, t - 1]
            @constraint(m, U[g, t]-prev==Y[g, t]-Z[g, t])
            @constraint(m, Y[g, t]+Z[g, t]<=n[g])
            @constraint(m, P[g, t]==pmin[g]*U[g, t]+sum(Q[g, t, k] for k ∈ 1:3))
            for k ∈ 1:3
                @constraint(m, Q[g, t, k]<=block[g]*U[g, t])
            end
            @constraint(m, P[g, t]+R[g, t]<=pmax[g]*U[g, t])
            @constraint(m, P[g, t]-Rdown[g, t]>=pmin[g]*U[g, t])
            @constraint(m, P[g, t]-(t==1 ? sum(units.p_0[clusters[g].unit_indices]) : P[g, t - 1])<=
                _clustered_pcm_up_ramp_limit(prev, Y[g, t], ru[g], sr[g]))
            @constraint(m, (t==1 ? sum(units.p_0[clusters[g].unit_indices]) : P[g, t - 1])-P[g, t]<=
                _clustered_pcm_down_ramp_limit(U[g, t], Z[g, t], rd[g], dr[g]))
            L=clusters[g].min_up
            D=clusters[g].min_down
            @constraint(m, sum(Y[g, k] for k ∈ max(1, t - L + 1):t)<=U[g, t])
            @constraint(m, sum(Z[g, k] for k ∈ max(1, t - D + 1):t)<=n[g]-U[g, t])
        end
        for d ∈ 1:ND, t ∈ 1:NT

            @constraint(m, ls[d, t]==0)
        end
        for w ∈ 1:NW, t ∈ 1:NT

            @constraint(m, wc[w, t]<=winds.scenarios_curve[1, t]*winds.p_max[w])
        end
        for h ∈ 1:NH, t ∈ 1:NT

            @constraint(m, hydros.p_min[h]<=H[h, t])
            @constraint(m, H[h, t]<=hydros.p_max[h])
            @constraint(m, H[h, t]<=hydros.reservoircurve[t, 1])
        end
        for h ∈ 1:NH
            @constraint(m, hydros.q_0[h]+sum(hydros.reservoircurve[t, 1]-H[h, t] for t ∈ 1:NT)<=hydros.q_max[h])
        end
        for t ∈ 1:NT
            demand=sum(loads.load_curve[:, t])
            wind=sum(winds.scenarios_curve[1, t]*winds.p_max[w] for w ∈ 1:NW)
            @constraint(m, sum(P[:, t])+sum(H[:, t])+wind-sum(wc[:, t])+sum(ls[:, t])==demand)
            hydro_up=sum(min(hydros.p_max[h], hydros.reservoircurve[t, 1])-H[h, t] for h ∈ 1:NH)
            for g ∈ 1:C
                @constraint(m, sum(R[:, t])+hydro_up>=0.5*pmax[g]*U[g, t]/n[g])
            end
            forecast_reserve=winds.scenarios_curve[1, t]*sum(winds.p_max)*0.05
            @constraint(m,
                sum(Rdown[:, t])+sum(H[h, t]-hydros.p_min[h] for h ∈ 1:NH)>=config_param.is_Alpha*forecast_reserve+config_param.is_Belta*demand)
        end
        gsdf_master=config_param.is_NetWorkCon==1 ? calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND) : nothing
        if gsdf_master!==nothing
            network_margin=max(10*tolerance, 1e-4)
            for l ∈ unique(feedback_lines), t ∈ 1:NT

                flow=@expression(m,
                    sum(gsdf_master[l, units.locatebus[first(clusters[g].unit_indices)]]*P[g, t] for g ∈ 1:C) +
                    sum(gsdf_master[l, hydros.locatebus[h]]*H[h, t] for h ∈ 1:NH) +
                    sum(gsdf_master[l, winds.index[w]]*(winds.scenarios_curve[1, t]*winds.p_max[w]-wc[w, t]) for w ∈ 1:NW) -
                    sum(gsdf_master[l, loads.locatebus[d]]*(loads.load_curve[d, t]-ls[d, t]) for d ∈ 1:ND))
                @constraint(m, lines.p_min[l]+network_margin<=flow)
                @constraint(m, flow<=lines.p_max[l]-network_margin)
            end
        end
        @objective(m, Min, clustered_pcm_economic_expression(config_param, coeffs, U, Y, Z, Q, R, Rdown, ls, wc;
            scenarios_prob = 1.0))
        optimize!(m)
        termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)||return (
            feasible = false, stage = :cluster_master, message = string(termination_status(m)))
        Ui=round.(Int, JuMP.value.(U))
        Yi=round.(Int, JuMP.value.(Y))
        Zi=round.(Int, JuMP.value.(Z))
        Pv=JuMP.value.(P)
        Rv=JuMP.value.(R)
        # Aggregate minimum-time inequalities are not a physical certificate by
        # themselves. The residence-flow checker must construct one legal integral
        # path for every physical unit before dispatch disaggregation is attempted.
        checks=Dict{Int, TrajectoryCheckResult}()
        paths=AnonymousUnitPath[]
        mapping=Dict{Int, Int}()
        physical=_pcm_physical_units(clusters, units)
        for c ∈ clusters
            q=check_cluster_trajectory_feasibility(c, vec(Ui[c.id, :]), vec(Yi[c.id, :]), vec(Zi[c.id, :]), _pcm_initial_states(c, units))
            checks[c.id]=q
            q.feasible||return (feasible = false, stage = :residence_flow, message = q.diagnostic_message, checks = checks)
            mp=assign_paths_to_physical_units(c, q.paths, physical)
            mp===nothing&&return (feasible = false, stage = :assignment, message = "physical assignment failed")
            append!(paths, q.paths)
            merge!(mapping, Dict((c.id*10000+p.id)=>u for (p, u) ∈ [(p, mp[p.id]) for p ∈ q.paths]))
        end
        assigned=Pair{AnonymousUnitPath, Int}[]
        for c ∈ clusters, p ∈ checks[c.id].paths

            global_path=AnonymousUnitPath(; id = c.id*10000+p.id, initial_on = p.initial_on, initial_duration = p.initial_duration,
                u = p.u, y = p.y, z = p.z, age = p.age, states = p.states)
            push!(assigned, global_path=>only(u for (key, u) ∈ mapping if key==c.id*10000+p.id))
        end
        schedules=[ClusterSchedule(; cluster = g, commitment = vec(Ui[g, :]), startup = vec(Yi[g, :]),
                       shutdown = vec(Zi[g, :]), power = vec(Pv[g, :]), reserve = vec(Rv[g, :])) for g ∈ 1:C]
        fixedinj=zeros(NB, NT)
        for d ∈ 1:ND, t ∈ 1:NT

            fixedinj[loads.locatebus[d], t]-=loads.load_curve[d, t]-value(ls[d, t])
        end
        for w ∈ 1:NW, t ∈ 1:NT

            fixedinj[winds.index[w], t]+=winds.scenarios_curve[1, t]*winds.p_max[w]-value(wc[w, t])
        end
        for h ∈ 1:NH, t ∈ 1:NT

            fixedinj[hydros.locatebus[h], t]+=value(H[h, t])
        end
        gsdf=gsdf_master===nothing ? zeros(0, NB) : gsdf_master
        net=NetworkData(; buses = collect(1:NB), ptdf = gsdf===nothing ? zeros(0, NB) : Matrix(gsdf),
            line_limits = min.(abs.(lines.p_min), abs.(lines.p_max)), fixed_injection = fixedinj)
        # The master deliberately starts without the complete network. Here the
        # certified paths are dispatched on the physical PTDF network. Conflicting
        # lines are returned to the master as a small feedback set.
        dis=solve_unit_disaggregation(schedules, assigned, physical; network_data = net, optimizer = optimizer, tolerance = tolerance)
        if !dis.feasible
            new_lines=unique(vcat(feedback_lines, dis.feedback.affected_lines))
            if dis.feedback.failure_stage==:network && iteration<max_iterations && length(new_lines)>length(feedback_lines)
                println("    Cluster feedback iteration $iteration: adding line cuts $(setdiff(new_lines,feedback_lines))")
                return solve_true_clustered_pcm_window(
                    NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH; optimizer = optimizer,
                    tolerance = tolerance, feedback_lines = new_lines, iteration = iteration+1, max_iterations = max_iterations)
            end
            return (feasible = false,
                stage = :network_disaggregation,
                message = "$(dis.feedback.message); lines=$(dis.feedback.affected_lines), periods=$(dis.feedback.affected_periods), deviations=$(length(dis.feedback.dispatch_deviation))",
                feedback = dis.feedback,
                cluster_solution = schedules)
        end
        x=Float64.(dis.commitment)
        y=Float64.(dis.startup)
        z=Float64.(dis.shutdown)
        p=dis.power
        r=dis.reserve
        pk=zeros(NG, NT, 3)
        for i ∈ 1:NG, t ∈ 1:NT

            rem=max(0.0, p[i, t]-units.p_min[i]*x[i, t])
            block=(units.p_max[i]-units.p_min[i])/3
            for k ∈ 1:3
                pk[i, t, k]=min(block, max(0.0, rem-block*(k-1)))
            end
        end
        su=y .* units.coffi_cold_shutup_1
        sd=z .* units.coffi_cold_shutdown_1
        costs=physical_pcm_economic_cost(config_param, units, x, y, z, p, r, JuMP.value.(Rdown),
            JuMP.value.(ls), JuMP.value.(wc))
        rdphys=zeros(NG, NT)
        for g ∈ 1:C, t ∈ 1:NT

            ids=clusters[g].unit_indices
            available=sum(max(0.0, p[i, t]-units.p_min[i]*x[i, t]) for i ∈ ids)
            available>tolerance&&foreach(i->rdphys[i, t]=value(Rdown[g, t])*max(0.0, p[i, t]-units.p_min[i]*x[i, t])/available, ids)
        end
        results=Dict{String, Array{Float64}}(
            "x₀"=>x, "u₀"=>y, "v₀"=>z, "p₀"=>p, "pₖ"=>pk, "su_cost"=>su, "sd_cost"=>sd, "seq_sr⁺"=>r, "seq_sr⁻"=>rdphys,
            "pᵨ"=>JuMP.value.(ls), "pᵩ"=>JuMP.value.(wc), "hydros_output"=>JuMP.value.(H), "res_scheduled_costs"=>costs,
            "cluster_ids"=>Float64.([only(c.id for c ∈ clusters if i in c.unit_indices) for i ∈ 1:NG]),
            "cluster_disaggregation_feasible"=>ones(1, 1))
        return (feasible = true, stage = :complete, results = results, clusters = clusters, checks = checks,
            master = m, disaggregation = dis, feedback_iterations = iteration-1, feedback_lines = feedback_lines)
    end
end
