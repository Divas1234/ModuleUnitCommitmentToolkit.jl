#!/usr/bin/env julia
# gui/run_boundary.jl — Extract structured boundary data from the SCUC data
# pipeline and emit it as JSON for the Run tab boundary display.
#
# Usage:  julia gui/run_boundary.jl [scenario_limit]
# Prints normal log text to stdout, then emits a JSON block bracketed by
# ###STRUCTURED_DATA### / ###END_STRUCTURED_DATA### markers that the
# Python server /api/run endpoint parses for the frontend tables.

using Pkg
const _ROOT = dirname(@__DIR__)
Pkg.activate(_ROOT)

ENV["PRINT_BOUNDARY_CONDITION"] = "true"
ENV["BOUNDARY_SHOW_PLOTS"] = "false"

include(joinpath(_ROOT, "src", "runtime_config.jl"))
load_runtime_config!(override = true)

include(joinpath(_ROOT, "src", "environment_config.jl"))
include(joinpath(_ROOT, "src", "renewables", "renewables.jl"))
include(joinpath(_ROOT, "src", "input_data", "readers.jl"))
include(joinpath(_ROOT, "src", "input_data", "formatted_data.jl"))
include(joinpath(_ROOT, "src", "unit_commitment", "utilities", "linearization.jl"))

println("Reading input data...")
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

println("Building system topology...")
config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
    DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data,
)

println("Generating wind scenarios...\n")
scenario_limit = parse(Int64, length(ARGS) >= 1 ? ARGS[1] : get(ENV, "CCG_SCENARIO_LIMIT", "5"))
winds, NW = genscenario(WindsFreqParam, 1; scenario_limit = scenario_limit)

NS = Int64(winds.scenarios_nums)

maybe_print_boundarycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

refcost, eachslope = linearizationfuelcurve(units, NG)

function json_escape(text::AbstractString)
    escaped = replace(text, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t")
    return "\"$escaped\""
end

function json_value(value)
    if value === nothing || value === missing
        return "null"
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Integer
        return string(value)
    elseif value isa AbstractFloat
        return isfinite(value) ? string(value) : "null"
    elseif value isa AbstractString || value isa Symbol
        return json_escape(string(value))
    elseif value isa AbstractDict
        parts = [json_escape(string(key)) * ":" * json_value(val) for (key, val) in value]
        return "{" * join(parts, ",") * "}"
    elseif value isa AbstractVector || value isa Tuple
        return "[" * join((json_value(item) for item in value), ",") * "]"
    else
        return json_escape(string(value))
    end
end

checks_list = [
    Dict("label" => "NG matches length(units.index)",       "ok" => NG == length(units.index)),
    Dict("label" => "NL matches length(lines.index)",       "ok" => NL == length(lines.index)),
    Dict("label" => "ND matches length(loads.index)",       "ok" => ND == length(loads.index)),
    Dict("label" => "NW matches length(winds.index)",       "ok" => NW == length(winds.index)),
    Dict("label" => "NT matches load_curve columns",        "ok" => NT == size(loads.load_curve, 2)),
    Dict("label" => "ND matches load_curve rows",           "ok" => ND == size(loads.load_curve, 1)),
    Dict("label" => "NS matches wind scenario rows",        "ok" => NS == size(winds.scenarios_curve, 1)),
    Dict("label" => "NT matches wind scenario columns",     "ok" => NT == size(winds.scenarios_curve, 2)),
    Dict("label" => "All p_max >= p_min",                   "ok" => all(units.p_max .>= units.p_min)),
    Dict("label" => "All line p_max >= 0",                  "ok" => all(lines.p_max .>= 0)),
    Dict("label" => "Load curve finite and non-negative",   "ok" => all(isfinite, loads.load_curve) && all(loads.load_curve .>= 0)),
    Dict("label" => "Wind scenarios finite and non-negative","ok" => all(isfinite, winds.scenarios_curve) && all(winds.scenarios_curve .>= 0)),
]

config_fields = [Dict("key" => String(f), "value" => string(getfield(config_param, f))) for f in fieldnames(config)]

units_data = [
    Dict("index" => units.index[i], "bus" => units.locatebus[i],
         "p_max" => units.p_max[i], "p_min" => units.p_min[i],
         "ramp_up" => units.ramp_up[i], "ramp_down" => units.ramp_down[i],
         "min_up" => units.min_shutup_time[i], "min_down" => units.min_shutdown_time[i],
         "init_status" => units.x_0[i], "init_power" => units.p_0[i],
         "cost_a" => units.coffi_a[i], "cost_b" => units.coffi_b[i], "cost_c" => units.coffi_c[i])
    for i in 1:NG
]

lines_data = [
    Dict("index" => lines.index[i], "from" => lines.from[i], "to" => lines.to[i],
         "x" => lines.x[i], "p_max" => lines.p_max[i], "p_min" => lines.p_min[i])
    for i in 1:NL
]

load_total_by_bus = [round(sum(loads.load_curve[i, :]); digits=2) for i in 1:ND]
load_total_by_time = [round(sum(loads.load_curve[:, j]); digits=2) for j in 1:NT]
wind_scenario_mean = [round(sum(winds.scenarios_curve[:, j]) / NS; digits=4) for j in 1:NT]

data = Dict(
    "system" => Dict(
        "NB" => NB, "NL" => NL, "NG" => NG, "NT" => NT,
        "ND" => ND, "NW" => NW, "NS" => NS, "NC" => length(psses.index),
    ),
    "totals" => Dict(
        "total_pmax" => round(sum(units.p_max); digits=2),
        "total_pmin" => round(sum(units.p_min); digits=2),
        "peak_load"  => round(maximum(sum(loads.load_curve; dims=1))[1]; digits=2),
        "total_wind_cap" => round(sum(winds.p_max); digits=2),
    ),
    "config" => config_fields,
    "validation" => checks_list,
    "units" => units_data,
    "lines" => lines_data,
    "load_totals" => Dict(
        "by_bus" => [Dict("bus" => i, "total_mw" => load_total_by_bus[i]) for i in 1:ND],
        "by_hour" => [Dict("hour" => j, "total_mw" => load_total_by_time[j]) for j in 1:NT],
    ),
    "wind" => Dict(
        "count" => NS,
        "mean_by_hour" => wind_scenario_mean,
        "installed_capacity" => [round(winds.p_max[i]; digits=2) for i in 1:NW],
    ),
)

println("\n###STRUCTURED_DATA###")
println(json_value(data))
println("###END_STRUCTURED_DATA###")
