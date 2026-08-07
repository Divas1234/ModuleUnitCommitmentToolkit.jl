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

# Activate the current project environment (if pkg directory exists and is valid)
# Otherwise, use the default project environment
if isdir("pkg") && isfile(joinpath("pkg", "Project.toml"))
	try
		Pkg.activate("pkg")
	catch
		# If activation fails, continue with current environment
		nothing
	end
end

# ============================================================================
# Package Dependencies
# ============================================================================
# List of required packages (removed duplicates)
neededPackages = [
	# Optimization
	:JuMP,
	:Gurobi,
	# Data handling
	:DataFrames,
	:CSV,
	:XLSX,
	:DelimitedFiles,
	:JLD,
	# Statistics and analysis
	:Distributions,
	:MultivariateStats,
	:Clustering,
	:StatsPlots,
	# Visualization
	:Plots,
	:UnicodePlots,
	:LaTeXStrings,
	# Utilities
	:Revise,
	:Test,
	:Random,
	:DataStructures
]

# Automatically install missing packages
for neededpackage in neededPackages
	package_name = String(neededpackage)
	if !(package_name in keys(Pkg.project().dependencies))
		println("Installing missing package: $package_name")
		Pkg.add(package_name)
	end
end

# ============================================================================
# Package Imports
# ============================================================================
using Revise
using JuMP
using Gurobi
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
