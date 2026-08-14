if !isdefined(@__MODULE__, :_CLUSTERED_PCM_COSTS_INCLUDED)
	const _CLUSTERED_PCM_COSTS_INCLUDED = true

	"""Build aggregate coefficients that preserve the physical PCM cost model."""
	function clustered_pcm_cost_coefficients(units, clusters; tolerance = 1e-7)
		NG = length(units.index)
		refcost, eachslope = linearizationfuelcurve(units, NG)
		C = length(clusters)
		cluster_refcost = zeros(C)
		cluster_slopes = zeros(size(eachslope, 1), C)
		cluster_startup = zeros(C)
		cluster_shutdown = zeros(C)
		cluster_pmin = zeros(C)
		cluster_pmax = zeros(C)
		for c in clusters
			members = c.unit_indices
			representative = first(members)
			member_slopes = eachslope[:, members]
			spread = maximum(member_slopes; dims = 2) .- minimum(member_slopes; dims = 2)
			maximum(spread; init = 0.0) <= tolerance * max(1.0, maximum(abs.(member_slopes); init = 0.0)) ||
				throw(ArgumentError("cluster $(c.id) contains materially different production-cost slopes"))
			cluster_refcost[c.id] = refcost[representative]
			cluster_slopes[:, c.id] .= eachslope[:, representative]
			cluster_startup[c.id] = units.coffi_cold_shutup_1[representative]
			cluster_shutdown[c.id] = units.coffi_cold_shutdown_1[representative]
			cluster_pmin[c.id] = units.p_min[representative]
			cluster_pmax[c.id] = units.p_max[representative]
		end
		(refcost = cluster_refcost, eachslope = cluster_slopes, startup = cluster_startup,
			shutdown = cluster_shutdown, pmin = cluster_pmin, pmax = cluster_pmax)
	end

	"""Return the same economic objective used by the physical PCM master."""
	function clustered_pcm_economic_expression(config_param, coeffs, U, Y, Z, Q, R, Rdown, ls, wc;
			scenarios_prob = 1.0)
		c₀ = config_param.is_CoalPrice
		load_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
		base_wind_penalty = config_param.is_WindsCuttingCoefficient * 1e0
		# In the compact model a coarse output state can otherwise make wind
		# curtailment cheaper than replacing thermal fuel.  Use a master-only
		# economic floor; physical result reporting below keeps the common project
		# coefficient so costs remain comparable across PCM methods.
		# 与二阶段物理调度采用一致的高弃风价值。旧值仅略高于燃料边际
		# 成本，主问题会主动选择二阶段无法经济消纳风电的承诺轨迹。
		auto_floor=max(maximum(coeffs.eachslope; init=0.0)*c₀+1.0, 1e6)
		configured_floor=parse(Float64, get(ENV, "PCM_CLUSTER_WIND_PENALTY_FLOOR", string(auto_floor)))
		wind_penalty = max(base_wind_penalty, configured_floor)
		C, T = size(U)
		startup_shutdown = sum(coeffs.startup[g] * Y[g, t] + coeffs.shutdown[g] * Z[g, t] for g ∈ 1:C, t ∈ 1:T)
		fuel = c₀ * (sum(coeffs.refcost[g] * U[g, t] for g ∈ 1:C, t ∈ 1:T) +
					 scenarios_prob * sum(coeffs.eachslope[k, g] * Q[g, t, k] for g ∈ 1:C, t ∈ 1:T, k ∈ axes(Q, 3)) +
					 scenarios_prob * 2c₀ * sum(R[g, t] + Rdown[g, t] for g ∈ 1:C, t ∈ 1:T))
		startup_shutdown + fuel + scenarios_prob * (load_penalty * sum(ls) + wind_penalty * sum(wc))
	end

	# display each cost-term for clustered pcm
	function clustered_pcm_economic_cost(config_param, coeffs, U, Y, Z, Q, R, Rdown, ls, wc;
			scenarios_prob = 1.0)
		c₀ = config_param.is_CoalPrice
		startup = sum(coeffs.startup[g] * Y[g, t] for g ∈ axes(U, 1), t ∈ axes(U, 2))
		shutdown = sum(coeffs.shutdown[g] * Z[g, t] for g ∈ axes(U, 1), t ∈ axes(U, 2))
		production = c₀ * (sum(coeffs.refcost[g] * U[g, t] for g ∈ axes(U, 1), t ∈ axes(U, 2)) +
						   scenarios_prob * sum(coeffs.eachslope[k, g] * Q[g, t, k] for g ∈ axes(U, 1), t ∈ axes(U, 2), k ∈ axes(Q, 3)))
		reserve_up = scenarios_prob * c₀ * 2c₀ * sum(R)
		reserve_down = scenarios_prob * c₀ * 2c₀ * sum(Rdown)
		load_cost = scenarios_prob * config_param.is_LoadsCuttingCoefficient * 1e10 * sum(ls)
		wind_cost = scenarios_prob * config_param.is_WindsCuttingCoefficient * 1e0 * sum(wc)
		reshape([startup, shutdown, production, reserve_up, reserve_down, load_cost, wind_cost], 1, 7)
	end

	function _physical_pcm_pwl_segments(units, x, p)
		NG, T = size(x)
		Q = zeros(NG, T, 3)
		for i ∈ 1:NG, t ∈ 1:T

			block = (units.p_max[i] - units.p_min[i]) / 3
			remaining = max(0.0, p[i, t] - units.p_min[i] * x[i, t])
			for k ∈ 1:3
				Q[i, t, k] = min(block, max(0.0, remaining - block * (k - 1)))
			end
		end
		Q
	end

	"""Recalculate physical-unit costs using the standard PCM reporting columns."""
	function physical_pcm_economic_cost(config_param, units, x, y, z, p, reserve_up, reserve_down, load_shed, wind_curtail;
			scenarios_prob = 1.0)
		NG, T = size(x)
		refcost, eachslope = linearizationfuelcurve(units, NG)
		Q = _physical_pcm_pwl_segments(units, x, p)
		c₀ = config_param.is_CoalPrice
		startup = sum(units.coffi_cold_shutup_1[i] * y[i, t] for i ∈ 1:NG, t ∈ 1:T)
		shutdown = sum(units.coffi_cold_shutdown_1[i] * z[i, t] for i ∈ 1:NG, t ∈ 1:T)
		production = c₀ * (sum(refcost[i] * x[i, t] for i ∈ 1:NG, t ∈ 1:T) +
						   scenarios_prob * sum(eachslope[k, i] * Q[i, t, k] for i ∈ 1:NG, t ∈ 1:T, k ∈ 1:3))
		reserve_up_cost = scenarios_prob * c₀ * 2c₀ * sum(reserve_up)
		reserve_down_cost = scenarios_prob * c₀ * 2c₀ * sum(reserve_down)
		load_cost = scenarios_prob * config_param.is_LoadsCuttingCoefficient * 1e10 * sum(load_shed)
		wind_cost = scenarios_prob * config_param.is_WindsCuttingCoefficient * 1e0 * sum(wind_curtail)
		reshape([startup, shutdown, production, reserve_up_cost, reserve_down_cost, load_cost, wind_cost], 1, 7)
	end
end
