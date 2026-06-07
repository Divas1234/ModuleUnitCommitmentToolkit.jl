"""
`wind`

Data structure for wind plants, stochastic availability scenarios, and wind
frequency-control parameters.
"""
struct wind
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

	function wind(index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw)
		return new(index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw)
	end
end

const Wind = wind
