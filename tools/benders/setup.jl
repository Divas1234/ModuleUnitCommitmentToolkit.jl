# Runtime configuration must be loaded before any downstream include reads ENV.
# Shell-provided ENV values still have priority, which keeps scheduler scripts
# and one-off terminal overrides reproducible.
const BENDERS_PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
if !isdefined(@__MODULE__, :load_runtime_config!)
    include(joinpath(BENDERS_PROJECT_ROOT, "src", "runtime_config.jl"))
end
isdefined(@__MODULE__, :BendersSetup) || include(joinpath(BENDERS_PROJECT_ROOT, "src", "api_types.jl"))
load_runtime_config!()

# Load environment configurations, simulation modules, and data readers
isdefined(@__MODULE__, :gr) || include(joinpath(BENDERS_PROJECT_ROOT, "src", "environment_config.jl"))
isdefined(@__MODULE__, :wind) || include(joinpath(BENDERS_PROJECT_ROOT, "src", "renewables", "renewables.jl"))
isdefined(@__MODULE__, :load_uc_data) || include(joinpath(BENDERS_PROJECT_ROOT, "src", "input_data", "readers.jl"))
# The model stack is loaded by the formulation includes below; paths are rooted
# from this file rather than from the caller's current directory.

# Load Benders decomposition formulation and cut-generation libraries.
include("models/construct_models.jl")
include("cuts/construct_cuts.jl")
include("decomposition.jl")

##
"""
	`main()`

	Main execution pipeline mapping raw data to the stochastic SCUC formulation.

	This function is the single data-construction entry point used by the Benders
	driver and by the CCG loader. It returns a named `BendersSetup`; runtime options arrive through TOML-backed ENV
	values before `forminputdata` builds the `config` struct, which keeps model
	flags consistent across both algorithms.

	# Returns
	A named `BendersSetup` containing all formulated JuMP models, internal data structures,
	and topological scenario dimensions.
"""

function main(;
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
    )

    config_param = data.config_param
    units = data.units
    lines = data.lines
    loads = data.loads
    winds = data.winds
    psses = data.psses
    DataCentras = data.DataCentras
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
    maybe_print_boundarycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param; data_centers = DataCentras)

    # Linearize generator fuel cost curves
    refcost, eachslope = linearizationfuelcurve(units, NG)

    # Construct the Benders Master Problem algebraically
    scuc_masterproblem, master_model_struct = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, loads, winds, config_param, scenarios_prob)

    # Construct the Benders Base Subproblem algebraically
    scuc_subproblem, sub_model_struct =
        bd_subfunction(NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, winds, loads, lines, DataCentras, psses, scenarios_prob, config_param)

    # Fallback initialization validation for scenario probabilities
    if !@isdefined(scenarios_prob)
        println("Warning: scenarios_prob not defined, forcing to default uniform value")
        scenarios_prob = 1.0 / NS
    end

    # Initialize decoupled scenario subproblems. Multi-cut mode requires one
    # independently fixable subproblem per scenario; single-cut mode reuses the
    # aggregate/base model.
    if config_param.is_ConsiderMultiCUTs == 1
        # Create discrete subproblem instances explicitly for multi-cut logic evaluation
        batch_scuc_subproblem_struct_dic = OrderedDict{Int64, SCUC_Model}()
        batch_scuc_subproblem_struct_dic = if (config_param.is_ConsiderMultiCUTs == 1)
            get_batch_scuc_subproblems_for_scenario(
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
                DataCentras,
                psses,
                scenarios_prob,
                config_param,
            )
        else
            OrderedDict(1 => sub_model_struct)
        end
        @info "Generating batch subproblems for multi-cut scenarios"
        @info "Batch subproblem dictionary successfully created with $(length(batch_scuc_subproblem_struct_dic)) independent entries."
    else
        @info "Single subproblem mode activated, skipping batch SCUC model multicut initialization."
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
        DataCentras,
        data,
    )
end
