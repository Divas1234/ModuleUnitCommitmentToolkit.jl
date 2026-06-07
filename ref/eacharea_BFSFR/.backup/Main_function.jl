include("src/pkg_environment.jl")
include("src/draw_frequencyderivations_differentmethods.jl")
theme(:default)
# theme(:vibrant)
# case1 without withBESSandWinds
# theme(:wong2)

using CSV
using DataFrames
if Sys.iswindows()
	figpath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\out\\"
elseif Sys.isapple()
	figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/"
end
# figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/"

"""
	function form_SFRcurveData(signal, flag)
	signal: denotes the noise type
		singal = 1: conventional nosie sequence
		singal = 2: increased nosise sequence that follows Gassian distributions
		singal = 3: more increased one.

	flag: denotes wether the converter-interfaced generators participating into frequency supporting or not
		flag = 0: not
		flag = 1: yes (converter would participating into frequency supporting)
"""

# !little noise
# ?converter not, and little nosie
"""
	output:
	xdata: sample sampled_filters
	bench1_ydata1: system frequency response through time-discretized SFR
	bench1_ydata2: bf-SFR
	bench1_ydata3: realdata through matlab/simulink
	sampledata1: detailed sampled filters.

	input:
	whitenoise_parameter: uncertain-variability features
	fcr_selected_threshold: binding of FCR for additional power when providing frequency supporting
"""

fcr_selected_threshold = 1000
whitenoise_parameter = 5e-4

xdata, bench1_ydata1, bench1_ydata2, bench1_ydata3, sampledata1 = form_SFRcurveData(1, 1, whitenoise_parameter, fcr_selected_threshold)
# large nosie
# ?converter not, and big nosie
xdata, bench2_ydata1, bench2_ydata2, bench2_ydata3, sampledata2 = form_SFRcurveData(2, 1, whitenoise_parameter, fcr_selected_threshold)

# case1 with withBESSandWinds
# !large noise
# ?converter yes, and little nosie
xdata, bench3_ydata1, bench3_ydata2, bench3_ydata3, sampledata3 = form_SFRcurveData(1, 2, whitenoise_parameter, fcr_selected_threshold)
# large nosie
# ?converter yes, and big nosie
xdata, bench4_ydata1, bench4_ydata2, bench4_ydata3, sampledata4 = form_SFRcurveData(2, 2, whitenoise_parameter, fcr_selected_threshold)

# Plots.plot(bench2_ydata1)

current_dir = pwd()

df_data_1 = DataFrame(
	xdata = xdata[:, 1],
	sfr_data = bench1_ydata1[:, 1] * -1,
	bfsfr_data = bench1_ydata2[:, 1],
	real_data = bench1_ydata3[:, 1]
)

df_data_2 = DataFrame(
	xdata = xdata[:, 1],
	sfr_data = bench2_ydata1[:, 1] * -1,
	bfsfr_data = bench2_ydata2[:, 1],
	real_data = bench2_ydata3[:, 1]
)

df_data_3 = DataFrame(
	xdata = xdata[:, 1],
	sfr_data = bench3_ydata1[:, 1] * -1,
	bfsfr_data = bench3_ydata2[:, 1],
	real_data = bench3_ydata3[:, 1]
)

df_data_4 = DataFrame(
	xdata = xdata[:, 1],
	sfr_data = bench4_ydata1[:, 1] * -1,
	bfsfr_data = bench4_ydata2[:, 1],
	real_data = bench4_ydata3[:, 1]
)

CSV.write(joinpath(current_dir, "res", "converter_not_little_noise.csv"), df_data_1)
CSV.write(joinpath(current_dir, "res", "converter_not_big_noise.csv"), df_data_2)
CSV.write(joinpath(current_dir, "res", "converter_yes_little_noise.csv"), df_data_3)
CSV.write(joinpath(current_dir, "res", "converter_yes_big_noise.csv"), df_data_4)

CSV.write(joinpath(current_dir, "res", "sampledata1.csv"), DataFrame(sampledata1, :auto))
CSV.write(joinpath(current_dir, "res", "sampledata2.csv"), DataFrame(sampledata2, :auto))
CSV.write(joinpath(current_dir, "res", "sampledata3.csv"), DataFrame(sampledata3, :auto))
CSV.write(joinpath(current_dir, "res", "sampledata4.csv"), DataFrame(sampledata4, :auto))

#NOTE - plot boxplot and distributions and save them in Gaussian(baseline) folder
run_r_script_draw_frequency_derivations()
run(`Rscript $"D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\Gaussian(baseline)\\draw_frequencynadir_violinplot_little_noise.r"`)
run(`Rscript $"D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\Gaussian(baseline)\\draw_frequencynadir_violinplot_big_noise.r"`)

tar_dir = joinpath(current_dir, "res")
dest_dir = joinpath(current_dir, "res","residuals")

files = readdir(tar_dir, join = true)  # 获取完整路径
target_words = ["noise", ".pdf", "sampledata"]
# files_to_move = filter(file -> isfile(file) && endswith(file, ".csv"), files)
files_to_move = filter(file -> isfile(file) && any(word -> occursin(word, basename(file)), target_words), files)

for file in files_to_move
    file_name = basename(file)
    target_path = joinpath(dest_dir, file_name)
    mv(file, target_path; force = true)
    println("Moved: $file_name")
end


# !draw curve about different residuals and distributions
p1 = draw_sfr_curve3(xdata, bench1_ydata2, bench1_ydata3, bench3_ydata2,
	bench3_ydata3, sampledata1, sampledata3)
p2 = draw_sfr_curve3(xdata, bench2_ydata2, bench2_ydata3, bench4_ydata2,
	bench4_ydata3, sampledata2, sampledata4)

fig1 = Plots.plot(p1, p2; size = (600, 300), layout = (1, 2))
Plots.savefig(fig1, figpath * "new_SFRcurves.svg")
Plots.savefig(p1, figpath * "littlenoise_SFRcurves.svg")
Plots.savefig(p2, figpath * "bignoise_SFRcurves.svg")

p4 = draw_case1_SFRdistribution(sampledata1, sampledata2)
p5 = draw_case1_boxplot(sampledata1, sampledata2)
fig2 = Plots.plot(p5, p4; size = (600, 300), layout = (1, 2))

Plots.savefig(p4, figpath * "pdf.svg")
Plots.savefig(p5, figpath * "boxplot.svg")
Plots.savefig(fig2, figpath * "SFRPDFinformations.svg")

p6, p7 = draw_sfr_surfacedistribution(sampledata1, sampledata2)
Plots.savefig(p6, figpath * "surface1.svg")
Plots.savefig(p7, figpath * "surface2.svg")

theme(:bright)
gr()
fig2 = Plots.plot(p6, p7; size = (600, 200), layout = (1, 2))
Plots.savefig(fig2, figpath * "surface1and2.pdf")

# !SECTION save data

# !draw trend curve along with different residual settings.
# ANCHOR xesix, asfr data, bf-sfr data, sim data, samplied data
gr()
N = 10
ydata = zeros(1201, N)
sampled_filters = zeros(1201, 100, N)
for i in 1:N
	ydata[:, i], ~, sampled_filters[:, :, i] = simulate(
		generate_data, particle_filter, 100, 60, i, 1, 1, 1234)
end
Plots.plot(-ydata[:, 1:3])
time_to_nadir = Int64(round(7.5 / δt))
new_ydata = zeros(100, N)
for i in 1:N
	new_ydata[:, i] = sampled_filters[time_to_nadir, :, i]
end
new_ydata
using DataFrames
df1 = DataFrame(new_ydata, :auto)
println(df1)

if Sys.iswindows()
	open(
		"C:\\Users\\yyp_uestc\\Downloads\\unitcommitment_code-master\\eacharea_BFSFR\\out\\result2_forCloudRainVis.txt",
		"w") do io
		writedlm(io, [" "])
		writedlm(io, new_ydata, '\t')
	end
elseif Sys.isapple()
	open(
		"/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/result2_forCloudRainVis.txt",
		"w") do io
		writedlm(io, [" "])
		writedlm(io, new_ydata, '\t')
	end
end
