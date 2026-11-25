using JuMP

# Helper function for transmission line constraints

"""
    device_net_injection(model::Model, dev, s::Int, t::Int, gsdf_line::AbstractVector)

Extensible multiple-dispatch hook returning the GSDF-weighted active power net injection
(positive = generation/discharge into grid, negative = load/charge from grid) contributed
by device container `dev` in scenario `s` at period `t` along a transmission line with
shift-factor row `gsdf_line`.

New flexible resources (e.g. hydrogen electrolyzers, pumped hydro, VPP) only need to
define a device struct and one method of `device_net_injection` without modifying
`add_transmission_constraints!`.
"""
device_net_injection(::Model, ::Any, ::Int, ::Int, ::AbstractVector) = 0.0

function device_net_injection(scuc::Model, storages::StorageUnits, s::Int, t::Int, gsdf_line::AbstractVector)
    NC = length(storages.locatebus)
    NC == 0 && return 0.0
    (check_var_exists(scuc, "pc⁺") && check_var_exists(scuc, "pc⁻")) || return 0.0
    pc⁺ = scuc[:pc⁺]
    pc⁻ = scuc[:pc⁻]
    return sum(gsdf_line[storages.locatebus[c]] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) for c in 1:NC)
end

function device_net_injection(scuc::Model, data_centers::DataCenters, s::Int, t::Int, gsdf_line::AbstractVector)
    ND2 = length(data_centers.locatebus)
    ND2 == 0 && return 0.0
    check_var_exists(scuc, "dc_p") || return 0.0
    dc_p = scuc[:dc_p]
    return -sum(gsdf_line[data_centers.locatebus[c]] * dc_p[(s - 1) * ND2 + c, t] for c in 1:ND2)
end

"""
`add_transmission_constraints!(...)`

Enforces transmission line limits using a DC power flow approximation based on
Generation Shift Density Factors (GSDF). This ensures that the net injection
at each node, when mapped to line flows, does not exceed the thermal capacity (p_max)
or stability limits (p_min) of any transmission line.

# Logic

Flow(Line l) = Sum(GSDF(l, Bus b) * Net_Injection(Bus b))
Net_Injection(Bus b) = P_gen + P_wind_net - P_load_net + sum(device_net_injection(dev))
"""
function add_transmission_constraints!(
    scuc::Model,
    NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, storages, Gsdf, config_param,
    ND2 = nothing,
    data_centers = nothing;
    extra_devices = (),
)

    # Only apply constraints if network modeling is enabled and GSDF data is available
    if config_param.is_network_con == 1 && Gsdf !== nothing && NL > 0
        transmissionline_powerflow_upbound_constr = [] # Container for upper bound (P <= Pmax)
        transmissionline_powerflow_downbound_constr = [] # Container for lower bound (P >= Pmin)

        pg₀ = scuc[:pg₀] # Base generation
        Δpd = scuc[:Δpd] # Load shedding slack
        Δpw = scuc[:Δpw] # Wind curtailment slack

        active_devices = Any[]
        if NC > 0 && storages !== nothing && !isempty(storages.locatebus)
            push!(active_devices, storages)
        end
        if config_param.consider_data_center == 1 && ND2 !== nothing && ND2 > 0 && data_centers !== nothing
            push!(active_devices, data_centers)
        end
        for dev in extra_devices
            dev !== nothing && push!(active_devices, dev)
        end

        for l in 1:NL
            gsdf_row = @view Gsdf[l, :]
            subGsdf_units = Gsdf[l, units.locatebus]
            subGsdf_winds = Gsdf[l, winds.locatebus]
            subGsdf_loads = Gsdf[l, loads.locatebus]

            flow = @expression(
                scuc,
                [s = 1:NS, t = 1:NT],
                sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
                (NW > 0 ? sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] - Δpw[(s - 1) * NW + w, t]) for w in 1:NW) : 0.0) -
                (ND > 0 ? sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t]) for d in 1:ND) : 0.0) +
                (isempty(active_devices) ? 0.0 : sum(device_net_injection(scuc, dev, s, t, gsdf_row) for dev in active_devices))
            )
            push!(transmissionline_powerflow_upbound_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], flow[s, t] <= lines.p_max[l, 1]))
            push!(transmissionline_powerflow_downbound_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], flow[s, t] >= lines.p_min[l, 1]))
        end
        println("\t constraints: 10) transmissionline limits for basline\t\t\t done")
        return scuc, transmissionline_powerflow_upbound_constr, transmissionline_powerflow_downbound_constr
    else
        println("\t constraints: 10) transmissionline limits skipped (is_network_con != 1 or Gsdf missing or NL=0)")
        return scuc, Any[], Any[]
    end
end
