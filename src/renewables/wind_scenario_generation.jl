using Distributions
using Random

"""
`generate_wind_scenarios(WindsFreqParam, mode; scenario_limit=50)`

Build wind availability scenarios and attach frequency-control parameters.
`mode == 1` generates Weibull-noise scenarios around the default profile;
other modes use fixed benchmark scenarios.
"""
function generate_wind_scenarios(WindsFreqParam, mode, NT::Int64 = 24; scenario_limit::Int64 = 50, seed::Int64 = 123)
    index, locatebus, NW, p_max, base_profile = default_wind_farm_config(NT)
    scenarios_curve = if mode == 1
        generate_weibull_wind_availability(base_profile, scenario_limit, NT; seed = seed)
    else
        copy(FIXED_WIND_AVAILABILITY_SCENARIOS)
    end

    scenarios_nums = size(scenarios_curve, 1)
    scenarios_prob = 1.0 / scenarios_nums
    winds = wind(
        index,
        locatebus,
        p_max,
        scenarios_prob,
        scenarios_nums,
        scenarios_curve,
        vec(WindsFreqParam[:, 1]),
        vec(WindsFreqParam[:, 2]),
        vec(WindsFreqParam[:, 3]),
        vec(WindsFreqParam[:, 4]),
        vec(WindsFreqParam[:, 5]),
        vec(WindsFreqParam[:, 6]),
    )
    return winds, NW
end

function generate_weibull_wind_availability(base_profile::AbstractMatrix, scenario_count::Int64, NT::Int64; seed::Int64 = 123)
    scenario_count > 0 || throw(ArgumentError("scenario_limit must be positive; got $(scenario_count)"))
    rng = MersenneTwister(seed)
    noise = reshape(rand(rng, Weibull(), scenario_count * NT), scenario_count, NT) .* 0.01
    signs = ifelse.(rand(rng, scenario_count, NT) .> 0.5, 1.0, -1.0)
    return clamp.(repeat(base_profile, scenario_count, 1) .+ signs .* noise, 0.0, 1.0)
end

genscenario(WindsFreqParam, flag, NT::Int64 = 24; scenario_limit::Int64 = 50) =
    generate_wind_scenarios(WindsFreqParam, flag, NT; scenario_limit = scenario_limit)
