using JuMP,
    MathOptInterface,
    Gurobi,
    DelimitedFiles,
    DataFrames,
    Distributions,
    CSV,
    Random,
    DataStructures

# Plotting backends are loaded by the visualization scripts that need them.
# Importing Plots here pulls GR and FFMPEG during `using ModuleUnitCommitmentToolkit`
# and prevents the solver from loading when those optional libraries fail.
if lowercase(strip(get(ENV, "MODULE_UC_SEED_RNG", "0"))) in ("1", "true", "yes", "y", "on")
    Random.seed!(1234)
end

if lowercase(strip(get(ENV, "MODULE_UC_VERBOSE_LOAD", "0"))) in ("1", "true", "yes", "y", "on")
    println("\t\u2192 The [JULIA] environment_config has been loaded.")
end
