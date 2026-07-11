include("formatted_data.jl")
include("excel_reader.jl")
include("boundary_checks.jl")
include("powersystems_reader.jl")
include("powersystems_bridge.jl")

export readxlssheet,
    forminputdata,
    boundrycondition,
    boundarycondition,
    boundary_condition,
    maybe_print_boundarycondition,
    read_powersystems_case,
    load_uc_data,
    build_system_from_powersystems,
    extract_uc_data_from_powersystems,
    generate_wind_scenarios_from_system,
    load_native_powersystems_case

"""
    load_uc_data(; scenario_limit = 50, use_powersystems = false, sys = nothing,
                 case_name = nothing, case_dir = "", frequency_parameters = nothing,
                 data_centers = NamedTuple[], horizon = 24, ...)

Unifies data loading from Excel (default), a CSV-extended `PowerSystems.System`,
or a native `PowerSystemCaseBuilder` case. Native cases do not require a case
directory: provide `case_name` (and optionally `case_category`) or `sys`.
"""
function load_uc_data(;
    scenario_limit::Int64 = 50,
    use_powersystems::Bool = false,
    sys = nothing,
    case_name = nothing,
    case_category = MatpowerTestSystems,
    case_dir::String = "",
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_params_override = nothing,
    frequency_parameters = frequency_params_override,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
)
    if use_powersystems
        if case_name !== nothing
            sys === nothing || throw(ArgumentError("Pass either sys or case_name, not both"))
            return load_native_powersystems_case(
                String(case_name);
                case_category = case_category,
                scenario_limit = scenario_limit,
                frequency_parameters = frequency_parameters,
                data_centers = data_centers,
                horizon = horizon,
            )
        end
        if sys !== nothing && isempty(case_dir)
            config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras, WindsFreqParam, bus_to_idx =
                extract_uc_data_from_powersystems(
                    sys,
                    data_center_buses = data_center_buses,
                    data_center_pmax = data_center_pmax,
                    frequency_parameters = frequency_parameters,
                    data_centers = data_centers,
                    horizon = horizon,
                )
            winds, NW = generate_wind_scenarios_from_system(sys, WindsFreqParam, 1, NT, bus_to_idx = bus_to_idx, scenario_limit = scenario_limit)
            NS = Int64(winds.scenarios_nums)
        else
            sys === nothing && throw(ArgumentError("sys is required when case_dir is provided"))
            config_param, units, lines, loads, psses, winds, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
                read_powersystems_case(sys, case_dir; scenario_limit = scenario_limit)
            NW = length(winds.locatebus)
            NS = Int64(winds.scenarios_nums)
        end
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
