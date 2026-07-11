using Pkg
Pkg.activate("./.pkg")

# List of required packages
required_pkgs = ["Revise", "JuMP", "Gurobi", "Test", "DelimitedFiles", "LaTeXStrings", "Plots", "DataFrames", "Clustering", "StatsPlots"]

# Install any missing packages
for pkg in required_pkgs
    if !haskey(Pkg.installed(), pkg)
        Pkg.add(pkg)
    end
end

# Now import the packages
for pkg in required_pkgs
    @eval using $(Symbol(pkg))
end

# using JuliaFormatter
# plotlyjs()
gr()
using Random
Random.seed!(1234)
include("formatteddata.jl")
include("renewableenergysimulation.jl")
include("showboundrycase.jl")
include("readdatafromexcel.jl")
include("SUCuccommitmentmodel.jl")
include("FCUCuccommitmentmodel.jl")
# includec/casesploting.jl")
include("showboundrycase.jl")
include("creatfrequencyconstraints.jl")
include("saveresult.jl")
include("BFLib_consideringFRlimit.jl")
include("enhance_FCUCuccommitmentmodel_withFCR.jl")
include("enhance_FCUCuccommitmentmodel_withoutFCR.jl")
include("generatefittingparameters.jl")
include("draw_onlineactivepowerbalance.jl")
include("cal_Diffaggregatedfrequencyparameters.jl")
include("draw_addditionalpower.jl")
include("new_BFLib_consideringFRlimit.jl")
