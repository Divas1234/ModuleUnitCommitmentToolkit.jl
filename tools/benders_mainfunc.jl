# Enforce ASCII console output for compatibility
ENV["JULIA_SHOW_ASCII"] = true

# Load main functions and formulations
include("mainfunc.jl")

# Initialize the Security-Constrained Unit Commitment (SCUC) problem.
# Unpack master/subproblem models, configuration parameters, and system data.
scenario_limit = parse(Int64, get(ENV, "BENDERS_SCENARIO_LIMIT", "50"))
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main(; scenario_limit = scenario_limit);

# Derive NW from the wind scenario data (number of wind farms = length of wind index vector)
NW = Int64(length(winds.index))

jensen_subproblem_struct = if get(ENV, "BENDERS_ENABLE_JENSEN_CUT", "0") == "1" && config_param.is_ConsiderMultiCUTs == 1
    build_jensen_subproblem_for_mean_scenario(NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, DataCentras, psses, config_param)
else
    nothing
end

# Execute the multiple-cut Benders Decomposition algorithm to solve the problem
multiple_bender_decomposition_scuc(
    scuc_masterproblem,
    scuc_subproblem,
    master_model_struct,
    batch_sub_model_struct_dic,
    winds,
    config_param,
    NG,
    NT,
    NW,
    ND,
    NL;
    jensen_subproblem_struct = jensen_subproblem_struct,
)
