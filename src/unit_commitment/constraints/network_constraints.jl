using JuMP

export add_transmission_constraints!

# Helper function for transmission line constraints

"""
`add_transmission_constraints!(...)`

Enforces transmission line limits using a DC power flow approximation based on
Generation Shift Density Factors (GSDF). This ensures that the net injection
at each node, when mapped to line flows, does not exceed the thermal capacity (p_max)
or stability limits (p_min) of any transmission line.

# Logic

Flow(Line l) = Sum(GSDF(l, Bus b) * Net_Injection(Bus b))
Net_Injection(Bus b) = P_gen + P_wind_net - P_load_net - P_storage_net - P_datacenter_net
"""
function add_transmission_constraints!(scuc::Model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2 = nothing, DataCentras = nothing)

	# Only apply constraints if network modeling is enabled and GSDF data is available
	if config_param.is_NetWorkCon == 1 && Gsdf !== nothing && NL > 0
		transmissionline_powerflow_upbound_constr = [] # Container for upper bound (P <= Pmax)
		transmissionline_powerflow_downbound_constr = [] # Container for lower bound (P >= Pmin)

		# Check if network constraints should be applied
		if NL == 0 || Gsdf === nothing
			println("\t constraints: 10) transmissionline limits skipped (NL=0 or Gsdf missing)")
			return nothing
		end

		pg₀ = scuc[:pg₀] # Base generation
		Δpd = scuc[:Δpd] # Load shedding slack
		Δpw = scuc[:Δpw] # Wind curtailment slack

		# Retrieve storage variable references if they exist in the model
		pc⁺ = check_var_exists(scuc, "pc⁺") ? scuc[:pc⁺] : nothing
		pc⁻ = check_var_exists(scuc, "pc⁻") ? scuc[:pc⁻] : nothing

		dc_enabled = config_param.is_ConsiderDataCentra == 1 && ND2 !== nothing && ND2 > 0 && DataCentras !== nothing && check_var_exists(scuc, "dc_p")
		dc_p = dc_enabled ? scuc[:dc_p] : nothing

		for l in 1:NL
			subGsdf_units = Gsdf[l, units.locatebus]
			subGsdf_winds = Gsdf[l, winds.index]
			subGsdf_loads = Gsdf[l, loads.locatebus]
			subGsdf_psses = (NC > 0 && !isempty(stroges.locatebus)) ? Gsdf[l, stroges.locatebus] : []
			subGsdf_dc = dc_enabled ? Gsdf[l, DataCentras.locatebus] : Float64[]

			flow = @expression(scuc, [s = 1:NS, t = 1:NT],
				sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
				sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] - Δpw[(s - 1) * NW + w, t]) for w in 1:NW) -
				sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t]) for d in 1:ND) -
				(dc_enabled ? sum(subGsdf_dc[c] * dc_p[(s - 1) * ND2 + c, t] for c in 1:ND2) : 0.0) +
				sum((NC > 0 && pc⁺ !== nothing && pc⁻ !== nothing && c <= length(subGsdf_psses)) ?
					subGsdf_psses[c] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) : 0.0 for c in 1:NC)
			)
			push!(transmissionline_powerflow_upbound_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], flow[s, t] <= lines.p_max[l, 1]))
			push!(transmissionline_powerflow_downbound_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], flow[s, t] >= lines.p_min[l, 1]))
		end
		println("\t constraints: 10) transmissionline limits for basline\t\t\t done")
		return scuc, transmissionline_powerflow_upbound_constr, transmissionline_powerflow_downbound_constr
	else
		return println("\t constraints: 10) transmissionline limits skipped (is_NetWorkCon != 1 or Gsdf missing or NL=0)")
	end
end
