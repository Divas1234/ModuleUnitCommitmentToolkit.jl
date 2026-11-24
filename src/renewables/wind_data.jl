"""
`WindUnits` (legacy aliases: `wind`, `Wind`)

Data structure for wind plants, stochastic availability scenarios, and wind
frequency-control parameters.
"""
mutable struct WindUnits
    index::Vector{Int64}
    locatebus::Vector{Int64}
    p_max::Vector{Float64}
    scenarios_prob::Float64
    scenarios_nums::Int64
    scenarios_curve::Array{Float64}
    Fcmode::Vector{Float64}
    Kw::Vector{Float64}
    Rw::Vector{Float64}
    Mw::Vector{Float64}
    Dw::Vector{Float64}
    Tw::Vector{Float64}
    area::Vector{Int}

    function WindUnits(
        index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve,
        Fcmode, Kw, Rw, Mw, Dw, Tw;
        area = ones(Int, length(index)),
    )
        return new(index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw, Int.(area))
    end
end

const wind = WindUnits
const Wind = WindUnits
