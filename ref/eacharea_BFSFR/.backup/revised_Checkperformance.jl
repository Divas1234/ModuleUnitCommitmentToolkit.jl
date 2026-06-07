include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
include("src/automatic_workflow_SFRcalculations.jl")

if Sys.iswindows()
	figpath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\"
elseif Sys.isapple()
	figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/"
end
# figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/"

# NOTE - testing BF-SFR performance in different filter numbers.

whitenoise_parameter = 1e-3
fcr_selected_threshold = 100 # completed slacked
δf_positor, δf_actual, δf_samplieddata = simulate(
	generate_data, particle_filter, 100, 60, 1, 1, 0, 1234, whitenoise_parameter, fcr_selected_threshold)

Plots.plot(δf_positor * 0.5)

using BenchmarkTools

@benchmark sort(data) setup=(data=rand(10))