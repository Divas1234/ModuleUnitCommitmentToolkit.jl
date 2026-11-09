# Benders production entry point.
#
# Configure runs through `MODULE_UC_CONFIG_FILE=/path/to/runtime_config.toml`
# or direct ENV overrides such as `BENDERS_SCENARIO_LIMIT=20`. The setup file
# loads TOML defaults before data import, so model flags in `[model]` are already
# reflected in the `config` struct returned by `main`.
include("setup.jl")

scenario_limit = parse(Int64, get(ENV, "BENDERS_SCENARIO_LIMIT", "50"))
setup = main(; scenario_limit = scenario_limit)
scuc_masterproblem = setup.master_model
scuc_subproblem = setup.sub_model
master_model_struct = setup.master_struct
batch_sub_model_struct_dic = setup.batch_subproblems
config_param = setup.config_param
units = setup.units
lines = setup.lines
loads = setup.loads
winds = setup.winds
psses = setup.psses
NB = setup.NB
NG = setup.NG
NL = setup.NL
ND = setup.ND
NS = setup.NS
NT = setup.NT
NC = setup.NC
ND2 = setup.ND2
DataCentras = setup.DataCentras

# `NW` is derived from the final wind object to stay correct after scenario
# filtering or stochastic generator changes.
NW = Int64(length(winds.index))

# Jensen cuts are an optional strengthening path. They are intentionally gated
# behind both the ENV switch and multi-cut mode because the cut depends on a
# mean-scenario subproblem aligned with per-scenario theta variables.
jensen_subproblem_struct = if get(ENV, "BENDERS_ENABLE_JENSEN_CUT", "0") == "1" && config_param.is_ConsiderMultiCUTs == 1
    build_jensen_subproblem_for_mean_scenario(NT, NB, NL, NG, ND, NC, ND2, NW, units, winds, loads, lines, DataCentras, psses, config_param)
else
    nothing
end

"""
	solve_fast_extensive_uc(...)

Build and solve the full extensive-form stochastic UC model.

This path is used as a benchmark and diagnostic fallback for Benders runs. It
uses the same data, objective, and constraints as decomposition, but solves all
scenarios in one JuMP model. Keep it disabled for large production cases unless
the goal is validation rather than decomposition performance.
"""

function solve_fast_extensive_uc(NT, NB, NG, ND, NC, ND2, NS, NW, NL, units, loads, winds, lines, DataCentras, psses, config_param, scenarios_prob)
    println("Starting fast extensive-form UC solve for Benders benchmark/convergence...")
    gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)
    refcost, eachslope = linearizationfuelcurve(units, NG)
    onoffinit = calculate_initial_unit_status(units, NG)
    contingency_size = define_contingency_size(units, NG)

    model = Model(Gurobi.Optimizer)
    set_silent(model)
    set_optimizer_attribute(model, "MIPGap", parse(Float64, get(ENV, "BENDERS_FAST_MIP_GAP", "1e-4")))
    set_optimizer_attribute(model, "NumericFocus", parse(Int64, get(ENV, "BENDERS_FAST_NUMERIC_FOCUS", "1")))

    define_decision_variables!(model, NT, NG, ND, NC, ND2, NS, NW, config_param)
    set_objective!(model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
    add_unit_operation_constraints!(model, NT, NG, units, onoffinit)
    add_curtailment_constraints!(model, NT, ND, NW, NS, loads, winds)
    add_generator_power_constraints!(model, NT, NG, NS, units)
    add_reserve_constraints!(model, NT, NG, NC, NS, units, loads, winds, config_param)
    add_power_balance_constraints!(model, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
    add_ramp_constraints!(model, NT, NG, NS, units, onoffinit)
    add_pwl_constraints!(model, NT, NG, NS, units)
    add_transmission_constraints!(model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, gsdf, config_param, ND2, DataCentras)
    add_storage_constraints!(model, NT, NC, NS, config_param, psses)
    add_datacentra_constraints!(model, NT, NS, config_param, ND2, DataCentras)
    add_frequency_constraints!(model, NT, NG, NC, NS, units, psses, config_param, contingency_size)

    optimize!(model)
    assert_is_solved_and_feasible(model)
    println("\n====================================================")
    println("Fast extensive-form convergence achieved")
    println("FINAL OBJECTIVE:    ", objective_value(model))
    println("FINAL BEST BOUND:   ", objective_bound(model))
    println("FINAL RELATIVE GAP: ", relative_gap(model))
    println("====================================================")
    return model
end

# Execute the multiple-cut Benders Decomposition algorithm to solve the problem
if get(ENV, "BENDERS_FAST_DIRECT_SOLVE", "0") == "1"
    solve_fast_extensive_uc(NT, NB, NG, ND, NC, ND2, NS, NW, NL, units, loads, winds, lines, DataCentras, psses, config_param, 1.0 / NS)
else
    multiple_bender_decomposition_scuc(
        scuc_masterproblem, scuc_subproblem, master_model_struct, batch_sub_model_struct_dic,
        winds, config_param, NG, NT, NW, ND, NL;
        jensen_subproblem_struct = jensen_subproblem_struct,
    )
end
