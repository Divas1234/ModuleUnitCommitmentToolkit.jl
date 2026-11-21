using JuMP

const _UC_CONSTRAINT_HOOKS = Pair{Symbol, Function}[]
const _UC_VARIABLE_HOOKS = Pair{Symbol, Function}[]
const _UC_OBJECTIVE_HOOKS = Pair{Symbol, Function}[]

function _register_uc_hook!(registry::Vector{Pair{Symbol, Function}}, name::Symbol, hook::Function)
    idx = findfirst(entry -> first(entry) === name, registry)
    if idx === nothing
        push!(registry, name => hook)
    else
        registry[idx] = name => hook
    end
    return name
end

"""
    register_uc_constraint_hook!(name::Symbol, hook::Function)

Register an extension constraint builder invoked at the end of `apply_scuc_constraints!`.
`hook` receives `(model, ctx)` where `ctx` is a NamedTuple of model dimensions, data
structures, and `config_param`, and may return constraint references to be stored under
`result.extensions[name]`.
"""
register_uc_constraint_hook!(name::Symbol, hook::Function) = _register_uc_hook!(_UC_CONSTRAINT_HOOKS, name, hook)
registered_uc_constraint_hooks() = Symbol[first(entry) for entry in _UC_CONSTRAINT_HOOKS]
function clear_uc_constraint_hooks!()
    empty!(_UC_CONSTRAINT_HOOKS)
    return nothing
end

"""
    register_uc_variable_hook!(name::Symbol, hook::Function)

Register a custom variable builder invoked at the end of `define_decision_variables!`.
`hook` receives `(model, ctx)` where `ctx` contains model dimensions and `config_param`.
"""
register_uc_variable_hook!(name::Symbol, hook::Function) = _register_uc_hook!(_UC_VARIABLE_HOOKS, name, hook)
registered_uc_variable_hooks() = Symbol[first(entry) for entry in _UC_VARIABLE_HOOKS]
function clear_uc_variable_hooks!()
    empty!(_UC_VARIABLE_HOOKS)
    return nothing
end

"""
    register_uc_objective_hook!(name::Symbol, hook::Function)

Register a custom objective term builder invoked after `set_objective_economic!`.
`hook` receives `(model, ctx)` and may return an additive JuMP expression to add to the
minimization objective (or `nothing` if it modifies the objective in place).
"""
register_uc_objective_hook!(name::Symbol, hook::Function) = _register_uc_hook!(_UC_OBJECTIVE_HOOKS, name, hook)
registered_uc_objective_hooks() = Symbol[first(entry) for entry in _UC_OBJECTIVE_HOOKS]
function clear_uc_objective_hooks!()
    empty!(_UC_OBJECTIVE_HOOKS)
    return nothing
end

function clear_all_uc_hooks!()
    clear_uc_variable_hooks!()
    clear_uc_objective_hooks!()
    clear_uc_constraint_hooks!()
    return nothing
end

"""
    apply_scuc_constraints!(...)

Applies security-constrained unit commitment (SCUC) constraints modularly to the given JuMP model.
Conditional logic is applied based on config_param flags.

# Returns
A NamedTuple containing the constraint references or sub-tuples of constraint references:
- `unit_operation`
- `curtailment`
- `generator_power`
- `reserve`
- `power_balance`
- `ramp`
- `pwl`
- `transmission`
- `storage`
- `datacentra`
- `frequency`
"""
function apply_scuc_constraints!(
    model::Model,
    NT::Int64,
    NB::Int64,
    NL::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NS::Int64,
    NW::Int64,
    units::unit,
    loads::load,
    winds::wind,
    lines::transmissionline,
    data_centers::DataCenters,
    psses::pss,
    config_param::config,
    onoffinit,
    gsdf,
    contingency_size;
    include_unit_operation = true,
    include_binary_logic_for_storage = true,
    include_frequency_constraints = true,
    winds_for_freq = winds,
)
    # 1. Unit Operation (Commitment logic, min up/down time, shutup/shutdown cost)
    unit_op_constrs = if include_unit_operation
        add_unit_operation_constraints!(model, NT, NG, units, onoffinit)
    else
        nothing
    end

    # 2. Wind and Load Curtailments
    curtailment_constrs = add_curtailment_constraints!(model, NT, ND, NW, NS, loads, winds)

    # 3. Generator Power Limits
    gen_power_constrs = add_generator_power_constraints!(model, NT, NG, NS, units)

    # 4. System Reserves
    reserve_constrs = add_reserve_constraints!(model, NT, NG, NC, NS, units, loads, winds, config_param)

    # 5. Power Balance Constraints
    power_balance_constrs = add_power_balance_constraints!(model, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)

    # 6. Generator Ramp-up / Ramp-down
    ramp_constrs = add_ramp_constraints!(model, NT, NG, NS, units, onoffinit)

    # 7. Piecewise Linearization of Generator Costs
    pwl_constrs = add_pwl_constraints!(model, NT, NG, NS, units)

    # 8. Transmission Line Limits
    transmission_constrs =
        add_transmission_constraints!(model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, gsdf, config_param, ND2, data_centers)

    # 9. Energy Storage (BESS) Module
    storage_constrs = if config_param.consider_bess == 1
        add_storage_constraints!(model, NT, NC, NS, config_param, psses; include_binary_logic = include_binary_logic_for_storage)
    else
        nothing
    end

    # 10. Data Center Module
    data_center_constrs = if config_param.consider_data_center == 1
        add_data_center_constraints!(model, NT, NS, config_param, ND2, data_centers)
    else
        nothing
    end

    # 11. Frequency Control Module
    freq_constrs = if config_param.consider_frequency_control == 1 && include_frequency_constraints
        add_frequency_constraints!(model, NT, NG, NC, NS, units, psses, config_param, contingency_size; winds = winds_for_freq)
    else
        nothing
    end

    # 12. Pluggable extension constraint hooks
    extension_constrs = Dict{Symbol, Any}()
    if !isempty(_UC_CONSTRAINT_HOOKS)
        ctx = (
            NT = NT, NB = NB, NL = NL, NG = NG, ND = ND, NC = NC, ND2 = ND2, NS = NS, NW = NW,
            units = units, loads = loads, winds = winds, lines = lines,
            data_centers = data_centers, psses = psses, config_param = config_param,
            onoffinit = onoffinit, gsdf = gsdf, contingency_size = contingency_size,
        )
        for (hook_name, hook_fn) in _UC_CONSTRAINT_HOOKS
            extension_constrs[hook_name] = hook_fn(model, ctx)
        end
    end

    return (
        unit_operation = unit_op_constrs,
        curtailment = curtailment_constrs,
        generator_power = gen_power_constrs,
        reserve = reserve_constrs,
        power_balance = power_balance_constrs,
        ramp = ramp_constrs,
        pwl = pwl_constrs,
        transmission = transmission_constrs,
        storage = storage_constrs,
        datacentra = data_center_constrs,
        frequency = freq_constrs,
        extensions = extension_constrs,
    )
end
