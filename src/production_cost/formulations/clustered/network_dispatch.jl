if !isdefined(@__MODULE__, :_CLUSTERED_PCM_NETWORK_DISPATCH_INCLUDED)
	const _CLUSTERED_PCM_NETWORK_DISPATCH_INCLUDED = true

	"""
	第二阶段物理调度：固定聚类解群后得到的 `U/Y/Z`。

	驻留流已经把聚合启停数量分配给真实机组。本模型不再增加组合二进制变量，
	只联合优化单机热出力/备用、水电、弃风和全部 DC 线路潮流。

	模型有意不设置负荷损失变量。返回 `nothing` 表示固定启停轨迹无法形成零切负荷网络调度，必须反馈主问题或回退到原始单机 SCUC。

	---
	这是一个小的二阶段优化问题
	1. 在聚类PCM获取不同集群机组的出力时序以后
	2. 以此为边界，构造一个物理网络调度问题，考虑机组的出力约束、爬坡约束、水电约束、弃风约束和线路潮流约束
	3. 以最小化成本为目标，求解出力、备用、水电出力和弃风量（*解群*）
	"""

	function _resolve_pcm_optimizer(optimizer)
		optimizer !== nothing && return optimizer
		if isdefined(@__MODULE__, :default_uc_optimizer)
			return default_uc_optimizer()
		end
		if isdefined(@__MODULE__, :Gurobi)
			return getfield(@__MODULE__, :Gurobi).Optimizer
		end
		error("No optimizer specified for PCM solver; pass `optimizer = ...` or configure `set_default_uc_optimizer!`.")
	end

	function solve_clustered_physical_network_dispatch(
			x, y, z, units, loads, winds, hydros, lines, gsdf, config_param, NT, ND, NW, NH; optimizer = nothing, tolerance = 1e-5)
		NG=size(x, 1)
		NL=size(gsdf, 1)
		refcost, eachslope = linearizationfuelcurve(units, NG)
		c₀ = hasproperty(config_param, :is_CoalPrice) ? config_param.is_CoalPrice : 1.0
		base_wind_penalty = isdefined(@__MODULE__, :_pcm_wind_curtailment_penalty) ? _pcm_wind_curtailment_penalty(config_param) : 1e6
		wind_penalty = max(base_wind_penalty, max(maximum(eachslope; init = 0.0) * c₀ + 1.0, 1e6))
		m=Model(_resolve_pcm_optimizer(optimizer))
		set_silent(m)
		@variable(m, p[1:NG, 1:NT]>=0)
		@variable(m, q[1:NG, 1:NT, 1:3]>=0)
		@variable(m, ru[1:NG, 1:NT]>=0)
		@variable(m, rd[1:NG, 1:NT]>=0)
		@variable(m, h[1:NH, 1:NT]>=0)
		@variable(m, wc[1:NW, 1:NT]>=0)
		# 使用驻留流产生的固定二进制路径，逐台检查出力、备用和爬坡约束。
		for i ∈ 1:NG, t ∈ 1:NT

			block = (units.p_max[i] - units.p_min[i]) / 3
			@constraint(m, p[i, t] == units.p_min[i] * x[i, t] + sum(q[i, t, k] for k ∈ 1:3))
			for k ∈ 1:3
				@constraint(m, q[i, t, k] <= block * x[i, t])
			end
			@constraint(m, p[i, t]+ru[i, t]<=units.p_max[i]*x[i, t])
			@constraint(m, p[i, t]-rd[i, t]>=units.p_min[i]*x[i, t])
			prev=t==1 ? units.p_0[i] : p[i, t - 1]
			prev_on=t==1 ? units.x_0[i] : x[i, t - 1]
			@constraint(m, p[i, t]-prev<=units.ramp_up[i]*prev_on+units.shut_up[i]*y[i, t])
			@constraint(m, prev-p[i, t]<=units.ramp_down[i]*x[i, t]+units.shut_down[i]*z[i, t])
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
			demand=sum(loads.load_curve[:, t]; init = 0.0)
			wind=NW == 0 ? 0.0 : sum(winds.scenarios_curve[1, t]*winds.p_max[w] for w ∈ 1:NW; init = 0.0)
			hydro_gen=NH == 0 ? 0.0 : sum(h[:, t])
			wind_curt=NW == 0 ? 0.0 : sum(wc[:, t])
			@constraint(m, sum(p[:, t])+hydro_gen+wind-wind_curt==demand)
			hydro_up=NH == 0 ? 0.0 : sum(min(hydros.p_max[j], hydros.reservoircurve[t, 1])-h[j, t] for j ∈ 1:NH; init = 0.0)
			for i ∈ 1:NG
				@constraint(m, sum(ru[:, t])+hydro_up>=0.5*units.p_max[i]*x[i, t])
			end
			forecast=NW == 0 ? 0.0 : winds.scenarios_curve[1, t]*sum(winds.p_max; init = 0.0)*0.05
			hydro_down=NH == 0 ? 0.0 : sum(h[j, t]-hydros.p_min[j] for j ∈ 1:NH; init = 0.0)
			@constraint(m, sum(rd[:, t])+hydro_down>=config_param.alpha*forecast+config_param.beta*demand)
			# PTDF 符号：发电为正注入、已服务负荷为负注入。
			for l ∈ 1:NL
				flow=@expression(m,
					sum(gsdf[l, units.locatebus[i]]*p[i, t] for i ∈ 1:NG; init = 0.0) +
					(NH == 0 ? 0.0 : sum(gsdf[l, hydros.locatebus[j]]*h[j, t] for j ∈ 1:NH; init = 0.0)) +
					(NW == 0 ? 0.0 : sum(gsdf[l, winds.locatebus[w]]*(winds.scenarios_curve[1, t]*winds.p_max[w]-wc[w, t]) for w ∈ 1:NW; init = 0.0)) -
					(ND == 0 ? 0.0 : sum(gsdf[l, loads.locatebus[d]]*loads.load_curve[d, t] for d ∈ 1:ND; init = 0.0)))
				@constraint(m, lines.p_min[l]+tolerance<=flow)
				@constraint(m, flow<=lines.p_max[l]-tolerance)
			end
		end
		# PWL LP objective matching standard/clustered PCM fuel & reserve pricing (LP-compatible with GLPK/HiGHS/Gurobi).
		@objective(m, Min,
			c₀ * (
				sum(refcost[i] * x[i, t] for i ∈ 1:NG, t ∈ 1:NT; init = 0.0) +
				sum(eachslope[k, i] * q[i, t, k] for i ∈ 1:NG, t ∈ 1:NT, k ∈ 1:3; init = 0.0) +
				2c₀ * (sum(ru; init = 0.0) + sum(rd; init = 0.0))
			) +
			wind_penalty * (NW == 0 ? 0.0 : sum(wc; init = 0.0)))
		optimize!(m)
		has_feasible = isdefined(@__MODULE__, :uc_has_feasible_solution) ? uc_has_feasible_solution(m) :
			(termination_status(m) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) || (termination_status(m) == MOI.TIME_LIMIT && has_values(m)))
		has_feasible || return nothing
		return (power = value.(p), reserve_up = value.(ru), reserve_down = value.(rd),
			hydro = NH == 0 ? zeros(Float64, 0, NT) : value.(h),
			wind_curtailment = NW == 0 ? zeros(Float64, 0, NT) : value.(wc), model = m)
	end
end
