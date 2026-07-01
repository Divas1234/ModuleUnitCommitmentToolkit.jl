using MultivariateStats
using Clustering
function creatfrequencyfittingfunction(units, winds, NG, NW, flag_method_type, whitenoise_parameter)
    Set_f_nadir, set_H, set_δp, set_Dg, set_Fg, set_Kg, set_Rg, sampleStatues =
        montecalrosimulation(units, winds, NG, NW, flag_method_type, whitenoise_parameter)

    res = transpose(vcat(transpose(set_H), transpose(set_Fg ./ set_Rg), transpose(1 ./ set_Rg), transpose(Set_f_nadir)))

    # println("res")
    # println("---------------------------------------------------")
    # @show DataFrame(res, :auto)

    new_res = sortslices(res; dims = 1, lt = (x, y) -> isless(x[1], y[1]))
    # @show DataFrame(new_res, :auto)
    R = kmeans(transpose(new_res), 10; maxiter = 200, display = :iter)

    # println("R_center")
    # println("---------------------------------------------------")
    # @show DataFrame((R.centers)', :auto)

    PWL_model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(PWL_model, "OutputFlag", 0)
    set_silent(PWL_model)
    coeffi_num = Int32(4)
    dataset = transpose(R.centers)
    bigM = 1e4
    clusteringnumber = size(dataset, 1)
    # sampling_numbers = size(inputdata, 1)
    @variable(PWL_model, coefficient[1, 1:coeffi_num])
    @variable(PWL_model, tem[1:clusteringnumber, 1] >= 0)
    @objective(PWL_model, Min, 1e3 * sum(tem[i, 1] for i in 1:clusteringnumber))
    @constraint(
        PWL_model,
        [i = 1:clusteringnumber, j = 1:4],
        tem[i, 1] >= dataset[i, 4] - sum(sum(coefficient[1, 1:3] .* dataset[i, 1:3]) + coefficient[1, 4])
    )
    JuMP.optimize!(PWL_model)

    # println("coefficient")
    # println("---------------------------------------------------")
    # @show JuMP.value.(coefficient)
    res = JuMP.value.(coefficient).data

    return res

    # # calculation_pwl_parameters(inputdata, outputdata, pwl_blocks, coeffi_block)
    # PWL_model = Model(Gurobi.Optimizer)
    # pwl_numbers = Int32(4)
    # coeffi_num = Int32(5)

    # bigM = 1e4
    # # sampling_numbers = size(inputdata, 1)
    # @variable(PWL_model, coefficient[1, 1:coeffi_num])
    # @variable(PWL_model, tem[1 : siza(set_H), 1] >= 0)
    # @objective(PWL_model, Min, 1e3 * sum(tem[i, 1] for i in 1:size(set_H, 1)))
    # @constraint(
    #     PWL_model,
    #     [i = 1:size(set_H,1), j = 1:4],
    #     tem[i, 1] >= y[i, 1] - sum(sum(coefficient[1,1:2] .* x[i,1:2]) + coefficient[1,3])
    # )
    # JuMP.optimize!(PWL_model)
    # return JuMP.value.(coefficient)
end

function montecalrosimulation(units, winds, NG, NW, flag_method_type, whitenoise_parameter)
    # create unitsstatues
    sampleNumber = 50
    unitsamplestatues = rand(0:1, NG, sampleNumber)
    Set_f_nadir, set_H, set_δp, set_Dg, set_Fg, set_Kg, set_Rg = zeros(sampleNumber, 1),
    zeros(sampleNumber, 1),
    zeros(sampleNumber, 1),
    zeros(sampleNumber, 1),
    zeros(sampleNumber, 1),
    zeros(sampleNumber, 1),
    zeros(sampleNumber, 1)
    for i in 1:sampleNumber
        # println(i)
        Sampling_Statue = unitsamplestatues[:, i]
        f_nadir, t_nadir, H, δp, Kg, Fg, Rg, Dg =
            creatingfrequencyresponsesamplingdata(units, winds, NW, NG, Sampling_Statue, 2, flag_method_type, whitenoise_parameter)
        Set_f_nadir[i, 1], set_H[i, 1], set_δp[i, 1], set_Dg[i, 1], set_Fg[i, 1], set_Kg[i, 1], set_Rg[i, 1] = f_nadir, H, δp, Dg, Fg, Kg, Rg
    end

    return Set_f_nadir, set_H, set_δp, set_Dg, set_Fg, set_Kg, set_Rg, unitsamplestatues
end

function creatingfrequencyresponsesamplingdata(units, winds, NW, NG, Sampling_Statue, flag, flag_method_type, whitenoise_parameter)
    Sampling_Statue[1, 1] = 1
    # creatingfrequencyresponsesamplingdata(units, winds, NW, NG, Sampling_Statue)

    # normalized winds parameters through COI
    vsmFC_number = sum(winds.Fcmode[:, 1])
    doopFC_number = length(winds.Fcmode[:, 1]) - vsmFC_number
    adjustablewindsVSCpower = winds.Fcmode .* winds.p_max
    inverse_winds_Rw = zeros(NW, 1)
    for i in 1:NW
        if winds.Fcmode[i, 1] == 0
            inverse_winds_Rw[i, 1] = 1 / winds.Rw[i, 1]
        end
    end
    current_Kw = 1.0
    current_Dw = sum(winds.Dw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Dw
    current_Mw = sum(winds.Mw .* adjustablewindsVSCpower) / sum(adjustablewindsVSCpower) # Mw
    current_Hw = current_Mw / 2
    current_Rw =
        1 / sum(winds.Kw .* inverse_winds_Rw .* (ones(NW, 1) - winds.Fcmode) .* winds.p_max) / sum(((ones(NW, 1) - winds.Fcmode) .* winds.p_max))

    # units parameters
    adjustabletheramlpower = units.p_max .* Sampling_Statue
    current_Kg = 1.0
    current_Tg = mean(units.Tg)
    current_Fg_div_Rg = sum(units.Kg .* units.Fg ./ units.Rg .* adjustabletheramlpower) / sum(units.p_max)
    current_Rg = 1 / (sum(units.Kg ./ units.Rg .* adjustabletheramlpower) / sum(units.p_max)) # Kg
    current_Fg = current_Fg_div_Rg * current_Rg
    current_Dg = sum(units.Dg .* adjustabletheramlpower) / sum(units.p_max)
    current_Hg = sum(units.Hg .* adjustabletheramlpower) / sum(units.p_max)
    current_Mg = current_Hg * 2

    #  powers for intia frequency response
    localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
    sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) + sum(winds.p_max))
    p_step = maximum(units.p_max) * 1.0

    # sumD and sumH
    if flag == 1
        current_sumD = (sum(units.Dg .* adjustabletheramlpower)) / sumapparentpower
        current_sumH = (sum(current_Mg .* adjustabletheramlpower)) / sumapparentpower / 2
    else
        current_sumD =
            (
                sum(units.Dg .* adjustabletheramlpower) +
                sum(winds.Dw .* winds.p_max .* winds.Fcmode + winds.Kw .* winds.p_max .* (ones(NW, 1) - winds.Fcmode)) +
                1 / 0.4
            ) / sumapparentpower
        current_sumH = (sum(current_Mg .* adjustabletheramlpower) + sum(current_Mw .* adjustablewindsVSCpower)) / sumapparentpower / 2
    end

    D, H, F, R, T, K, δp = current_sumD, current_sumH, current_Fg, current_Rg, current_Tg, current_Kg, p_step

    # flag_method_type = 1
    if flag_method_type == 0
        # @show [D, H, F, T, R, δp]
        f_nadir, t_nadir = calculation_frequencynadirdata(H, R, D, F, T, δp)
        f_nadir = f_nadir * (-1)
    else
        #TODO - PF SFR
        sample_Num = 200
        horizon = 30
        flag, symflag = 1, 0
        seed = rand()
        δf_positor, δf_actual, δf_samplieddata =
            simulate(generate_data, particle_filter, sample_Num, horizon, flag, symflag, units, winds, Sampling_Statue, whitenoise_parameter, seed)
        f_nadir = maximum(abs.(δf_positor)) * (-1)
        t_nadir = findmax(abs.(δf_positor))[1]
    end
    return f_nadir, t_nadir, H, δp, K, F, R, D
end

function calculation_frequencynadirdata(H, R, D, F, T, δp)
    # δp = 1.10
    # H, R, D, F, T = equivalentfrequencycoefficients[i, 1:5]
    ωₙ = sqrt((D * R + 1) / (2 * H * R * T))
    ς = (D * R * T + 2 * H * R + F * T) / (2 * (D * R + 1)) * ωₙ
    ωᵣ = ωₙ * sqrt(1 - ς * ς)
    α = sqrt((1 - 2 * T * ς * ωₙ + (T * ωᵣ) * (T * ωᵣ)) / (1 - ς * ς))
    tnadir = abs((1 / ωᵣ) * (atan((ωᵣ * T) / (ς * ωᵣ * T - 1))))
    fnadir = δp * (R) / (D * R + 1) * (1 + sqrt(1 - ς * ς) * α * exp(-ς * ωₙ * tnadir))
    return fnadir, tnadir
end

# delate the duplicate elements in arrays by filitering index
function Rmduplicateelements(str, index)
    str_index = unique(str[:, index])
    str_1 = zeros(size(str_index, 1), size(str, 2))
    for i in 1:axes(str_index, 1)
        j = findfirst(isequal(str_index[i, 1]), str[:, index])
        str_1[i, :] = str[j, :]
    end

    return str_1
end
