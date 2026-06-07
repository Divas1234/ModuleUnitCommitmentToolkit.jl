using MAT
# flag: with/without BESS/withBESSandWinds
# signal: with/with small/large uncertain errors
"""
	signal: denotes the noise type
		singal = 1: conventional nosie sequence
		singal = 2: increased nosise sequence that follows Gassian distributions
		singal = 3: more increased one.

	flag: denotes wether the converter-interfaced generators participating into frequency supporting or not
		flag = 0: not
		flag = 1: yes (converter would participating into frequency supporting)
"""
function form_SFRcurveData(signal, flag, whitenoise_parameter = 1e-4, fcr_selected_threshold = 100)
	if flag == 1
		if signal == 1
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(
				generate_data, particle_filter, 100, 60, 1, 1, 0, 1234, whitenoise_parameter, fcr_selected_threshold)
			#TODO default, the frequency dynamics from SFR is approximiately equals to the one solved by BF-SFR.
			# δf_ASFR = δf_positor

			ydata, different_ASFR, increment_Padd = frequencydynamic_ASFR(0)
			δf_ASFR = ydata

			# str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withoutBESSandWinds/realdata1.mat")

			if Sys.iswindows()
				str = matread("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/data/withoutBESSandWinds/realdata1.mat")
			elseif Sys.isapple()
				str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withoutBESSandWinds/realdata1.mat")
			end

			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201 - 20 + 2):1201, 1]
			# δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
			δf_BF_SFR = δf_positor
		elseif signal == 2
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(
				generate_data, particle_filter, 100, 60, 2, 1, 0, 1234, whitenoise_parameter, fcr_selected_threshold)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			# δf_ASFR = δf_positor

			ydata, different_ASFR, increment_Padd = frequencydynamic_ASFR(0)
			δf_ASFR = ydata

			if Sys.iswindows()
				str = matread("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/data/withoutBESSandWinds/realdata2.mat")
			elseif Sys.isapple()
				str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withoutBESSandWinds/realdata2.mat")
			end

			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201 - 20 + 2):1201, 1]
			# δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
			δf_BF_SFR = δf_positor
		end
	else
		if signal == 1
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(
                generate_data, particle_filter, 100, 60, 1, 1, 1, 1234, whitenoise_parameter, fcr_selected_threshold)
			# δf_ASFR = δf_positor

			ydata, different_ASFR, increment_Padd = frequencydynamic_ASFR(1)
			δf_ASFR = ydata

			# str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withBESSandWinds/realdata1.mat")

			if Sys.iswindows()
				str = matread("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/data/withBESSandWinds/realdata1.mat")
			elseif Sys.isapple()
				str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withBESSandWinds/realdata1.mat")
			end

			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201 - 20 + 2):1201, 1]
			# δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))

			δf_BF_SFR = δf_positor
		elseif signal == 2
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(
				generate_data, particle_filter, 100, 60, 2, 1, 1, 1234, whitenoise_parameter, fcr_selected_threshold)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			# δf_ASFR = δf_positor

			ydata, different_ASFR, increment_Padd = frequencydynamic_ASFR(1)
			δf_ASFR = ydata

			# str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withBESSandWinds/realdata2.mat")
			if Sys.iswindows()
				str = matread("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/data/withBESSandWinds/realdata2.mat")
			elseif Sys.isapple()
				str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/data/withBESSandWinds/realdata2.mat")
			end

			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201 - 20 + 2):1201, 1]
			# δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))

			δf_BF_SFR = δf_positor
		end
	end
	# * output data
	# * ANCHOR xesix, asfr data, bf-sfr data, sim data, samplied data
	# return xdata, (δf_ASFR .- 50) .* 0.5, -δf_BF_SFR .* 0.5, realoutdata .* 0.5, δf_samplieddata .* 0.5
	return xdata, δf_ASFR * 0.475, -δf_BF_SFR * 0.5, realoutdata * 0.5, δf_samplieddata * 0.5
end
