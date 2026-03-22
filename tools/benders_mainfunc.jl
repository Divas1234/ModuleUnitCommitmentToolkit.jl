# Enforce ASCII console output for compatibility
ENV["JULIA_SHOW_ASCII"] = true

# Load main functions and formulations
include("mainfunc.jl")

# Initialize the Security-Constrained Unit Commitment (SCUC) problem.
# Unpack master/subproblem models, configuration parameters, and system data.
scuc_masterproblem,
scuc_subproblem,
master_model_struct,
sub_model_struct,
batch_sub_model_struct_dic,
config_param,
units,
lines,
loads,
winds,
psses,
NB,
NG,
NL,
ND,
NS,
NT,
NC,
ND2,
DataCentras = main();

# Execute the multiple-cut Benders Decomposition algorithm to solve the problem
multiple_bender_decomposition_scuc(
    scuc_masterproblem,
    scuc_subproblem,
    master_model_struct,
    batch_sub_model_struct_dic,
    winds,
    config_param,
)
