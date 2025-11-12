function exported_scheduling_cost(
    NS::Int64,
    NT::Int64,
    NB::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NH::Int64,
    units::unit,
    loads::load,
    winds::wind,
    lines::transmissionline,
    DataCentras::data_centra,
    config_param::config,
    interval_scheduling_id,
    su_cost,
    sd_cost,
    pgₖ,
    pg₀,
    x₀,
    seq_sr⁺,
    seq_sr⁻,
    pᵨ,
    pᵩ,
    eachslope,
    refcost,
    pss_charge_state⁺ = nothing,
    pss_charge_state⁻ = nothing,
    pss_charge_p⁺ = nothing,
    pss_charge_p⁻ = nothing,
    pss_Qc = nothing,
    dc_p_res = nothing,
    dc_f_res = nothing,
    dc_v²_res = nothing,
    dc_λ_res = nothing,
    dc_Δu1_res = nothing,
    dc_Δu2_res = nothing,
    ph = nothing,
)
    c₀ = config_param.is_CoalPrice  # Base cost of coal
    pₛ = scenarios_prob  # Probability of scenarios

    # Penalty coefficients for load and wind curtailment
    load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
    wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

    ρ⁺ = c₀ * 2
    ρ⁻ = c₀ * 2

    rounded_x₀ = map(x -> x >= 0.5 ? Int64(1) : Int64(0), round.(x₀, digits = 0))

    prod_cost =
        pₛ *
        c₀ *
        (
            sum(
                sum(
                    sum(sum(pgₖ[i+(s-1)*NG, t, :] .* eachslope[:, i] for t = 1:NT)) for
                    s = 1:NS
                ) for i = 1:NG
            ) + sum(sum(sum(x₀[:, t] .* refcost[:, 1] for t = 1:NT)) for s = 1:NS)
        )
    cr⁺ =
        pₛ *
        c₀ *
        sum(sum(sum(ρ⁺ * seq_sr⁺[i+(s-1)*NG, t] for i = 1:NG) for t = 1:NT) for s = 1:NS)
    cr⁻ =
        pₛ *
        c₀ *
        sum(sum(sum(ρ⁺ * seq_sr⁻[i+(s-1)*NG, t] for i = 1:NG) for t = 1:NT) for s = 1:NS)
    # seq_sr⁺   = pₛ * c₀ * sum(ρ⁺ * seq_sr⁺[i, :] for i in 1:NG)
    # seq_sr⁻   = pₛ * c₀ * sum(ρ⁺ * seq_sr⁻[i, :] for i in 1:NG)
    𝜟pd = pₛ * sum(sum(sum(pᵨ[(1+(s-1)*ND):(s*ND), t]) for t = 1:NT) for s = 1:NS)
    𝜟pw = pₛ * sum(sum(sum(pᵩ[(1+(s-1)*NW):(s*NW), t]) for t = 1:NT) for s = 1:NS)

    str = zeros(1, 7)
    str[1, 1] = sum(su_cost) * 1.0
    str[1, 2] = sum(sd_cost) * 1.0
    str[1, 3] = prod_cost
    str[1, 4] = cr⁺
    str[1, 5] = cr⁻
    str[1, 6] = 𝜟pd
    str[1, 7] = 𝜟pw

    # Set output directory for results
    # output_dir = joinpath(pwd(), "output")
    if Sys.iswindows()
        output_dir = "D:/GithubClonefiles/module_unitcommitment/output/"
    elseif Sys.isapple()
        output_dir = "/Users/yuanyiping/Documents/GitHub/module_unitcommitment/output/"
    end

    if interval_scheduling_id != 0
        # output_dir = joinpath(output_dir, "pcm_simulation_results")
        # output_dir = output_dir * "<interval_$interval_scheduling_id>"
        output_dir =
            output_dir *
            "details_schedule_results/pcm_simulation_results/intervels_[$interval_scheduling_id]/"
        mkpath(dirname(output_dir))
    end
    # Create directory if it doesn't exist
    try
        if interval_scheduling_id == 0
            output_file = joinpath(output_dir, "Bench_schedule_commitment_result.txt")
        else
            # output_dir = joinpath(output_dir, "pcm_simulation_results")
            # output_dir = output_dir * "<interval_$interval_scheduling_id>"
            output_file = joinpath(output_dir, "res_schedule_commitment_result.txt")
        end
        # Open output file for writing results

        open(output_file, "w") do io
            writedlm(io, [" "])
            writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr⁺" "cr⁻" "𝜟pd" "𝜟pw"], '\t')
            writedlm(io, str, '\t')
            writedlm(io, [" "])
            writedlm(io, ["list 1: units stutup/down states"])
            writedlm(io, rounded_x₀, '\t')
            writedlm(io, [" "])
            writedlm(io, ["list 2: units dispatching power in scenario NO.1"])
            writedlm(io, pg₀[1:NG, 1:NT], '\t')
            writedlm(io, [" "])
            writedlm(io, ["list 3: spolied wind power"])
            writedlm(io, pᵩ[1:NW, 1:NT], '\t')
            writedlm(io, [" "])
            writedlm(io, ["list 4: forced load curtailments"])
            writedlm(io, pᵨ[1:ND, 1:NT], '\t')
            writedlm(io, [" "])
            if config_param.is_HydroUnitCon == 1
                writedlm(io, ["list 12: hydros output"])
                writedlm(io, ph[1:NH, 1:NT], '\t')
                writedlm(io, [" "])
            end
            if config_param.is_ConsiderBESS == 1
                writedlm(io, ["list 5: pss charge state"])
                writedlm(io, pss_charge_state⁺[1:NC, 1:NT], '\t')
                writedlm(io, ["list 6: pss discharge state"])
                writedlm(io, pss_charge_state⁻[1:NC, 1:NT], '\t')
                writedlm(io, ["list 7: pss charge power"])
                writedlm(io, pss_charge_p⁺[1:NC, 1:NT], '\t')
                writedlm(io, ["list 8: pss discharge power"])
                writedlm(io, pss_charge_p⁻[1:NC, 1:NT], '\t')
                writedlm(io, ["list 9: pss strored energy"])
                writedlm(io, pss_Qc[1:NC, 1:NT], '\t')
                writedlm(io, [" "])
            end
            writedlm(io, [" "])
            writedlm(io, ["list 10: sr⁺"])
            writedlm(io, seq_sr⁺[1:NG, 1:NT], '\t')
            writedlm(io, [" "])
            writedlm(io, ["list 11: sr⁻"])
            writedlm(io, seq_sr⁻[1:NG, 1:NT], '\t')
        end
        # writedlm(io, ["list 12: α"])
        # writedlm(io, α[1:NC, 1:NT], '\t')
        # writedlm(io, [" "])
        # writedlm(io, ["list 13: β"])
        # writedlm(io, β[1:NC, 1:NT], '\t')
        # end

        println(
            "PART1: [unit-commitment] calculation result has been saved to: $output_file",
        )

        if config_param.is_ConsiderBESS == 1 && NC > 0
            # Open output file for writing results

            if interval_scheduling_id == 0
                output_file = joinpath(output_dir, "Bench_bess_scheduling_result.txt")
            else
                # output_dir = joinpath(output_dir, "pcm_simulation_results")
                # output_dir = output_dir * "<interval_$interval_scheduling_id>"
                output_file = joinpath(output_dir, "res__bess_scheduling_result.txt")
            end
            open(output_file, "w") do io
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
                writedlm(io, pss_Qc[1:NC, 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 10: sr⁺"])
                writedlm(io, seq_sr⁺[1:NG, 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 11: sr⁻"])
                writedlm(io, seq_sr⁻[1:NG, 1:NT], '\t')
                return writedlm(io, [" "])
                # writedlm(io, ["list 12: α"])
                # writedlm(io, α[1:NC, 1:NT], '\t')
                # writedlm(io, [" "])
                # writedlm(io, ["list 13: β"])
                # writedlm(io, β[1:NC, 1:NT], '\t')
            end
            println("PART2: [BESS] calculation result has been saved to: $output_file")
        end

        if config_param.is_ConsiderDataCentra == 1 && ND2 > 0
            if interval_scheduling_id == 0
                output_file = joinpath(output_dir, "Bench_datacentra_result.txt")
            else
                # output_dir = joinpath(output_dir, "pcm_simulation_results")
                # output_dir = output_dir * "<interval_$interval_scheduling_id>"
                output_file = joinpath(output_dir, "res_datacentra_scheduling_result.txt")
            end
            open(output_file, "w") do io
                writedlm(io, [" "])
                writedlm(io, ["list 1: dc_p"], '\t')
                writedlm(io, dc_p_res[1:(ND2), 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 2: dc_f"])
                writedlm(io, dc_f_res[1:(ND2), 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 3: dc_v²"])
                writedlm(io, dc_v²_res[1:(ND2), 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 4: dc_λ"])
                writedlm(io, dc_λ_res[1:(ND2), 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 5: dc_Δu1"])
                writedlm(io, dc_Δu1_res[1:(ND2), 1:NT], '\t')
                writedlm(io, [" "])
                writedlm(io, ["list 6: dc_Δu2"])
                return writedlm(io, dc_Δu2_res[1:(ND2), 1:NT], '\t')
            end
            println(
                "PART2: [data-centra] calculation result has been saved to: $output_file",
            )
            println(
                "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++",
            )

            # Open output file for csv writing results
            # output_dir = "D:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/"

            iter_num = 6
            coeff = 0.05
            iter_block = Int64(round(NT / iter_num))

            s = 1
            data_to_write = [
                ("dc_Δu2.csv", (dc_Δu2_res[1:(ND2), 1:NT])),
                ("dc_Δu1.csv", (dc_Δu1_res[1:(ND2), 1:NT])),
                ("dc_v².csv", (dc_v²_res[1:(ND2), 1:NT])),
                ("dc_λ.csv", (dc_λ_res[1:(ND2), 1:NT])),
                ("dc_f.csv", (dc_f_res[1:(ND2), 1:NT])),
                ("dc_p.csv", (dc_p_res[1:(ND2), 1:NT])),
                (
                    "dc_debug_tasks_1.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((1-1)*iter_block+1):(1*iter_block),
                    ])),
                ),
                (
                    "dc_debug_tasks_2.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((2-1)*iter_block+1):(2*iter_block),
                    ])),
                ),
                (
                    "dc_debug_tasks_3.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((3-1)*iter_block+1):(3*iter_block),
                    ])),
                ),
                (
                    "dc_debug_tasks_4.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((4-1)*iter_block+1):(4*iter_block),
                    ])),
                ),
                (
                    "dc_debug_tasks_5.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((5-1)*iter_block+1):(5*iter_block),
                    ])),
                ),
                (
                    "dc_debug_tasks_6.csv",
                    ((dc_λ_res[
                        ((s-1)*ND2+1):(s*ND2),
                        ((6-1)*iter_block+1):(6*iter_block),
                    ])),
                ),
            ]

            # iter = 1
            # println("===============================================================================")
            # @show (1 + coeff) * sum(DataCentras.λ) * iter_block .*
            # 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
            # @show (1 - coeff) * sum(DataCentras.λ) * iter_block .*
            # 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
            # @show sum(JuMP.value.(dc_λ[
            # 	((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)])) .*
            # 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])

            sub_output_dir = joinpath(pwd(), "output/data_centra/")
            for (filename, data) in data_to_write
                filepath = joinpath(sub_output_dir, filename)
                try
                    CSV.write(filepath, DataFrame(data, :auto))
                    println("Successfully wrote to $filepath")
                catch e
                    @error "Failed to write to $filepath" exception = (e, catch_backtrace())
                end
            end
        end

    catch e
        println("Error writing results to file: $e")
    end

    return str
end
