function add_qss_frequency_constraints!(
    scuc::Model,
    NT::Int64,
    NG::Int64,
    NS::Int64,
    units,
    x,
    qss_limit_hz::Float64;
    contingency::Union{Nothing, Real} = nothing,
    f0_hz::Float64 = frequency_env_float("FREQUENCY_BASE_HZ", 50.0),
)
    if !haskey(JuMP.object_dictionary(scuc), :sr⁺)
        return nothing
    end
    sr_pos = scuc[:sr⁺]
    rhs_contingency = contingency === nothing ? frequency_contingency_size(units, maximum(units.p_max)) : Float64(contingency)
    damping_pu = qss_limit_hz / max(f0_hz, eps(Float64))
    return @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        sum(sr_pos[(s - 1) * NG + i, t] for i in 1:NG) +
        sum(safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in 1:NG) * damping_pu >=
        rhs_contingency
    )
end

function add_sfr_reserve_constraints!(scuc::Model, NT::Int64, NG::Int64, NS::Int64, units, x, nadir_limit_hz::Float64, fcr_threshold::Float64)
    if !haskey(JuMP.object_dictionary(scuc), :sr⁺)
        return nothing
    end
    sr_pos = scuc[:sr⁺]
    return @constraint(
        scuc,
        [s = 1:NS, t = 1:NT, i = 1:NG],
        sr_pos[(s - 1) * NG + i, t] >= unit_primary_response_coeff(units, i) * nadir_limit_hz * fcr_threshold * x[i, t]
    )
end
