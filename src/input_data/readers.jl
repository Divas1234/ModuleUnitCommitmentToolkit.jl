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

function _normalize_input_source(input, use_powersystems, sys, case_name, case_dir)
    source = lowercase(replace(string(input), '-' => '_', ' ' => '_'))
    source = source == "power_systems" ? "powersystems" : source
    source in ("excel", "powersystems", "powersystems_csv") ||
        throw(ArgumentError("input must be :excel, :powersystems, or :powersystems_csv; got $(input)"))

    if source == "powersystems" && !isempty(case_dir) && case_name === nothing
        source = "powersystems_csv"
    end

    if use_powersystems !== nothing
        legacy_source = if use_powersystems
            case_name !== nothing ? "powersystems" : (isempty(case_dir) ? "powersystems" : "powersystems_csv")
        else
            "excel"
        end
        source != "excel" && source != legacy_source &&
            throw(ArgumentError("input=$(input) conflicts with use_powersystems=$(use_powersystems)"))
        source = legacy_source
    end

    return Symbol(source)
end

"""
    load_uc_data(; input = :excel, scenario_limit = 50, use_powersystems = nothing,
                 sys = nothing, case_name = nothing, case_dir = "",
                 frequency_parameters = nothing, data_centers = NamedTuple[], horizon = 24, ...)

Unified data entry point. `input` selects `:excel`, native `:powersystems`, or
`:powersystems_csv` for a `PowerSystems.System` plus project extension files.
The legacy `use_powersystems` flag is retained for compatibility and should not
be used together with a conflicting `input` value.
"""
function load_uc_data(;
    input::Union{Symbol, AbstractString} = :excel,
    scenario_limit::Int64 = 50,
    use_powersystems::Union{Nothing, Bool} = nothing,
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
    input_source = _normalize_input_source(input, use_powersystems, sys, case_name, case_dir)
    if input_source == :powersystems
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
        if sys === nothing
            throw(ArgumentError("sys or case_name is required when input=:powersystems"))
        end
        if isempty(case_dir)
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
        end
    elseif input_source == :powersystems_csv
        sys === nothing && throw(ArgumentError("sys is required when input=:powersystems_csv"))
        isempty(case_dir) && throw(ArgumentError("case_dir is required when input=:powersystems_csv"))
        case_name === nothing || throw(ArgumentError("case_name cannot be used with input=:powersystems_csv"))
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
