using JuMP

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
        model::Model, NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, NW::Int64, units::unit, loads::load,
        winds::wind, lines::transmissionline, DataCentras::data_centra, psses::pss, config_param::config, onoffinit, gsdf, contingency_size;
        include_unit_operation = true, include_binary_logic_for_storage = true, include_frequency_constraints = true, winds_for_freq = winds)
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
    transmission_constrs = add_transmission_constraints!(
        model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, gsdf, config_param, ND2, DataCentras)

    # 9. Energy Storage (BESS) Module
    storage_constrs = if config_param.is_ConsiderBESS == 1
        add_storage_constraints!(model, NT, NC, NS, config_param, psses; include_binary_logic = include_binary_logic_for_storage)
    else
        nothing
    end

    # 10. Data Center Module
    datacentra_constrs = if config_param.is_ConsiderDataCentra == 1
        add_datacentra_constraints!(model, NT, NS, config_param, ND2, DataCentras)
    else
        nothing
    end

    # 11. Frequency Control Module
    freq_constrs = if config_param.is_ConsiderFrequencyControl == 1 && include_frequency_constraints
        add_frequency_constraints!(model, NT, NG, NC, NS, units, psses, config_param, contingency_size; winds = winds_for_freq)
    else
        nothing
    end

    return (unit_operation = unit_op_constrs, curtailment = curtailment_constrs, generator_power = gen_power_constrs,
        reserve = reserve_constrs, power_balance = power_balance_constrs, ramp = ramp_constrs, pwl = pwl_constrs,
        transmission = transmission_constrs, storage = storage_constrs, datacentra = datacentra_constrs, frequency = freq_constrs)
end
