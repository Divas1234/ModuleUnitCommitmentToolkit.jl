using Revise,
    JuMP,
    MathOptInterface,
    Gurobi,
    Test,
    DelimitedFiles,
    LaTeXStrings,
    Plots,
    JLD2,
    DataFrames,
    Clustering,
    StatsPlots,
    Distributions,
    CSV,
    Random,
    DataFrames,
    MultivariateStats,
    DataStructures

gr()
Random.seed!(1234)

println("\t\u2192 The [JULIA] environment_config has been loaded.")
# println("\n\n\n")
