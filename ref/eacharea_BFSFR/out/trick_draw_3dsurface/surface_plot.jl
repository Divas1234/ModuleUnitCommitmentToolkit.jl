# Import the Makie package for plotting
# using CairoMakie
# using ColorSchemes
using Pkg
Pkg.activate("./.pkg/")
using DataFrames
using CSV
using LinearAlgebra
using VegaLite

df1 = CSV.read("data.csv", DataFrame; delim = '\t', header = false)
df2 = CSV.read("data1.csv", DataFrame; delim = '\t', header = false)
