using JuMP, Gurobi, Test, DelimitedFiles
# using CPLEX

include("linearization.jl")
include("powerflowcalculation.jl")

function enhance_FCUC_scucmodel_withFCR(
    NN::Int64,
    NT::Int64,
    NB::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    units::unit,
    loads::load,
    winds::wind,
    lines::transmissionline,
    config_param::config,
    fittingparameter_vector,
    fcr_thres,
    confidence_level,
)
    if config_param.is_NetWorkCon == 1
        Adjacmatrix_BtoG, Adjacmatrix_B2D, Gsdf = linearpowerflow(units, lines, loads, NG, NB, ND, NL)
        Adjacmatrix_BtoW = zeros(NB, length(winds.index))
        for i in 1:length(winds.index)
            Adjacmatrix_BtoW[winds.index[i, 1], i] = 1
        end
    end

    NS = winds.scenarios_nums
    NW = length(winds.index)

    println("prepare...")
    # flag_method_type = 1
    # NN = 20 # sampled scenarios for chance constraints
    # μ, σ = 0, 0.5e-3
    # fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(
    # 	units, winds, NG, NW, NN, flag_method_type, μ, σ)

    println("Step-3: Creating dispatching model")

    # creat scucsimulation_model
    # scuc = Model(CPLEX.Optimizer)
    scuc = Model(Gurobi.Optimizer)

    # NS = 1 # for test

    # binary variables
    @variable(scuc, x[1:NG, 1:NT], Bin)
    @variable(scuc, u[1:NG, 1:NT], Bin)
    @variable(scuc, v[1:NG, 1:NT], Bin)

    # continuous variables
    @variable(scuc, pg₀[1:(NG * NS), 1:NT] >= 0)
    @variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3] >= 0)
    @variable(scuc, su₀[1:NG, 1:NT] >= 0)
    @variable(scuc, sd₀[1:NG, 1:NT] >= 0)
    @variable(scuc, sr⁺[1:(NG * NS), 1:NT] >= 0)
    @variable(scuc, sr⁻[1:(NG * NS), 1:NT] >= 0)
    @variable(scuc, Δpd[1:(ND * NS), 1:NT] >= 0)
    @variable(scuc, Δpw[1:(NW * NS), 1:NT] >= 0)

    # pss variables
    @variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
    @variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
    @variable(scuc, pc⁺[1:(NC * NS), 1:NT] >= 0)# charge power
    @variable(scuc, pc⁻[1:(NC * NS), 1:NT] >= 0)# discharge power
    @variable(scuc, qc[1:(NC * NS), 1:NT] >= 0) # cumsum power
    # @variable(scuc, pss_sumchargeenergy[1:NC * NS, 1] >= 0)

    # defination charging and discharging of BESS
    @variable(scuc, α[1:(NS * NC), 1:NT], Bin)
    @variable(scuc, β[1:(NS * NC), 1:NT], Bin)

    # Auxiliary variable for frequency constraints
    @variable(scuc, ι[1:NN, 1:NT], Bin)

    refcost, eachslope = linearizationfuelcurve(units, NG)

    c₀ = config_param.is_CoalPrice
    pₛ = scenarios_prob
    plentycoffi_1 = config_param.is_LoadsCuttingCoefficient * 1e10
    plentycoffi_2 = config_param.is_WindsCuttingCoefficient * 1e0
    ρ⁺ = c₀ * 2
    ρ⁻ = c₀ * 2

    println("start...")
    println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

    # model-1: MIQP with quartic fuel equation
    # @objective(scuc, Min, sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)+
    #     pₛ*c₀/100*(sum(sum(sum(sum(units.coffi_a[i,1] * (pg₀[i + (s - 1) * NG,t]^2) + units.coffi_b[i,1] * pg₀[i + (s - 1) * NG,t] + units.coffi_c[i,1] for t in 1:NT)) for s in 1:NS) for i in 1:NG))+
    #     pₛ*plentycoffi_1*sum(sum(sum(Δpd[1+(s-1)*ND : s*ND, t]) for t in 1:NT) for s in 1:NS)+
    #     pₛ*plentycoffi_2*sum(sum(sum(Δpw[1+(s-1)*NW : s*NW, t]) for t in 1:NT) for s in 1:NS))

    # model-2:MILP with piece linearization equation of nonliear equation
    @objective(
        scuc,
        Min,
        100 * sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) +
        pₛ *
        c₀ *
        (
            sum(sum(sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT)) for s in 1:NS) for i in 1:NG) +
            sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS) +
            sum(sum(sum(ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT) for s in 1:NS)
        ) +
        pₛ * plentycoffi_1 * sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS) +
        pₛ * plentycoffi_2 * sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
    )

    #
    # for test
    # @objective(scuc, Min, 0)
    println("objective_function")
    println("\t MILP_type objective_function \t\t\t\t\t\t done")

    println("subject to.")

    # minimum shutup and shutdown ductration limits
    onoffinit, Lupmin, Ldownmin = zeros(NG, 1), zeros(NG, 1), zeros(NG, 1)
    for i in 1:NG
        # onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
        Lupmin[i] = min(NT, units.min_shutup_time[i] * onoffinit[i])
        Ldownmin[i] = min(NT, (units.min_shutdown_time[i, 1]) * (1 - onoffinit[i]))
    end

    # @constraint(
    #     scuc,
    #     [i = 1:NG, t = 1:Int64((Lupmin[i] + Ldownmin[i]))],
    #     x[i, t] == onoffinit[i]
    # )

    for i in 1:NG
        for t in Int64(max(1, Lupmin[i])):NT
            LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
            @constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t])
        end
        for t in Int64(max(1, Ldownmin[i])):NT
            LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
            @constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]))
        end
    end
    println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

    # binary variable logic
    @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))
    @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)
    println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

    # shutup/shutdown cost
    shutupcost = units.coffi_cold_shutup_1
    shutdowncost = units.coffi_cold_shutdown_1
    # @constraint(scuc, [t = 1], su₀[:, t] .>= shutupcost .* (x[:, t] - onoffinit[:, 1]))
    # @constraint(scuc, [t = 1], sd₀[:, t] .>= shutdowncost .* (onoffinit[:, 1] - x[:, t]))

    @constraint(scuc, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
    @constraint(scuc, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))

    @constraint(scuc, [t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
    @constraint(scuc, [t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])
    println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")

    # loadcurtailments and spoliedwinds limits
    @constraint(scuc, [s = 1:NS, t = 1:NT], Δpw[(1 + (s - 1) * NW):(s * NW), t] .<= winds.scenarios_curve[s, t] * winds.p_max[:, 1])
    @constraint(scuc, [s = 1:NS, t = 1:NT], Δpd[(1 + (s - 1) * ND):(s * ND), t] .<= loads.load_curve[:, t])
    # @constraint(scuc, [s=1:NS, t = 1:NT], Δpw[1+(s-1)*NW:s*NW, t] .== zeros(NW,1))
    # @constraint(scuc, [s=1:NS, t = 1:NT], Δpd[1+(s-1)*ND:s*ND, t] .== zeros(ND,1))
    println("\t constraints: 4) loadcurtailments and spoliedwinds\t\t\t done")

    # generatos power limits
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] + sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<= units.p_max[:, 1] .* x[:, t]
    )
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] - sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>= units.p_min[:, 1] .* x[:, t]
    )
    println("\t constraints: 5) generatos power limits\t\t\t\t\t done")

    # system reserves
    # forcast_error = 0.05
    # forcast_reserve = winds.scenarios_curve * sum(winds.p_max[:,1]) * forcast_error
    # @constraint(scuc,[s = 1:NS, t = 1:NT, i = 1:NG], sum(sr⁺[1 + (s - 1) * NG:s * NG, t]) >= 0.05 * units.p_max[i,1] * x[i,t])
    # @constraint(scuc,[s = 1:NS, t = 1:NT], sum(sr⁻[1 + (s - 1) * NG:s * NG, t]) >= config_param.is_Alpha * forcast_reserve[s,t] + config_param.is_Belta * sum(loads.load_curve[:,t]))

    forcast_error = 0.05
    forcast_reserve = winds.scenarios_curve * sum(winds.p_max[:, 1]) * forcast_error
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT, i = 1:NG],
        sum(sr⁺[(1 + (s - 1) * NG):(s * NG), t]) + sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) >= 0.5 * units.p_max[i, 1] * x[i, t]
    )
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        sum(sr⁻[(1 + (s - 1) * NG):(s * NG), t]) + sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) >=
        1.0 * (config_param.is_Alpha * forcast_reserve[s, t] + config_param.is_Belta * sum(loads.load_curve[:, t]))
    )
    println("\t constraints: 6) system reserves limits\t\t\t\t\t done")

    # power balance constraints

    # @constraint(scuc,[s = 1:NS,t = 1:NT],sum(pg₀[1 + (s - 1) * NG:s * NG,t]) + sum(winds.scenarios_curve[s,t] .* winds.p_max[:,1] - Δpw[1 + (s - 1) * NW:s * NW,t]) - sum(loads.load_curve[:,t] - Δpd[1 + (s - 1) * ND:s * ND,t]) .== 0)

    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        sum(pg₀[(1 + (s - 1) * NG):(s * NG), t]) + sum(winds.scenarios_curve[s, t] * winds.p_max[:, 1] - Δpw[(1 + (s - 1) * NW):(s * NW), t]) -
        sum(loads.load_curve[:, t] - Δpd[(1 + (s - 1) * ND):(s * ND), t]) + sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) -
        sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) .== 0
    )
    println("\t constraints: 7) power balance constraints\t\t\t\t done")

    # ramp-up and ramp-down constraints
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pg₀[(1 + (s - 1) * NG):(s * NG), t] - ((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) .<=
        units.ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
        units.shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
        units.p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]))
    )
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        ((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) - pg₀[(1 + (s - 1) * NG):(s * NG), t] .<=
        units.ramp_down[:, 1] .* x[:, t] + units.shut_down[:, 1] .* v[:, t] + units.p_max[:, 1] .* (x[:, t])
    )
    println("\t constraints: 8) ramp-up/ramp-down constraints\t\t\t\t done")

    # PWL constraints
    eachseqment = (units.p_max - units.p_min) / 3
    @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG], pg₀[i + (s - 1) * NG, t] .== units.p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, :]))
    @constraint(scuc, [s = 1:NS, t = 1:NT, i = 1:NG, k = 1:3], pgₖ[i + (s - 1) * NG, t, k] <= eachseqment[i, 1] * x[i, t])
    println("\t constraints: 9) piece linearization constraints\t\t\t done")

    # transmissionline power limits for basline states
    if config_param.is_NetWorkCon == 1
        for l in 1:NL
            subGsdf_units = Gsdf[l, units.locatebus]
            subGsdf_winds = Gsdf[l, winds.index]
            subGsdf_loads = Gsdf[l, loads.locatebus]
            subGsdf_psses = Gsdf[1, stroges.locatebus]
            @constraint(
                scuc,
                [s = 1:NS, t = 1:NT],
                sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
                sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] - Δpw[(s - 1) * NW + w, t]) for w in 1:NW) -
                sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t]) for d in 1:ND) +
                sum(subGsdf_psses[c] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) for c in 1:NC) <= lines.p_max[l, 1]
            )
            @constraint(
                scuc,
                [s = 1:NS, t = 1:NT],
                sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) +
                sum(subGsdf_winds[w] * (winds.scenarios_curve[s, t] * winds.p_max[w, 1] - Δpw[(s - 1) * NW + w, t]) for w in 1:NW) -
                sum(subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t]) for d in 1:ND) +
                sum(subGsdf_psses[c] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) for c in 1:NC) >= lines.p_min[l, 1]
            )
        end
        println("\t constraints: 10) transmissionline limits for basline\t\t\t done")
    end

    # stroges system constraints
    # discharge/charge limits
    @constraint(scuc, [s = 1:NS, t = 1:NT], pc⁺[((s - 1) * NC + 1):(s * NC), t] .<= stroges.p⁺[:, 1] .* κ⁺[((s - 1) * NC + 1):(s * NC), t]) # charge power
    @constraint(scuc, [s = 1:NS, t = 1:NT], pc⁻[((s - 1) * NC + 1):(s * NC), t] .<= stroges.p⁻[:, 1] .* κ⁻[((s - 1) * NC + 1):(s * NC), t]) # discharge power

    # coupling limits for adjacent discharge/charge constraints
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        pc⁺[((s - 1) * NC + 1):(s * NC), t] - ((t == 1) ? stroges.P₀[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) .<= stroges.γ⁺[:, 1]
    )
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        ((t == 1) ? stroges.P₀[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) - pc⁺[((s - 1) * NC + 1):(s * NC), t] .<= stroges.γ⁻[:, 1]
    )

    # Mutual exclusion constraints in charge and discharge states
    @constraint(scuc, [s = 1:NS, t = 1:NT, c = 1:NC], κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t] <= 1)

    # Energy storage constraint
    @constraint(scuc, [s = 1:NS, t = 1:NT], qc[((s - 1) * NC + 1):(s * NC), t] .<= stroges.Q_max[:, 1])
    @constraint(scuc, [s = 1:NS, t = 1:NT], qc[((s - 1) * NC + 1):(s * NC), t] .>= stroges.Q_min[:, 1])
    @constraint(
        scuc,
        [s = 1:NS, t = 1:NT],
        qc[((s - 1) * NC + 1):(s * NC), t] .==
        ((t == 1) ? stroges.P₀[:, 1] : qc[((s - 1) * NC + 1):(s * NC), t - 1]) + stroges.η⁺[:, 1] .* pc⁺[((s - 1) * NC + 1):(s * NC), t] -
        (ones(NC, 1) ./ stroges.η⁻[:, 1]) .* pc⁻[((s - 1) * NC + 1):(s * NC), t]
    )

    # inital-time and end-time equaltimes
    @constraint(scuc, [s = 1:NS], 0.95 * stroges.P₀[:, 1] .<= qc[((s - 1) * NC + 1):(s * NC), NT] .<= 1.1 * stroges.P₀[:, 1])
    @constraint(
        scuc,
        [s = 1:NS, c = 1:NC, t = 1:NT],
        α[(s - 1) * NC + c, t] >= κ⁺[(s - 1) * NC + 1, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + 1, t - 1])
    )
    @constraint(
        scuc,
        [s = 1:NS, c = 1:NC, t = 1:NT],
        β[(s - 1) * NC + c, t] >= ((t == 1) ? 0 : κ⁺[(s - 1) * NC + 1, t - 1]) - κ⁺[(s - 1) * NC + 1, t]
    )

    @constraint(scuc, [s = 1:NS, c = 1:NC], sum(α[(s - 1) * NC + c, t] for t in 1:NT) <= 2)

    @constraint(scuc, [s = 1:NS, c = 1:NC], sum(β[(s - 1) * NC + c, t] for t in 1:NT) <= 2)

    # # magic constraint
    # least_operatime = 0.0
    # @constraint(scuc, [s = 1:NS], pss_sumchargeenergy[(s - 1) * NC + 1:s * NC,1] .== sum(pc⁺[(s - 1) * NC + 1:s * NC,t] for t in 1:NT))
    # @constraint(scuc, [s = 1:NS], pss_sumchargeenergy[(s - 1) * NC + 1:s * NC,1] .>= least_operatime * NT * storges.p_max[:,1])
    println("\t constraints: 11) stroges system constraints limits\t\t\t done")

    # frequency constrol process
    f_base = 50.0
    RoCoF_max = 4.5
    f_nadir = 49.5
    f_qss = 49.5
    Δp = maximum(units.p_max[:, 1]) * 0.25
    """
    		if nadir threshold is 0.5 or too minor, all generators must keep active for guarantee the system to be stable.
    		so in the actual little case, the suitable scalling for imbalanced power is neceassary...
    		scalling_imbalanced_power = 1.5, default.

    	"""
    scalling_imbalanced_power = 1.25

    # LINK - RoCoF constraint
    # @constraint(scuc,
    # 	[t = 1:NT],
    # 	sum(winds.Mw[:, 1] .* winds.Fcmode[:, 1] .* winds.p_max[:, 1]) +
    # 	2 * sum(x[:, t] .* units.Hg[:, 1] .* units.p_max[:, 1])>=
    # 	(Δp / scalling_imbalanced_power) * f_base / RoCoF_max * (sum(units.p_max[:, 1]) + sum(winds.Fcmode .* winds.p_max)))

    #! discard here in further version
    # @constraint(
    # 	scuc,
    # 	[t = 1:NT],
    # 	sum(winds.Mw[:, 1] .* winds.Fcmode[:, 1] .* winds.p_max[:, 1]) +
    # 	2 * sum(x[:, t] .* units.Hg[:, 1] .* units.p_max[:, 1]) >=
    # 	Δp * f_base / RoCoF_max * (sum(units.p_max[:, 1]) + sum(winds.Fcmode .* winds.p_max))
    # )

    # LINK - f_nadir constraint
    # flag_method_type = 1
    # μ, σ = 1e-3, 1e-3
    # fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(units, winds, NG, NW, NN, flag_method_type, μ, σ)
    big_M = 1e6

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

    #  powers for intia frequency response
    localapparentpower = (sum(units.p_max[:, 1]) + sum(winds.p_max .* winds.Fcmode))
    sumapparentpower = (localapparentpower - sum(winds.p_max .* winds.Fcmode) + sum(winds.p_max))

    for n in 1:NN
        # recalculating the fitting parameters
        fittingparameter = fittingparameter_vector[n, :] * (-1)
        # println(fittingparameter)
        # fittingparameter = creatfrequencyfittingfunction(units, winds, NG, NW, flag_method_type, whitenoise_parameter[n])
        # fittingparameter = fittingparameter * (-1)
        # println(fittingparameter)

        # normalized winds parameters through COI
        @constraint(
            scuc,
            [t = 1:NT],
            fittingparameter[1] / sumapparentpower * (sum(x[:, t] .* units.Hg .* units.p_max) + sum(current_Mw .* adjustablewindsVSCpower)) +
            fittingparameter[2] / sum(units.p_max) * (sum(x[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
            fittingparameter[3] / sum(units.p_max) * (sum(x[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
            fittingparameter[4] <= (f_base - f_nadir) * scalling_imbalanced_power + (1 - ι[n, t]) * big_M
        )
        # for s in 1:NS
        # 	@constraint(
        # 		scuc,
        # 		[t = 1:NT],
        # 		sr⁺[(1+(s-1)*NG):(s*NG), t] .>= units.Kg[:, 1] ./ units.Rg[:, 1] * (f_base - f_nadir) * 0.1 .* x[:, t] - (1 - ι[n, t]) * big_M
        # 	)
        # end
    end

    @constraint(scuc, [t = 1:NT], sum(ι[:, t]) >= confidence_level * NN)

    # frequency constrainment reserve
    @constraint(
        scuc,
        [t = 1:NT, s = 1:NS],
        sr⁺[(1 + (s - 1) * NG):(s * NG), t] .>= (units.Kg[:, 1] ./ units.Rg[:, 1] * (f_base - f_nadir) * fcr_thres .* x[:, t])
    )

    # Quadratic(Quasi)-steady-state constraint
    # fc = units.p_max
    # coff₃ = units.Dg .* units.p_max
    # @constraint(
    #     scuc,
    #     [t = 1:NT],
    #     sum(units.p_max .* ζ[:, t]) >=
    #     Δp * sum(units.p_max .* x[:, t]) -
    #     sum(coff₃ .* x[:, t]) * sum(loads.load_curve[:, t]) * f_qss
    # )
    # @constraint(
    #     scuc,
    #     [t = 1:NT, i = 1],
    #     ζ[i, t] <= sum(units.p_max[:, 1] .* z[((i-1)*NG+1):(i*NG), t])
    # )
    # @constraint(scuc, [t = 1:NT, i = 1:NG, j = 1:NG], z[(i-1)*NG+j, t] <= x[i, t])
    # @constraint(scuc, [t = 1:NT, i = 1:NG, j = 1:NG], z[(i-1)*NG+j, t] <= x[j, t])
    # @constraint(
    #     scuc,
    #     [t = 1:NT, i = 1:NG, j = 1:NG],
    #     z[(i-1)*NG+j, t] >= x[i, t] + x[j, t] - 1
    # )
    # @constraint(scuc, [t = 1:NT, i = 1:NG], ζ[i, t] <= sum(sr⁺[i, t]))
    # @constraint(
    #     scuc,
    #     [t = 1:NT, i = 1:NG],
    #     ζ[i, t] >= -sum(fc[i, 1]) * (1 - x[i, t]) + sum(sr⁺[i, t])
    # )

    # @constraint(
    #     scuc,
    #     [t = 1:NT, s = 1:NS],
    #     sum(sr⁺[(1+(s-1)*NG):(s*NG)]) * sum(units.p_max .* x[:, t]) >=
    #     Δp * sum(units.p_max .* x[:, t]) -
    #     sum(coff₃ .* x[:, t]) * sum(loads.load_curve[:, t]) * f_qss
    # )

    # println("\t constraints: 12) frequency responce constraints limits\t\t\t done")
    # println("\n")
    println("Model has been loaded")
    println("Step-4: calculation...")
    JuMP.optimize!(scuc)

    println("callback gurobisolver\t\t\t\t\t\t\t done")
    @test JuMP.termination_status(scuc) == MOI.OPTIMAL
    @test JuMP.primal_status(scuc) == MOI.FEASIBLE_POINT
    println("#TEST: termination_status\t\t\t\t\t\t pass")

    println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    # println("pg₀>>\n", JuMP.value.(pg₀[1:NG,1:NT]))
    # println("x>>  \n", JuMP.value.(x))
    # println("Δpd>>\n", JuMP.value.(Δpd[1:ND,1:NT]))
    # println("Δpw>>\n", JuMP.value.(Δpw[1:NW,1:NT]))
    su_cost = sum(JuMP.value.(su₀))
    sd_cost = sum(JuMP.value.(sd₀))
    pᵪ = JuMP.value.(pgₖ)
    p₀ = JuMP.value.(pg₀)
    x₀ = JuMP.value.(x)
    r⁺ = JuMP.value.(sr⁺)
    r⁻ = JuMP.value.(sr⁻)
    pᵨ = JuMP.value.(Δpd)
    pᵩ = JuMP.value.(Δpw)

    pss_charge_state⁺ = JuMP.value.(κ⁺)
    pss_charge_state⁻ = JuMP.value.(κ⁻)
    pss_charge_p⁺ = JuMP.value.(pc⁺)
    pss_charge_p⁻ = JuMP.value.(pc⁻)
    pss_charge_q = JuMP.value.(qc)
    # pss_sumchargeenergy = JuMP.value.(pss_sumchargeenergy)

    prod_cost =
        pₛ *
        c₀ *
        (
            sum(sum(sum(sum(pᵪ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT)) for s in 1:NS) for i in 1:NG) +
            sum(sum(sum(x₀[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS)
        )
    cr⁺ = pₛ * c₀ * sum(sum(sum(ρ⁺ * r⁺[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT) for s in 1:NS)
    cr⁻ = pₛ * c₀ * sum(sum(sum(ρ⁺ * r⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT) for s in 1:NS)
    seq_sr⁺ = pₛ * c₀ * sum(ρ⁺ * r⁺[i, :] for i in 1:NG)
    seq_sr⁻ = pₛ * c₀ * sum(ρ⁺ * r⁻[i, :] for i in 1:NG)
    𝜟pd = pₛ * sum(sum(sum(pᵨ[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)
    𝜟pw = pₛ * sum(sum(sum(pᵩ[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
    str = zeros(1, 7)
    str[1, 1] = su_cost * 10
    str[1, 2] = sd_cost * 10
    str[1, 3] = prod_cost
    str[1, 4] = cr⁺
    str[1, 5] = cr⁻
    str[1, 6] = 𝜟pd
    str[1, 7] = 𝜟pw

    # fittingparameter = creatfrequencyfittingfunction( units, winds, NG, NW, flag_method_type, 0)
    # fittingparameter = fittingparameter * (-1)
    # fittingparameter = fittingparameter_vector[1, :] * (-1)
    δf = zeros(NT, 2)
    fittingparameter = fittingparameter_vector[1, :] * (-1)
    for t in 1:NT
        δf[t, 1] =
            fittingparameter[1] / sumapparentpower * (sum(x₀[:, t] .* units.Hg .* units.p_max) + sum(current_Mw .* adjustablewindsVSCpower)) +
            fittingparameter[2] / sum(units.p_max) * (sum(x₀[:, t] .* units.Kg .* units.Fg ./ units.Rg .* units.p_max)) +
            fittingparameter[3] / sum(units.p_max) * (sum(x₀[:, t] .* units.Kg ./ units.Rg .* units.p_max)) +
            fittingparameter[4] / scalling_imbalanced_power
        δf[t, 2] = (f_base - f_nadir)
    end

    #? checking fcr constraints
    rhs_fcr = zeros(NG, NT)
    for g in 1:NG
        for t in 1:NT
            rhs_fcr[g, t] = units.Kg[g, 1] / units.Rg[g, 1] * (f_base - f_nadir) * 0.025 * x₀[g, t]
        end
    end

    formatted_rhs_fcr = map(x -> @sprintf("%.5g", x), rhs_fcr)
    formatted_r⁺ = map(x -> @sprintf("%.5g", x), r⁺)

    # filepath = pwd()
    # df = XLSX.readxlsx(filepath * "\\case1\\data\\data.xlsx")
    # filepath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/littlecase/"

    if Sys.isapple()
        filepath = "/Users/yuanyiping/Documents/GitHub/RFCUC/RfcucCaseStudies/littlecase/output/"
    elseif Sys.iswindows()
        filepath = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\"
    end
    open(filepath * "Pros_enhance_with_FCR_calculation_result_fcr" * "$fcr_thres" * ".txt", "w") do io
        writedlm(io, [" "])
        writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr⁺" "cr⁻" "𝜟pd" "𝜟pw"], '\t')
        writedlm(io, str, '\t')
        writedlm(io, [" "])
        writedlm(io, ["δf"], '\t')
        writedlm(io, δf, '\t')
        writedlm(io, [" "])
        writedlm(io, ["rhs_fcr"], '\t')
        writedlm(io, [" "])
        writedlm(io, formatted_rhs_fcr, '\t')
        writedlm(io, ["list 1: units stutup/down states"])
        writedlm(io, JuMP.value.(x), '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 2: units dispatching power in scenario NO.1"])
        writedlm(io, JuMP.value.(pg₀[1:NG, 1:NT]), '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 3: spolied wind power"])
        writedlm(io, JuMP.value.(Δpw[1:NW, 1:NT]), '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 4: forced load curtailments"])
        writedlm(io, JuMP.value.(Δpd[1:ND, 1:NT]), '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 5: pss charge state"])
        writedlm(io, pss_charge_state⁺[1:NC, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 6: pss discharge state"])
        writedlm(io, pss_charge_state⁻[1:NC, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 7: pss charge power"])
        writedlm(io, pss_charge_p⁺[1:NC, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 8: pss discharge power"])
        writedlm(io, pss_charge_p⁻[1:NC, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 9: pss strored energy"])
        writedlm(io, pss_charge_q[1:NC, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 10: sr⁺"])
        writedlm(io, formatted_r⁺[1:NG, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 11: sr⁻"])
        writedlm(io, r⁻[1:NG, 1:NT], '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 12: α"])
        writedlm(io, JuMP.value.(α[1:NC, 1:NT]), '\t')
        writedlm(io, [" "])
        writedlm(io, ["list 13: β"])
        return writedlm(io, JuMP.value.(β[1:NC, 1:NT]), '\t')
    end

    println("the calculation_result has been saved into | calculation_result.txt |\t done")
    println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

    return x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cr⁺, cr⁻
end
