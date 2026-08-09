"""
`add_frequency_constraints!(...)`

Adds linear frequency-security constraints to the UC model.
"""
function add_frequency_constraints!(scuc::Model, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency; winds = nothing)
    if config_param.is_ConsiderFrequencyControl == 0
        println("\t constraints: 13) frequency control constraints skipped (is_ConsiderFrequencyControl != 1)")
        return nothing
    end

    if !haskey(JuMP.object_dictionary(scuc), :x)
        println("\t constraints: 13) frequency control constraints skipped (x not defined)")
        return nothing
    end

    x = scuc[:x]
    frequency_base_hz = frequency_env_float("FREQUENCY_BASE_HZ", 50.0)
    rocof_limit_hz_per_s = frequency_env_float("FREQUENCY_ROCOF_LIMIT_HZ_PER_S", 5.0)
    qss_limit_hz = frequency_env_float("FREQUENCY_QSS_LIMIT_HZ", 5.0)
    nadir_limit_hz = frequency_env_float("FREQUENCY_NADIR_LIMIT_HZ", qss_limit_hz)
    fcr_threshold = frequency_env_float("FREQUENCY_FCR_THRESHOLD", 0.025)

    contingency = frequency_contingency_size(units, Δp_contingency)
    imbalance_scaling = max(frequency_env_float("FREQUENCY_IMBALANCE_SCALING", 1.0), eps(Float64))
    frequency_nadir_limit = max(nadir_limit_hz, eps(Float64))

    thermal_inertia = @expression(scuc, [t = 1:NT],
        sum(safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i ∈ 1:NG))
    wind_capacity_support = wind_frequency_capacity_support(winds)
    sum_apparent_power = frequency_sum_apparent_power(units, winds)
    sum_unit_capacity = max(sum(units.p_max), eps(Float64))
    nadir_fit_contingency = frequency_nadir_fit_contingency(units, contingency)
    nadir_coefficients = frequency_nadir_fitting_parameters(units, winds, nadir_fit_contingency)
    nadir_cut_count = size(nadir_coefficients, 1)
    nadir_inertia_term = @expression(scuc, [t = 1:NT],
        (sum(safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i ∈ 1:NG) + wind_capacity_support.inertia) /
        sum_apparent_power)
    nadir_fg_response_term = @expression(scuc, [t = 1:NT],
        sum(unit_turbine_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i ∈ 1:NG) / sum_unit_capacity)
    nadir_primary_term = @expression(scuc, [t = 1:NT],
        sum(unit_primary_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i ∈ 1:NG) / sum_unit_capacity)

    rocof_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
        wind_capacity_support.inertia + 2.0 * thermal_inertia[t] >= contingency * frequency_base_hz / rocof_limit_hz_per_s * sum_apparent_power)
    nadir_constr = @constraint(scuc, [k = 1:nadir_cut_count, s = 1:NS, t = 1:NT],
        nadir_coefficients[k, 1] * nadir_inertia_term[t] +
        nadir_coefficients[k, 2] * nadir_fg_response_term[t] +
        nadir_coefficients[k, 3] * nadir_primary_term[t] +
        nadir_coefficients[k, 4] <= frequency_nadir_limit * imbalance_scaling)
    qss_constr = add_qss_frequency_constraints!(scuc, NT, NG, NS, units, x, qss_limit_hz)
    sfr_constr = add_sfr_reserve_constraints!(scuc, NT, NG, NS, units, x, frequency_nadir_limit, fcr_threshold)

    println("\t constraints: 13) frequency control constraints\t\t\t done")
    return (rocof = rocof_constr, qss = qss_constr, nadir = nadir_constr, sfr = sfr_constr)
end
