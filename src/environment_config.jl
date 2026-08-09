# ============================================================================
# Environment configuration module.
#
# This module handles:
# - Package dependency management
# - Package imports
# - Global configuration settings (random seed, plotting backend, etc.)
#
# Dependencies (automatically installed if not present):
# - Optimization: JuMP, Gurobi
# - Data handling: DataFrames, CSV, XLSX, DelimitedFiles, JLD
# - Statistics: Distributions, MultivariateStats, Clustering, StatsPlots
# - Visualization: Plots, UnicodePlots, LaTeXStrings
# - Utilities: Revise, Test, Random, DataStructures
# ============================================================================

using Pkg

# Use active project environment if specified, otherwise activate current directory
if !isfile(Base.active_project())
    if isdir("pkg") && isfile(joinpath("pkg", "Project.toml"))
        try
            Pkg.activate("pkg")
        catch
            nothing
        end
    end
end

# ============================================================================
# Package Dependencies
# ============================================================================
# List of required packages (removed duplicates)
neededPackages = [
    # Optimization
    :JuMP, :Gurobi,
    # Data handling
    :DataFrames, :CSV, :XLSX, :DelimitedFiles, :JLD,
    # Statistics and analysis
    :Distributions, :MultivariateStats, :Clustering, :StatsPlots,
    # Visualization
    :Plots, :UnicodePlots, :LaTeXStrings,
    # Utilities
    :Revise, :Test, :Random, :DataStructures]

# Automatically install missing packages
for neededpackage ∈ neededPackages
    package_name = String(neededpackage)
    if !(package_name in keys(Pkg.project().dependencies))
        println("Installing missing package: $package_name")
        Pkg.add(package_name)
    end
end

# ============================================================================
# Package Imports
# ============================================================================
try
    using Revise
catch
    # Revise is optional for interactive REPL development
end
using JuMP
const HAS_GUROBI = try
    using Gurobi: Gurobi
    # Test if Gurobi can load its library
    Gurobi.Env()
    true
catch
    false
end

if HAS_GUROBI
    using Gurobi
else
    using GLPK
end
using Test
using DelimitedFiles
using LaTeXStrings
using Plots
using JLD
using DataFrames
using Clustering
using StatsPlots
using Distributions
using CSV
using Random
using MultivariateStats
using DataStructures

# ============================================================================
# Global Configuration
# ============================================================================
# Set plotting backend
gr()

# Set random seed for reproducibility
Random.seed!(1234)

println("\t→ The [JULIA] environment_config has been loaded.")
