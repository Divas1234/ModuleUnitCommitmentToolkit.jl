using DelimitedFiles
using JLD2

#LINK -  exported details scheduled results as a .csv file
function save_details_scheduled_results(config_param, results; winds = nothing, output_dir = nothing)
    # Check if optimization was successful and extract results
    if results !== nothing
        println("Extracting results from dictionary...")
        bench_x₀ = results["x₀"]
        bench_p₀ = results["p₀"]
        bench_pᵨ = results["pᵨ"]
        bench_pᵩ = results["pᵩ"]
        bench_seq_sr⁺ = results["seq_sr⁺"]
        bench_seq_sr⁻ = results["seq_sr⁻"]
        bench_su_cost = results["su_cost"]
        bench_sd_cost = results["sd_cost"]

        if config_param.consider_bess == 1
            bench_pss_charge_p⁺ = get(results, "pss_charge_p⁺", nothing)
            bench_pss_charge_p⁻ = get(results, "pss_charge_p⁻", nothing)
        else
            bench_pss_charge_p⁺ = nothing
            bench_pss_charge_p⁻ = nothing
        end

        if config_param.consider_data_center == 1
            # Extract Data Centra results if they exist
            dc_p = get(results, "dc_p", nothing)
            dc_fv² = get(results, "dc_fv²", nothing)
            dc_fv²λ = get(results, "dc_fv²λ", nothing)
            dc_fv²_plus = get(results, "dc_fv²_plus", nothing)
            dc_fv²_minus = get(results, "dc_fv²_minus", nothing)
            dc_fv²λ_plus = get(results, "dc_fv²λ_plus", nothing)
        else
            dc_p = nothing
            dc_fv² = nothing
            dc_fv²λ = nothing
            dc_fv²_plus = nothing
            dc_fv²_minus = nothing
            dc_fv²λ_plus = nothing
        end
    else
        println("Optimization failed. Cannot proceed with saving results.")
        # Handle the error appropriately, maybe exit or skip saving
        # For now, just assign nothing to avoid errors in subsequent code if not handled
        bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻ = ntuple(_ -> nothing, 5)
    end

    # Save the balance results
    # Save the balance results (only if optimization succeeded)
    if results !== nothing && bench_p₀ !== nothing # Check if variables are valid
        savebalance_result(
            bench_p₀,
            bench_pᵨ,
            bench_pᵩ,
            bench_pss_charge_p⁺,
            bench_pss_charge_p⁻,
            1;
            config_param = config_param,
            winds = winds,
            output_dir = output_dir,
        )
    else
        println("Skipping saving results due to optimization failure.")
    end
end

#LINK -  save the main results as .txt file
function save_UCresults(
    x₀, bench_x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻,
    pss_charge_p⁺, pss_charge_p⁻,
    su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻,
    bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻,
    NT, NG, ND, NW, units, winds,
)
    output_path = joinpath(uc_output_dir(), "bench", "mydata_1.jld")
    mkpath(dirname(output_path))
    return save(
        output_path,
        "x₀", x₀,
        "p₀", p₀,
        "pᵨ", pᵨ,
        "pᵩ", pᵩ,
        "seq_sr⁺", seq_sr⁺,
        "seq_sr⁻", seq_sr⁻,
        "pss_charge_p⁺", pss_charge_p⁺,
        "pss_charge_p⁻", pss_charge_p⁻,
        "su_cost", su_cost,
        "sd_cost", sd_cost,
        "prod_cost", prod_cost,
        "cost_sr⁺", cost_sr⁺,
        "cost_sr⁻", cost_sr⁻,
        "NT", NT,
        "NG", NG,
        "ND", ND,
        "NW", NW,
        "winds", winds,
        "units", units,
        "bench_x₀", bench_x₀,
        "bench_p₀", bench_p₀,
        "bench_pᵨ", bench_pᵨ,
        "bench_pᵩ", bench_pᵩ,
        "bench_seq_sr⁺", bench_seq_sr⁺,
        "bench_seq_sr⁻", bench_seq_sr⁻,
        "bench_pss_charge_p⁺", bench_pss_charge_p⁺,
        "bench_pss_charge_p⁻", bench_pss_charge_p⁻,
        "bench_su_cost", bench_su_cost,
        "bench_sd_cost", bench_sd_cost,
        "bench_prod_cost", bench_prod_cost,
        "bench_cost_sr⁺", bench_cost_sr⁺,
        "bench_cost_sr⁻", bench_cost_sr⁻,
    )
end

function read_UCresults(output_path::AbstractString = joinpath(uc_output_dir(), "bench", "mydata_1.jld"))
    isfile(output_path) || throw(ArgumentError("UC results file not found: $(output_path)"))
    return JLD2.load(output_path)
end

function savebalance_result(
    bench_p₀,
    bench_pᵨ,
    bench_pᵩ,
    bench_pss_charge_p⁺,
    bench_pss_charge_p⁻,
    flag;
    config_param = nothing,
    winds = nothing,
    output_dir = nothing,
    scenario_index::Int = 1,
)
    nt = size(bench_p₀, 2)
    ns = (winds !== nothing && hasproperty(winds, :scenarios_nums)) ? max(1, Int(winds.scenarios_nums)) : 1
    s = clamp(scenario_index, 1, ns)
    _scenario_slice(mat) = begin
        nrows = size(mat, 1)
        (nrows == 0 || ns <= 1 || nrows % ns != 0) && return 1:nrows
        per = div(nrows, ns)
        return ((s - 1) * per + 1):(s * per)
    end
    gen_rows = _scenario_slice(bench_p₀)
    load_rows = _scenario_slice(bench_pᵨ)
    thermalunits_output = zeros(nt, 1)
    for i in 1:nt
        thermalunits_output[i, 1] = isempty(gen_rows) ? 0.0 : sum(@view bench_p₀[gen_rows, i])
    end

    windunits_output = zeros(nt, 1)
    if winds !== nothing && !isempty(winds.p_max)
        total_wind_cap = sum(winds.p_max)
        nw = length(winds.p_max)
        w_start = (s - 1) * nw + 1
        w_stop = min(s * nw, size(bench_pᵩ, 1))
        for i in 1:nt
            spill = w_start <= w_stop ? sum(@view bench_pᵩ[w_start:w_stop, i]) : 0.0
            windunits_output[i, 1] = total_wind_cap * winds.scenarios_curve[s, i] - spill
        end
    end

    forceloadcurtailment = zeros(nt, 1)
    for i in 1:nt
        forceloadcurtailment[i, 1] = isempty(load_rows) ? 0.0 : sum(@view bench_pᵨ[load_rows, i])
    end

    BESScharging_output, BESSdischarging_output = zeros(nt, 1), zeros(nt, 1)
    consider_bess = config_param !== nothing && config_param.consider_bess == 1
    if consider_bess && bench_pss_charge_p⁺ !== nothing && bench_pss_charge_p⁻ !== nothing
        bess_rows = _scenario_slice(bench_pss_charge_p⁺)
        for i in 1:nt
            BESScharging_output[i, 1] = isempty(bess_rows) ? 0.0 : sum(@view bench_pss_charge_p⁺[bess_rows, i])
            BESSdischarging_output[i, 1] = isempty(bess_rows) ? 0.0 : sum(@view bench_pss_charge_p⁻[bess_rows, i])
        end
    end
    # Plots.plot(-bench_pss_charge_p⁺[1,:])
    # Plots.plot!(bench_pss_charge_p⁻[1,:])

    output_root = uc_output_dir(output_dir)
    if Sys.iswindows()
        if flag == 1
            filepath = joinpath(output_root, "details_schedule_results")
        elseif flag == 2
            filepath = output_root
        else
            flag == 3
            filepath = output_root
        end
    else
        filepath = joinpath(output_root, "details_schedule_results")
    end
    if !isdir(filepath)
        mkpath(filepath)
    end
    open(joinpath(filepath, "res_thermalunits.csv"), "w") do io
        # writedlm(io, [" "])
        return writedlm(io, thermalunits_output, '\t')
    end
    open(joinpath(filepath, "res_windunits.csv"), "w") do io
        # writedlm(io, [" "])
        return writedlm(io, windunits_output, '\t')
    end
    open(joinpath(filepath, "res_forcedloadcurtailment.csv"), "w") do io
        # writedlm(io, [" "])
        return writedlm(io, forceloadcurtailment, '\t')
    end
    open(joinpath(filepath, "res_bess_charging.csv"), "w") do io
        # writedlm(io, [" "])
        return writedlm(io, BESScharging_output, '\t')
    end
    open(joinpath(filepath, "res_bess_discharging.csv"), "w") do io
        # writedlm(io, [" "])
        return writedlm(io, BESSdischarging_output, '\t')
    end
    return println("details [unit_commtiemnt] scheduling results have been saved!")
end
