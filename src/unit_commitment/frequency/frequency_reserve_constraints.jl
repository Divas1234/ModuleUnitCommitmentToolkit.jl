function add_qss_frequency_constraints!(scuc::Model, NT::Int64, NG::Int64, NS::Int64, units, x, qss_limit_hz::Float64)
    if !haskey(JuMP.object_dictionary(scuc), :sr⁺)
        return nothing
    end
    sr_pos = scuc[:sr⁺]
    return @constraint(scuc, [s = 1:NS, t = 1:NT],
        sum(sr_pos[(s - 1) * NG + i, t] for i ∈ 1:NG) +
        sum(safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i ∈ 1:NG) * qss_limit_hz >=
        frequency_contingency_size(units, 0.0))
end

function add_sfr_reserve_constraints!(scuc::Model, NT::Int64, NG::Int64, NS::Int64, units, x, nadir_limit_hz::Float64, fcr_threshold::Float64)
    if !haskey(JuMP.object_dictionary(scuc), :sr⁺)
        return nothing
    end
    sr_pos = scuc[:sr⁺]
    return @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG],
        sr_pos[(s - 1) * NG + i, t] >= unit_primary_response_coeff(units, i) * nadir_limit_hz * fcr_threshold * x[i, t])
end
