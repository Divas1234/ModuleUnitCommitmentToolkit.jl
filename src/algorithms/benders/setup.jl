const BENDERS_PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))

"""
    build_benders_setup(; input = :excel, scenario_limit = 50, ...)

Main execution pipeline mapping raw data to the stochastic SCUC Benders formulation.
Returns a named `BendersSetup` containing all formulated JuMP models, internal data
structures, and topological scenario dimensions.
"""
function build_benders_setup(;
    input::Union{Symbol, AbstractString} = :excel,
    scenario_limit::Int64 = 50,
    use_powersystems::Union{Nothing, Bool} = nothing,
    sys = nothing,
    case_name = nothing,
    case_category = MatpowerTestSystems,
    case_dir::String = "",
    data_center_buses::Vector{Int} = Int[],
    data_center_pmax::Vector{Float64} = Float64[],
    frequency_parameters = nothing,
    data_centers = NamedTuple[],
    horizon::Int64 = 24,
    data_file::Union{Nothing, AbstractString} = nothing,
)
    # Load system data using the unified data loader
    data = load_uc_data(;
        input = input,
        scenario_limit = scenario_limit,
        use_powersystems = use_powersystems,
        sys = sys,
        case_name = case_name,
        case_category = case_category,
        case_dir = case_dir,
        data_center_buses = data_center_buses,
        data_center_pmax = data_center_pmax,
        frequency_parameters = frequency_parameters,
        data_centers = data_centers,
        horizon = horizon,
        data_file = data_file,
    )

    config_param = data.config_param
    units = data.units
    lines = data.lines
    loads = data.loads
    winds = data.winds
    psses = data.psses
    data_centers = data.data_centers
    NB = data.NB
    NG = data.NG
    NL = data.NL
    ND = data.ND
    NT = data.NT
    NC = data.NC
    ND2 = data.ND2
    NW = data.NW
    NS = data.NS
    scenarios_prob = data.full_scenario_probability

    # Print imported system statistics and validate core boundaries when enabled.
    maybe_print_boundarycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param; data_centers = data_centers)

    # Linearize generator fuel cost curves
    refcost, eachslope = linearizationfuelcurve(units, NG)

    # Construct the Benders Master Problem algebraically
    scuc_masterproblem, master_model_struct = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, loads, winds, config_param, scenarios_prob)

    # Construct the Benders Base Subproblem algebraically
    scuc_subproblem, sub_model_struct = bd_subfunction(UCProblemData(data); scenarios_prob = scenarios_prob)

    # Fallback initialization validation for scenario probabilities
    if !@isdefined(scenarios_prob)
        println("Warning: scenarios_prob not defined, forcing to default uniform value")
        scenarios_prob = 1.0 / NS
    end

    # Initialize decoupled scenario subproblems. Multi-cut mode requires one
    # independently fixable subproblem per scenario; single-cut mode reuses the
    # aggregate/base model.
    batch_scuc_subproblem_struct_dic = if config_param.consider_multi_cuts == 1
        @info "Generating batch subproblems for multi-cut scenarios"
        dic = get_batch_scuc_subproblems_for_scenario(
            NT,
            NB,
            NL,
            NG,
            ND,
            NC,
            ND2,
            NW,
            units,
            winds,
            loads,
            lines,
            data_centers,
            psses,
            scenarios_prob,
            config_param,
        )
        @info "Batch subproblem dictionary successfully created with $(length(dic)) independent entries."
        dic
    else
        @info "Single subproblem mode activated, reusing base SCUC subproblem."
        OrderedDict{Int64, SCUC_Model}(1 => sub_model_struct)
    end

    # Output constructed structs, models, constraints, and optimization environment settings
    return BendersSetup(
        scuc_masterproblem,
        scuc_subproblem,
        master_model_struct,
        sub_model_struct,
        batch_scuc_subproblem_struct_dic,
        config_param,
        units,
        lines,
        loads,
        winds,
        psses,
        Int64(NB),
        Int64(NG),
        Int64(NL),
        Int64(ND),
        Int64(NS),
        Int64(NT),
        Int64(NC),
        Int64(ND2),
        data_centers,
        data,
    )
end
