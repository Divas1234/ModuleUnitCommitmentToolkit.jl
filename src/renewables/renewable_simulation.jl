# Renewable Energy (Wind) Simulation and Scenario Generation
using Distributions

"""
`wind`

Data structure for wind power plants, including stochastic scenario data and frequency regulation parameters.
Support for two primary frequency control modes:

 1. Droop Control (Model-1)
 2. Virtual Inertia Machine (Model-2)
"""
struct wind
	index::Vector{Int64}          # Wind farm identifier
	locatebus::Vector{Int64}      # Electrical bus location
	p_max::Vector{Float64}        # Installed capacity / Maximum power output
	scenarios_prob::Float64       # Probability associated with each scenario
	scenarios_nums::Int64         # Total number of stochastic scenarios
	scenarios_curve::Array{Float64} # Time-series power output matrix (Scenarios x Time)

	# Frequency Control Parameters (Renewable Energy)
	Fcmode::Vector{Float64}       # Control mode flag: 1 for Droop, 2 for Virtual Inertia

	# Model-1 (Droop Control): Kw / (Rw * (1 + sTw))
	Kw::Vector{Float64}           # Gain coefficient for droop control
	Rw::Vector{Float64}           # Droop regulation coefficient

	# Model-2 (Virtual Inertia Machine): (sMw + Dw) / (1 + sTw)
	Mw::Vector{Float64}           # Virtual inertia coefficient
	Dw::Vector{Float64}           # Virtual damping coefficient (p.u.)
	Tw::Vector{Float64}           # Frequency control time constant (s)

	"""
	   Validates parameter consistency based on the selected frequency control mode.
	   """
	function checkvaildity(Fcmode)
		if Fcmode == 1
			if Kw != 0 || Rw != 0
				println("Parameter mismatch for Droop Control (Fcmode-1)")
			end
		end
		return if Fcmode == 2
			if Kw != 0 || Rw != 0
				println("Parameter mismatch for Virtual Inertia (Fcmode-2)")
			end
		end
	end

	function wind(
			index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw,
	)
		return new(
			index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, Fcmode, Kw, Rw, Mw, Dw, Tw,
		)
	end
end

# --- Default Initialization and Base Curves ---
"""
	add_windfarms_config()

Configures default parameters for wind farms, including identifiers, bus locations, capacity limits, and typical power output curves.

# Returns

  - `index`: Wind farm index vector
  - `locatebus`: Bus location vector for wind farm interconnection
  - `NW`: Number of wind farms
  - `p_max`: Rated capacity for each wind farm (per-unit value)
  - `scenarios_curvebase`: Normalized typical daily wind power output curve (1×24 matrix)
"""
function add_windfarms_config()
	# Wind farm indices: assuming 2 wind farms in the system
	index = [1; 2]
	# Bus location: both wind farms connected to bus 1 (simplified test system configuration)
	locatebus = [1; 1]
	# Get total number of wind farms
	NW = length(index)
	# Optimization horizon: 24 hours for typical daily dispatch
	NT = 24 # Optimization horizon (24 hours)

	# Rated capacity: 0.5 p.u. per wind farm (relative to system base capacity)
	# Note: cap array length is 5 to satisfy dimension requirements for subsequent ones() operation
	cap = [0.5] * 5
	# Expand to NW×1 matrix, each row corresponds to one wind farm's capacity
	p_max = cap .* ones(NW, 1)
	# Extract first column and convert to vector form
	p_max = p_max[:, 1]

	# Base wind power normalized output curve (typical daily 24-hour data)
	# Value range 0.3~0.5, corresponding to daily periodicity of wind speed variations
	# 4×6 matrix with 24 data points, representing typical power values at different time periods
	scenarios_curvebase = [0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300
						   0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042
						   0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410
						   0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982] * 1.0
	# Reshape to 1×NT matrix for subsequent scenario operations and probability weighting
	scenarios_curvebase = reshape(scenarios_curvebase, 1, NT)

	return index, locatebus, NW, p_max, scenarios_curvebase
end

"""
`genscenario(WindsFreqParam, flag)`

Generates stochastic wind power scenarios by adding probabilistic noise to a base profile.

# Arguments

  - `WindsFreqParam`: Matrix containing control modes and parameters.
  - `flag`: 1 for random Weibull-based scenario generation; 0 for fixed predefined scenarios.

# Returns

A tuple containing the `wind` struct and the number of wind units `NW`.
"""
function genscenario(WindsFreqParam, flag, NT = 24; scenario_limit::Int64 = 50)
	index, locatebus, NW, p_max, scenarios_curvebase = add_windfarms_config()

	if flag == 1
		# Generate a single scenario with Weibull distribution noise scaled by 0.01 (1%)
		rand(123) # Fixed seed for reproducibility
		scenarios_nums = scenario_limit
		sample_sets = rand(Weibull(), scenarios_nums * NT) * 0.01
		scenarios_curve, scenarios_error = reshape(sample_sets, scenarios_nums, NT),
		reshape(sample_sets, scenarios_nums, NT)

		for i ∈ 1:scenarios_nums
			for j ∈ 1:NT
				sample_temp = rand()
				# Randomly add or subtract noise from the base curve
				if sample_temp > 0.5
					scenarios_curve[i, j] = scenarios_curvebase[1, j] + scenarios_error[i, j]
				else
					scenarios_curve[i, j] = scenarios_curvebase[1, j] - scenarios_error[i, j]
				end
			end
		end
	else
		# Use predefined fixed scenarios for deterministic evaluation or specific test cases
		scenarios_nums = Int64(1)
		scenarios_curve = [0.440724927203680 0.420965256587272 0.449034794022911 0.454128108336623 0.436483077739172 0.477450522402300 0.443871634609799 0.374756446192485 0.448192193924943 0.431190577826877 0.428867647037057 0.445673091565042 0.433764408789611 0.421900481861469 0.429104412188035 0.463277796146724 0.426579282372516 0.448189506134410 0.429353980231385 0.434861266141317 0.437494540514197 0.456877055120346 0.425139803090161 0.425629623577982
						   0.438145251438362 0.451595831499290 0.434476599311993 0.419306858427854 0.439299123016117 0.402675152643531 0.436348294887821 0.447513027575036 0.445276832579360 0.408448500875771 0.476106019486472 0.451932867123187 0.446968204950444 0.457706023689642 0.454429491703142 0.432489551344388 0.460269791720502 0.417994780067730 0.404420416693225 0.443013967794901 0.407382847053778 0.430503777173583 0.455183618944849 0.443789093804304
						   0.441672518788126 0.461922845597782 0.425338820890952 0.420366090471607 0.411612893296905 0.435840069094316 0.443930499695973 0.457511112047526 0.450817300160177 0.396413160907573 0.441068179613219 0.432401166117165 0.420639320150678 0.443835529493502 0.433537192471826 0.427399090347307 0.417573417186437 0.422905158624658 0.467119379846108 0.500219495833784 0.432716758754643 0.422622895486611 0.452734491278974 0.425638923917095
						   0.404454468849607 0.427898443023513 0.456678201304931 0.466227716201764 0.458275535897303 0.447722201714402 0.430408791524416 0.457075404497126 0.422560643262941 0.479016292670867 0.440735317418680 0.426724520859767 0.438876736399005 0.427232619437777 0.431855284702541 0.436026678964276 0.463231975065251 0.449494208561186 0.440539555865053 0.430643201150598 0.463252275085078 0.426482114000725 0.450319628567473 0.447144352980500
						   0.475002833720225 0.437617623292143 0.434471584469213 0.439971226562153 0.454329370050504 0.436312054145452 0.445440779281991 0.463144009687827 0.433153030072578 0.484931467718911 0.413222836444571 0.443268354334839 0.459751329710262 0.449325345517610 0.451073618934457 0.440806883197305 0.432345533655294 0.461416346612016 0.458566667364229 0.391262069079400 0.459153578592304 0.463514158218735 0.416622458118542 0.457798005720119]
	end

	# Calculate final probabilities and extract control parameters
	scenarios_prob = 1 / scenarios_nums
	FCmode = WindsFreqParam[:, 1]
	KW = WindsFreqParam[:, 2]
	RW = WindsFreqParam[:, 3]
	MW = WindsFreqParam[:, 4]
	DW = WindsFreqParam[:, 5]
	TW = WindsFreqParam[:, 6]

	scenarios_nums = size(scenarios_curve, 1)

	# Instantiate the wind data structure
	winds = wind(
		index, locatebus, p_max, scenarios_prob, scenarios_nums, scenarios_curve, FCmode, KW, RW, MW, DW, TW,
	)

	return winds, NW
end
