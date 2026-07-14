# Central include point for renewable resource data and scenario generation.

if !isdefined(@__MODULE__, :_RENEWABLES_INCLUDED)
    const _RENEWABLES_INCLUDED = true

    include("wind_data.jl")
    include("wind_profiles.jl")
    include("wind_scenario_generation.jl")

    println("\t→ the renewable energy curves module loaded.")
end
