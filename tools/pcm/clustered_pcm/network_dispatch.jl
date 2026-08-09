if !isdefined(@__MODULE__, :_CLUSTERED_PCM_NETWORK_DISPATCH_INCLUDED)
    const _CLUSTERED_PCM_NETWORK_DISPATCH_INCLUDED = true

    """
    第二阶段物理调度：固定聚类解群后得到的 `U/Y/Z`。

    驻留流已经把聚合启停数量分配给真实机组。本模型不再增加组合二进制变量，
    只联合优化单机热出力/备用、水电、弃风和全部 DC 线路潮流。

    模型有意不设置负荷损失变量。返回 `nothing` 表示固定启停轨迹无法形成零切负荷网络调度，必须反馈主问题或回退到原始单机 SCUC。
    """
    function solve_clustered_physical_network_dispatch(
            x, y, z, units, loads, winds, hydros, lines, gsdf, config_param, NT, ND, NW, NH; optimizer = Gurobi.Optimizer, tolerance = 1e-5)
        NG=size(x, 1)
        NL=size(gsdf, 1)
        m=Model(optimizer)
        set_silent(m)
        @variable(m, p[1:NG, 1:NT]>=0)
        @variable(m, ru[1:NG, 1:NT]>=0)
        @variable(m, rd[1:NG, 1:NT]>=0)
        @variable(m, h[1:NH, 1:NT]>=0)
        @variable(m, wc[1:NW, 1:NT]>=0)
        # 使用驻留流产生的固定二进制路径，逐台检查出力、备用和爬坡约束。
        for i ∈ 1:NG, t ∈ 1:NT

            @constraint(m, units.p_min[i]*x[i, t]<=p[i, t])
            @constraint(m, p[i, t]+ru[i, t]<=units.p_max[i]*x[i, t])
            @constraint(m, p[i, t]-rd[i, t]>=units.p_min[i]*x[i, t])
            prev=t==1 ? units.p_0[i] : p[i, t - 1]
            prev_on=t==1 ? units.x_0[i] : x[i, t - 1]
            @constraint(m, p[i, t]-prev<=units.ramp_up[i]*prev_on+units.shut_up[i]*y[i, t]+units.p_max[i]*(1-prev_on))
            @constraint(m, prev-p[i, t]<=units.ramp_down[i]*x[i, t]+units.shut_down[i]*z[i, t]+units.p_max[i]*(1-x[i, t]))
        end
        for w ∈ 1:NW, t ∈ 1:NT

            @constraint(m, wc[w, t]<=winds.scenarios_curve[1, t]*winds.p_max[w])
        end
        for j ∈ 1:NH, t ∈ 1:NT

            @constraint(m, hydros.p_min[j]<=h[j, t])
            @constraint(m, h[j, t]<=min(hydros.p_max[j], hydros.reservoircurve[t, 1]))
        end
        for j ∈ 1:NH
            @constraint(m, hydros.q_0[j]+sum(hydros.reservoircurve[t, 1]-h[j, t] for t ∈ 1:NT)<=hydros.q_max[j])
        end
        for t ∈ 1:NT
            demand=sum(loads.load_curve[:, t])
            wind=sum(winds.scenarios_curve[1, t]*winds.p_max)
            @constraint(m, sum(p[:, t])+sum(h[:, t])+wind-sum(wc[:, t])==demand)
            hydro_up=sum(min(hydros.p_max[j], hydros.reservoircurve[t, 1])-h[j, t] for j ∈ 1:NH)
            for i ∈ 1:NG
                @constraint(m, sum(ru[:, t])+hydro_up>=0.5*units.p_max[i]*x[i, t])
            end
            forecast=winds.scenarios_curve[1, t]*sum(winds.p_max)*0.05
            @constraint(m, sum(rd[:, t])+sum(h[j, t]-hydros.p_min[j] for j ∈ 1:NH)>=config_param.is_Alpha*forecast+config_param.is_Belta*demand)
            # PTDF 符号：发电为正注入、已服务负荷为负注入。
            # winds.index 沿用旧 PCM 网络模型的风电节点口径。
            for l ∈ 1:NL
                flow=@expression(m,
                    sum(gsdf[l, units.locatebus[i]]*p[i, t] for i ∈ 1:NG) +
                    sum(gsdf[l, hydros.locatebus[j]]*h[j, t] for j ∈ 1:NH) +
                    sum(gsdf[l, winds.index[w]]*(winds.scenarios_curve[1, t]*winds.p_max[w]-wc[w, t]) for w ∈ 1:NW) -
                    sum(gsdf[l, loads.locatebus[d]]*loads.load_curve[d, t] for d ∈ 1:ND))
                @constraint(m, lines.p_min[l]+tolerance<=flow)
                @constraint(m, flow<=lines.p_max[l]-tolerance)
            end
        end
        # 弃风惩罚远高于常规成本：只有固定启停状态或网络可行性要求时才弃风。
        @objective(m, Min,
            sum(units.coffi_a[i]*p[i, t]^2+units.coffi_b[i]*p[i, t]+units.coffi_c[i]*x[i, t] for i ∈ 1:NG, t ∈ 1:NT) +
            sum(ru) +
            sum(rd) +
            1e6*sum(wc))
        optimize!(m)
        termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)||return nothing
        return (power = value.(p), reserve_up = value.(ru), reserve_down = value.(rd), hydro = value.(h), wind_curtailment = value.(wc), model = m)
    end
end
