using Pkg
if Sys.iswindows()
    Pkg.activate("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\.pkg")
elseif Sys.isapple()
    Pkg.activate("/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/eacharea_BFSFR/.pkg/")
end

Pkg.add(["DelimitedFiles", "Random", "Plots", "PlotThemes", "LaTeXStrings", "Distributions", "StatsPlots", "XLSX", "MAT"])
# Plots, DelimitedFiles, LaTeXStrings, PlotThemes
# Distributions, Plots, StatsPlots
using DelimitedFiles, Random, Plots, Colors, PlotThemes, LaTeXStrings, Distributions, StatsPlots, XLSX, MAT

using CSV
using DataFrames

# plotlyjs()
# gaston()
# pgfplotsx()
# pythonplot()
gr()
Random.seed!(1234)
include("BFLib_consideringFRlimit.jl")
include("calcualte_SFRresult.jl")
include("draw_SFRcurve.jl")
include("CASE1_draw_PDFinfomation.jl")
include("draw_SFRsurface.jl")
include("batch_dataclean_utils.jl")
include("get_batch_frequency_datafreames.jl")

# include("CASE1_draw_SFRcurve.jl")
