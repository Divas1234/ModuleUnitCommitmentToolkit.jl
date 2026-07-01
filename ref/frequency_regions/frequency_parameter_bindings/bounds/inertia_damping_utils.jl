using Pkg
Pkg.activate(".Pkg/")

neededPackages = [:FileIO, :LinearAlgebra, :Random, :GLM, :Plots, :DelimitedFiles, :GeometryBasics, :QHull, :Printf]

# Ensure all required packages are available in the active environment.
for neededpackage in neededPackages
    (String(neededpackage) in keys(Pkg.project().dependencies)) || Pkg.add(String(neededpackage))
    # @eval using $neededpackage
end

using Plots, PlotThemes
using LinearAlgebra

gr()
# theme(:wong2)

include("boundary.jl")
include("inertia_response.jl")
include("primary_frequency_response.jl")
include("analytical_frequency_response.jl")
include("inertia_damping_regression.jl")
# include("visualizations.jl")
include("converter_config.jl")
include("generate_geometries.jl")
# include("plot_polygon_figures.jl")

# Shared constants
const DAMPING_RANGE = 2:0.25:15
const MIN_DAMPING = minimum(DAMPING_RANGE)
const MAX_DAMPING = maximum(DAMPING_RANGE)

# Constants for formula scaling
const PERCENTAGE_BASE = 100
const FREQUENCY_BASE = 50
current_filepath = pwd()
# const OUTPUT_REL_PATH = joinpath(current_filepath, "\\res\\all_vertices.txt")
const OUTPUT_REL_PATH = "res/all_vertices.txt"
