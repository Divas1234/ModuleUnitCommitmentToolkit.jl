using Printf

function boundrycondition(
    NB::Int64,
    NL::Int64,
    NG::Int64,
    NT::Int64,
    ND::Int64,
    units::unit,
    loads::load,
    lines::transmissionline,
    winds::wind,
    stroges::stroge
)

    NS = winds.scenarios_nums
    NW = length(winds.index)

    # verify data
    println("\t\t\t\t\t")
    println("total info+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("NB>>\t\t\t\t\t\t", NB)
    println("NL>>\t\t\t\t\t\t", NL)
    println("NG>>\t\t\t\t\t\t", NG)
    println("ND>>\t\t\t\t\t\t", ND)
    println("NT>>\t\t\t\t\t\t", NT)
    println("Nw>>\t\t\t\t\t\t", NW)
    println("NT>>\t\t\t\t\t\t", NS)

    println("\t\t\t\t\t")
    println("config_info+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("config_param.is_NetWorkCon>>\t\t\t", config_param.is_NetWorkCon)
    println("config_param.is_ThermalUnitCon>>\t\t", config_param.is_ThermalUnitCon)
    println("config_param.is_WindUnitCon>>\t\t\t", config_param.is_WindUnitCon)
    println("config_param.is_SysticalCon>>\t\t\t", config_param.is_SysticalCon)
    println("config_param.is_PieceLinear>>\t\t\t", config_param.is_PieceLinear)
    println("config_param.is_NumSeg>>\t\t\t", config_param.is_NumSeg)
    println("config_param.is_Alpha>>\t\t\t\t", config_param.is_Alpha)
    println("config_param.is_Belta>>\t\t\t\t", config_param.is_Belta)
    println("config_param.is_CoalPrice>>\t\t\t", config_param.is_CoalPrice)
    println("config_param.is_ActiveLoad>>\t\t\t", config_param.is_ActiveLoad)
    println("config_param.is_WindIntegration>>\t\t", config_param.is_WindIntegration)
    println("config_param.is_LoadsCuttingCoefficient>>\t", config_param.is_LoadsCuttingCoefficient)
    println("config_param.is_WindsCuttingCoefficient>>\t", config_param.is_WindsCuttingCoefficient)
    println("config_param.is_MaxIterationsNum>>\t\t", config_param.is_MaxIterationsNum)
    println("config_param.is_CalculPrecision>>\t\t", config_param.is_CalculPrecision)

    println("\t\t\t\t\t")
    println("units_info+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("units.index>>\t\t\t\t\t", units.index)
    println("units.locatebus>>\t\t\t\t", units.locatebus)
    println("units.p_max>>\t\t\t\t\t", units.p_max)
    println("units.p_min>>\t\t\t\t\t", units.p_min)
    println("units.ramp_up>>\t\t\t\t\t", units.ramp_up)
    println("units.ramp_down>>\t\t\t\t", units.ramp_down)
    println("units.shut_up>>\t\t\t\t\t", units.shut_up)
    println("units.shut_down>>\t\t\t\t", units.shut_down)
    println("units.min_shutup_time>>\t\t\t\t", units.min_shutup_time)
    println("units.min_shutdown_time>>\t\t\t", units.min_shutdown_time)
    println("units.x_0>>\t\t\t\t\t", units.x_0)
    println("units.t_0>>\t\t\t\t\t", units.t_0)
    println("units.p_0>>\t\t\t\t\t", units.p_0)
    println("units.coffi_a>>\t\t\t\t\t", units.coffi_a)
    println("units.coffi_b>>\t\t\t\t\t", units.coffi_b)
    println("units.coffi_c>>\t\t\t\t\t", units.coffi_c)
    println("units.coffi_cold_shutup_1>>\t\t\t", units.coffi_cold_shutup_1)
    println("units.coffi_cold_shutup_2>>\t\t\t", units.coffi_cold_shutup_2)
    println("units.coffi_cold_shutdown_1>>\t\t\t", units.coffi_cold_shutdown_1)
    println("units.coffi_cold_shutdown_2>>\t\t\t", units.coffi_cold_shutdown_2)

    println("\t\t\t\t\t")
    println("loads_info+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("loads.index>>\t\t\t\t\t", loads.index)
    println("loads.locatebus>>\t\t\t\t", loads.locatebus)
    println("loads.load_curve>>")
    for i in 1:ND
        for j in 1:NT
            @printf("%0.3f\t", loads.load_curve[i, j])
        end
        #     println("\t\t\t\t\t")
    end
    # loads.load_curve

    println("\t\t\t\t\t")
    println("lines_info+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("lines.from>>\t\t\t\t\t", lines.from)
    println("lines.to>>\t\t\t\t\t", lines.to)
    println("lines.x>>\t\t\t\t\t", lines.x)
    println("lines.p_max>>\t\t\t\t\t", lines.p_max)
    println("lines.p_min>>\t\t\t\t\t", lines.p_min)

    println("\t\t\t\t\t")
    println("winds_info+++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("winds.index>>\t\t\t\t\t", winds.index)
    println("winds.scenarios_prob>>\t\t\t\t", winds.scenarios_prob)
    println("winds.scenarios_nums>>\t\t\t\t", winds.scenarios_nums)
    println("winds.p_max>>\t\t\t\t\t", winds.p_max)
    println("winds.scenarios_curve>>\t\t\t\t\t")
    println("winds.p_max>>\t\t\t\t\t", winds.scenarios_curve)

    println("\t\t\t\t\t")
    println("pss_info+++++++++++++++++++++++++++++++++++++++++++++++++++++")
    println("\t\t\t\t\t")
    println("stroges.index>>\t\t\t\t\t",stroges.index)
    println("stroges.locatebus>>\t\t\t\t",stroges.locatebus)
    println("stroges.q_max>>\t\t\t\t\t",stroges.Q_max)
    println("stroges.q_min>>\t\t\t\t\t",stroges.Q_min)
    println("stroges.p⁺>>\t\t\t\t\t",stroges.p⁺)
    println("stroges.p⁻>>\t\t\t\t\t",stroges.p⁻)
    println("stroges.P₀>>\t\t\t\t\t",stroges.P₀)
    println("stroges.γ⁺>>\t\t\t\t\t",stroges.γ⁺)
    println("stroges.γ⁻>>\t\t\t\t\t",stroges.γ⁻)
    println("stroges.η⁺>>\t\t\t\t\t",stroges.η⁺)
    println("stroges.η⁻>>\t\t\t\t\t",stroges.η⁻)
    println("stroges.δₛ>>\t\t\t\t\t",stroges.δₛ)

end
