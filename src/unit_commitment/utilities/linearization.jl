# linearization
function linearizationfuelcurve(units, NG; num_segments::Integer = 3)
    nseg = max(1, Int(num_segments))
    linearpower_limits = (units.p_max - units.p_min) ./ nseg
    cost = zeros(NG, nseg + 1)
    temp = units.p_min
    cost[:, 1] = units.coeff_a .* (units.p_min .^ 2) + units.coeff_b .* units.p_min + units.coeff_c
    for i in 2:(nseg + 1)
        temp = temp + linearpower_limits
        cost[:, i] = units.coeff_a .* (temp .^ 2) + units.coeff_b .* temp + units.coeff_c
    end
    eachslope = zeros(NG, nseg)
    for i in 1:nseg
        # Some public MATPOWER cases contain zero-capacity placeholder units.
        # Their linearization segments have zero width, so assign a zero
        # slope instead of creating NaN/Inf coefficients in the JuMP objective.
        for g in 1:NG
            eachslope[g, i] = linearpower_limits[g] > eps(Float64) ?
                (cost[g, i + 1] - cost[g, i]) / linearpower_limits[g] : 0.0
        end
    end
    return cost[:, 1], eachslope'
end
