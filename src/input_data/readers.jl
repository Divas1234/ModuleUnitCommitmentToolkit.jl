include("formatted_data.jl")
include("excel_reader.jl")
include("boundary_checks.jl")
include("powersystems_reader.jl")

export readxlssheet, forminputdata, boundrycondition, boundarycondition, boundary_condition, maybe_print_boundarycondition, read_powersystems_case, load_uc_data

"""
    load_uc_data(; scenario_limit = 50, use_powersystems = false, sys = nothing, case_dir = "")

Unifies data loading from Excel (default) or PowerSystems.jl.
"""
function load_uc_data(; scenario_limit::Int64 = 50, use_powersystems::Bool = false, sys = nothing, case_dir::String = "")
    if use_powersystems
        config_param, units, lines, loads, psses, winds, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
            read_powersystems_case(sys, case_dir; scenario_limit = scenario_limit)
        NW = length(winds.locatebus)
        NS = Int64(winds.scenarios_nums)
    else
        UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()
        config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
            forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)
        winds, NW = genscenario(WindsFreqParam, 1; scenario_limit = scenario_limit)
        NS = Int64(winds.scenarios_nums)
    end

    return (
        config_param = config_param,
        units = units,
        lines = lines,
        loads = loads,
        winds = winds,
        psses = psses,
        DataCentras = DataCentras,
        NB = NB,
        NG = NG,
        NL = NL,
        ND = ND,
        NT = NT,
        NC = NC,
        ND2 = ND2,
        NW = NW,
        NS = NS,
        full_scenario_probability = 1.0 / NS,
    )
end

println("\t\u2192 inputdata was written and reformatted for UC modeling.")
