using JuMP,
    MathOptInterface,
    Gurobi,
    Test,
    DelimitedFiles,
    LaTeXStrings,
    JLD2,
    DataFrames,
    Clustering,
    Distributions,
    CSV,
    Random,
    MultivariateStats,
    DataStructures

# Plotting backends are loaded by the visualization scripts that need them.
# Importing Plots here pulls GR and FFMPEG during `using ModuleUnitCommitmentToolkit`
# and prevents the solver from loading when those optional libraries fail.
Random.seed!(1234)

println("\t\u2192 The [JULIA] environment_config has been loaded.")
# println("\n\n\n")
