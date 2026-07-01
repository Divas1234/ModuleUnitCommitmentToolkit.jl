
function automatic_workflow_function(figpath, distribution_type, whitenoise_parameter, fcr_binding = 100)
    """
    		function form_SFRcurveData(signal, flag)
    		signal: denotes the noise type
    			signal = 1: conventional noise sequence
    			signal = 2: increased noise sequence that follows Gaussian distributions
    			signal = 3: more increased one.

    		flag: denotes whether the converter-interfaced generators participating into frequency supporting or not
    			flag = 0: not
    			flag = 1: yes (converter would participating into frequency supporting)
    	"""

    # !little noise
    # ?converter not, and little noise
    """
    		xdata: sample sampled_filters
    		bench1_ydata1: system frequency response through time-discretized SFR
    		bench1_ydata2: bf-SFR
    		bench1_ydata3: realdata through matlab/simulink
    		sampledata1: detailed sampled filters.
    	"""

    # fcr_binding = 100
    xdata, bench1_ydata1, bench1_ydata2, bench1_ydata3, sampledata1 = form_SFRcurveData(1, 1, whitenoise_parameter, fcr_binding)
    # large nosie
    # ?converter not, and big nosie
    xdata, bench2_ydata1, bench2_ydata2, bench2_ydata3, sampledata2 = form_SFRcurveData(2, 1, whitenoise_parameter, fcr_binding)

    # case1 with withBESSandWinds
    # !large noise
    # ?converter yes, and little nosie
    xdata, bench3_ydata1, bench3_ydata2, bench3_ydata3, sampledata3 = form_SFRcurveData(1, 2, whitenoise_parameter, fcr_binding)
    # large nosie
    # ?converter yes, and big nosie
    xdata, bench4_ydata1, bench4_ydata2, bench4_ydata3, sampledata4 = form_SFRcurveData(2, 2, whitenoise_parameter, fcr_binding)

    # Plots.plot(bench2_ydata1)

    # current_dir = pwd()

    current_dir = figpath

    df_data_1 =
        DataFrame(; xdata = xdata[:, 1], sfr_data = bench1_ydata1[:, 1] * -1, bfsfr_data = bench1_ydata2[:, 1], real_data = bench1_ydata3[:, 1])

    df_data_2 =
        DataFrame(; xdata = xdata[:, 1], sfr_data = bench2_ydata1[:, 1] * -1, bfsfr_data = bench2_ydata2[:, 1], real_data = bench2_ydata3[:, 1])

    df_data_3 =
        DataFrame(; xdata = xdata[:, 1], sfr_data = bench3_ydata1[:, 1] * -1, bfsfr_data = bench3_ydata2[:, 1], real_data = bench3_ydata3[:, 1])

    df_data_4 =
        DataFrame(; xdata = xdata[:, 1], sfr_data = bench4_ydata1[:, 1] * -1, bfsfr_data = bench4_ydata2[:, 1], real_data = bench4_ydata3[:, 1])

    distribution_type = "Gaussian" # "Weibull"

    if occursin(distribution_type, current_dir)
        # println("The directory already exists, please check it.")
        if !isdir(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)"))
            mkpath(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)"))
        end

        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "converter_not_little_noise.csv"), df_data_1)
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "converter_not_big_noise.csv"), df_data_2)
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "converter_yes_little_noise.csv"), df_data_3)
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "converter_yes_big_noise.csv"), df_data_4)

        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "sampledata1.csv"), DataFrame(sampledata1, :auto))
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "sampledata2.csv"), DataFrame(sampledata2, :auto))
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "sampledata3.csv"), DataFrame(sampledata3, :auto))
        CSV.write(joinpath(current_dir, "res//Gaussian($whitenoise_parameter)", "sampledata4.csv"), DataFrame(sampledata4, :auto))
    elseif occursin("Weibull", current_dir)
        # println("The directory already exists, please check it.")
        if !isdir(joinpath(current_dir, "res//Weibull($whitenoise_parameter)"))
            mkpath(joinpath(current_dir, "res//Weibull($whitenoise_parameter)"))
        end

        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "converter_not_little_noise.csv"), df_data_1)
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "converter_not_big_noise.csv"), df_data_2)
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "converter_yes_little_noise.csv"), df_data_3)
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "converter_yes_big_noise.csv"), df_data_4)

        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "sampledata1.csv"), DataFrame(sampledata1, :auto))
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "sampledata2.csv"), DataFrame(sampledata2, :auto))
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "sampledata3.csv"), DataFrame(sampledata3, :auto))
        CSV.write(joinpath(current_dir, "res//Weibull($whitenoise_parameter)", "sampledata4.csv"), DataFrame(sampledata4, :auto))
    else
        # println("The directory already exists, please check it.")
        if !isdir(joinpath(current_dir, "res//fcr_binding($fcr_binding)"))
            mkpath(joinpath(current_dir, "res//fcr_binding($fcr_binding)"))
        end

        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "converter_not_little_noise.csv"), df_data_1)
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "converter_not_big_noise.csv"), df_data_2)
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "converter_yes_little_noise.csv"), df_data_3)
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "converter_yes_big_noise.csv"), df_data_4)

        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "sampledata1.csv"), DataFrame(sampledata1, :auto))
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "sampledata2.csv"), DataFrame(sampledata2, :auto))
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "sampledata3.csv"), DataFrame(sampledata3, :auto))
        CSV.write(joinpath(current_dir, "res//fcr_binding($fcr_binding)", "sampledata4.csv"), DataFrame(sampledata4, :auto))
    end

    # run_r_script_draw_frequency_derivations();

    # println("================================================================")
    # println("end...")
    # println("================================================================")
end
