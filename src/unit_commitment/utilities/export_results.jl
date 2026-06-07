using Dates

"""
	exported_scheduling_cost(...)

Export solved UC schedules into the repository `output/` directory. The export
contains both human-readable summaries and plotting/analysis-friendly CSV files:

- `schedule_commitment_result.txt`
- `schedule_cost_summary.csv`
- `unit_commitment_status.csv`
- `unit_startup_shutdown_decisions.csv`
- `unit_startup_shutdown_costs.csv`
- `generator_dispatch.csv`
- `reserve_schedule.csv`
- `curtailment_schedule.csv`
- `power_balance_summary.csv`
- `data_center_schedule.csv` when data centers are enabled
- `bess_schedule.csv` when BESS is enabled
"""
function exported_scheduling_cost(
		NS::Int64,
		NT::Int64,
		NB::Int64,
		NG::Int64,
		ND::Int64,
		NC::Int64,
		ND2::Int64,
		units::unit,
		loads::load,
		winds::wind,
		lines::transmissionline,
		DataCentras::data_centra,
		config_param::config,
		scenarios_prob,
		su_cost,
		sd_cost,
		pgₖ,
		pg₀,
		x₀,
		u₀,
		v₀,
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
		dc_fv²_res = nothing,
		dc_fv²λ_res = nothing,
		dc_fv²_plus_res = nothing,
		dc_fv²_minus_res = nothing,
		dc_fv²λ_plus_res = nothing,
		;
		output_dir_override = nothing,
		file_prefix::AbstractString = "",
)
	output_dir = uc_output_dir(output_dir_override)
	NW = length(winds.index)
	cost_summary = compute_uc_cost_summary(
		NS,
		NT,
		NG,
		ND,
		NW,
		config_param,
		scenarios_prob,
		su_cost,
		sd_cost,
		pgₖ,
		x₀,
		seq_sr⁺,
		seq_sr⁻,
		pᵨ,
		pᵩ,
		eachslope,
		refcost,
	)

	write_cost_summary_csv(joinpath(output_dir, file_prefix * "schedule_cost_summary.csv"), cost_summary)
	rm(joinpath(output_dir, file_prefix * "unit_startup_shutdown.csv"); force = true)
	rm(joinpath(output_dir, "unit_startup_shutdown.csv"); force = true)
	write_commitment_csv(joinpath(output_dir, file_prefix * "unit_commitment_status.csv"), units, x₀, NT)
	write_startup_shutdown_decisions_csv(joinpath(output_dir, file_prefix * "unit_startup_shutdown_decisions.csv"), units, u₀, v₀, NT)
	write_startup_shutdown_costs_csv(joinpath(output_dir, file_prefix * "unit_startup_shutdown_costs.csv"), units, su_cost, sd_cost, NT)
	write_generator_dispatch_csv(joinpath(output_dir, file_prefix * "generator_dispatch.csv"), units, pg₀, NT, NG, NS)
	write_reserve_schedule_csv(joinpath(output_dir, file_prefix * "reserve_schedule.csv"), units, seq_sr⁺, seq_sr⁻, NT, NG, NS)
	write_curtailment_schedule_csv(joinpath(output_dir, file_prefix * "curtailment_schedule.csv"), loads, winds, pᵨ, pᵩ, NT, ND, NW, NS)
	write_power_balance_summary_csv(
		joinpath(output_dir, file_prefix * "power_balance_summary.csv"),
		loads,
		winds,
		pg₀,
		pᵨ,
		pᵩ,
		NT,
		NG,
		ND,
		NW,
		NS,
		config_param,
		NC,
		pss_charge_p⁺,
		pss_charge_p⁻,
		ND2,
		dc_p_res,
	)

	if config_param.is_ConsiderBESS == 1 && NC > 0
		write_bess_schedule_csv(
			joinpath(output_dir, file_prefix * "bess_schedule.csv"),
			pss_charge_state⁺,
			pss_charge_state⁻,
			pss_charge_p⁺,
			pss_charge_p⁻,
			pss_Qc,
			NT,
			NC,
			NS,
		)
	end

	if config_param.is_ConsiderDataCentra == 1 && ND2 > 0
		write_data_center_schedule_csv(
			joinpath(output_dir, file_prefix * "data_center_schedule.csv"),
			DataCentras,
			dc_p_res,
			dc_fv²_res,
			dc_fv²λ_res,
			dc_fv²_plus_res,
			dc_fv²_minus_res,
			dc_fv²λ_plus_res,
			NT,
			ND2,
			NS,
		)
	end

	write_schedule_summary_txt(
		joinpath(output_dir, file_prefix * "schedule_commitment_result.txt"),
		cost_summary,
		units,
		x₀,
		u₀,
		v₀,
		pg₀,
		seq_sr⁺,
		seq_sr⁻,
		NT,
		NG,
	)

	println("UC scheduling results saved to: $output_dir")
	return cost_summary
end

function uc_output_dir(output_dir_override = nothing)
	output_dir = output_dir_override === nothing ? get(ENV, "MODULE_UC_OUTPUT_DIR", joinpath(pwd(), "output")) : String(output_dir_override)
	mkpath(output_dir)
	return output_dir
end

function uc_run_id()
	return get(ENV, "MODULE_UC_RUN_ID", Dates.format(now(), "yyyymmdd_HHMMSS"))
end

function uc_algorithm_run_dir(algorithm_name::AbstractString; run_id::AbstractString = uc_run_id())
	return joinpath(pwd(), "output", algorithm_name, run_id)
end

function uc_scheduling_output_dir(algorithm_name::AbstractString; run_id::AbstractString = uc_run_id())
	output_dir = joinpath(uc_algorithm_run_dir(algorithm_name; run_id = run_id), "scheduling")
	mkpath(output_dir)
	return output_dir
end

function uc_schedule_file_prefix(algorithm_name::AbstractString, scenario_count::Integer)
	return "$(algorithm_name)_$(scenario_count)_scenarios_"
end

function model_value(model, variable_name::Symbol)
	object_dictionary = JuMP.object_dictionary(model)
	if !haskey(object_dictionary, variable_name)
		throw(KeyError(variable_name))
	end
	return JuMP.value.(model[variable_name])
end

function optional_model_value(model, variable_name::Symbol)
	object_dictionary = JuMP.object_dictionary(model)
	if !haskey(object_dictionary, variable_name)
		return nothing
	end
	variable_container = model[variable_name]
	return isempty(variable_container) ? nothing : JuMP.value.(variable_container)
end

function export_solved_uc_model_results(
		model,
		data;
		output_dir::AbstractString = joinpath(pwd(), "output"),
		winds = data.winds,
		NS::Int64 = Int64(winds.scenarios_nums),
		scenarios_prob = 1.0 / NS,
		file_prefix::AbstractString = "",
)
	refcost, eachslope = linearizationfuelcurve(data.units, data.NG)
	config_param = data.config_param

	x₀ = model_value(model, :x)
	u₀ = model_value(model, :u)
	v₀ = model_value(model, :v)
	pg₀ = model_value(model, :pg₀)
	pgₖ = model_value(model, :pgₖ)
	su_cost = model_value(model, :su₀)
	sd_cost = model_value(model, :sd₀)
	seq_sr⁺ = model_value(model, :sr⁺)
	seq_sr⁻ = model_value(model, :sr⁻)
	pᵨ = model_value(model, :Δpd)
	pᵩ = model_value(model, :Δpw)

	pss_charge_state⁺ = optional_model_value(model, :κ⁺)
	pss_charge_state⁻ = optional_model_value(model, :κ⁻)
	pss_charge_p⁺ = optional_model_value(model, :pc⁺)
	pss_charge_p⁻ = optional_model_value(model, :pc⁻)
	pss_Qc = optional_model_value(model, :qc)

	dc_p_res = optional_model_value(model, :dc_p)
	dc_fv²_res = optional_model_value(model, :dc_fv²)
	dc_fv²λ_res = optional_model_value(model, :dc_fv²λ)
	dc_fv²_plus_res = optional_model_value(model, :dc_fv²_plus)
	dc_fv²_minus_res = optional_model_value(model, :dc_fv²_minus)
	dc_fv²λ_plus_res = optional_model_value(model, :dc_fv²λ_plus)

	return exported_scheduling_cost(
		NS,
		data.NT,
		data.NB,
		data.NG,
		data.ND,
		data.NC,
		data.ND2,
		data.units,
		data.loads,
		winds,
		data.lines,
		data.DataCentras,
		config_param,
		scenarios_prob,
		su_cost,
		sd_cost,
		pgₖ,
		pg₀,
		x₀,
		u₀,
		v₀,
		seq_sr⁺,
		seq_sr⁻,
		pᵨ,
		pᵩ,
		eachslope,
		refcost,
		pss_charge_state⁺,
		pss_charge_state⁻,
		pss_charge_p⁺,
		pss_charge_p⁻,
		pss_Qc,
		dc_p_res,
		dc_fv²_res,
		dc_fv²λ_res,
		dc_fv²_plus_res,
		dc_fv²_minus_res,
		dc_fv²λ_plus_res;
		output_dir_override = output_dir,
		file_prefix = file_prefix,
	)
end

function scenario_row(entity_count::Int, scenario::Int, entity::Int)
	return (scenario - 1) * entity_count + entity
end

function compute_uc_cost_summary(NS, NT, NG, ND, NW, config_param, scenarios_prob, su_cost, sd_cost, pgₖ, x₀, seq_sr⁺, seq_sr⁻, pᵨ, pᵩ, eachslope, refcost)
	c0 = config_param.is_CoalPrice
	ps = scenarios_prob
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient
	reserve_price_up = 2 * c0
	reserve_price_down = 2 * c0

	startup_cost = sum(su_cost)
	shutdown_cost = sum(sd_cost)
	variable_fuel_cost = ps * c0 * sum(pgₖ[scenario_row(NG, s, g), t, k] * eachslope[k, g] for s in 1:NS, g in 1:NG, t in 1:NT, k in axes(pgₖ, 3))
	no_load_cost = ps * c0 * sum(x₀[g, t] * refcost[g, 1] for s in 1:NS, g in 1:NG, t in 1:NT)
	reserve_up_cost = ps * c0 * sum(reserve_price_up * seq_sr⁺[scenario_row(NG, s, g), t] for s in 1:NS, g in 1:NG, t in 1:NT)
	reserve_down_cost = ps * c0 * sum(reserve_price_down * seq_sr⁻[scenario_row(NG, s, g), t] for s in 1:NS, g in 1:NG, t in 1:NT)
	load_curtailment_cost = ps * load_curtailment_penalty * sum(max(pᵨ[scenario_row(ND, s, d), t], 0.0) for s in 1:NS, d in 1:ND, t in 1:NT)
	wind_curtailment_cost = ps * wind_curtailment_penalty * sum(max(pᵩ[scenario_row(NW, s, w), t], 0.0) for s in 1:NS, w in 1:NW, t in 1:NT)
	total_cost = startup_cost + shutdown_cost + variable_fuel_cost + no_load_cost + reserve_up_cost + reserve_down_cost + load_curtailment_cost + wind_curtailment_cost

	return (
		startup_cost = startup_cost,
		shutdown_cost = shutdown_cost,
		variable_fuel_cost = variable_fuel_cost,
		no_load_cost = no_load_cost,
		reserve_up_cost = reserve_up_cost,
		reserve_down_cost = reserve_down_cost,
		load_curtailment_cost = load_curtailment_cost,
		wind_curtailment_cost = wind_curtailment_cost,
		total_cost = total_cost,
	)
end

function write_rows_csv(path::AbstractString, header, rows)
	open(path, "w") do io
		writedlm(io, reshape(collect(header), 1, :), ',')
		for row in rows
			writedlm(io, reshape(collect(row), 1, :), ',')
		end
	end
	return path
end

function write_cost_summary_csv(path, cost_summary)
	rows = (Any[string(name), getfield(cost_summary, name)] for name in keys(cost_summary))
	return write_rows_csv(path, ["component", "value"], rows)
end

function write_commitment_csv(path, units, x, NT)
	unit_columns = ["unit_$(units.index[g])_commitment" for g in 1:length(units.index)]
	rows = (Any[t, [x[g, t] for g in 1:length(units.index)]...] for t in 1:NT)
	return write_rows_csv(path, ["time", unit_columns...], rows)
end

function write_startup_shutdown_decisions_csv(path, units, u, v, NT)
	startup_columns = ["unit_$(units.index[g])_startup" for g in 1:length(units.index)]
	shutdown_columns = ["unit_$(units.index[g])_shutdown" for g in 1:length(units.index)]
	rows = (
		Any[
			t,
			[u[g, t] for g in 1:length(units.index)]...,
			[v[g, t] for g in 1:length(units.index)]...,
		] for t in 1:NT
	)
	return write_rows_csv(path, ["time", startup_columns..., shutdown_columns...], rows)
end

function write_startup_shutdown_costs_csv(path, units, su_cost, sd_cost, NT)
	startup_cost_columns = ["unit_$(units.index[g])_startup_cost" for g in 1:length(units.index)]
	shutdown_cost_columns = ["unit_$(units.index[g])_shutdown_cost" for g in 1:length(units.index)]
	rows = (
		Any[
			t,
			[su_cost[g, t] for g in 1:length(units.index)]...,
			[sd_cost[g, t] for g in 1:length(units.index)]...,
		] for t in 1:NT
	)
	return write_rows_csv(path, ["time", startup_cost_columns..., shutdown_cost_columns...], rows)
end

function write_generator_dispatch_csv(path, units, pg, NT, NG, NS)
	unit_columns = ["unit_$(units.index[g])_dispatch" for g in 1:NG]
	rows = (Any[s, t, [pg[scenario_row(NG, s, g), t] for g in 1:NG]...] for s in 1:NS, t in 1:NT)
	return write_rows_csv(path, ["scenario", "time", unit_columns...], rows)
end

function write_reserve_schedule_csv(path, units, reserve_up, reserve_down, NT, NG, NS)
	rows = (Any[s, units.index[g], t, reserve_up[scenario_row(NG, s, g), t], reserve_down[scenario_row(NG, s, g), t]] for s in 1:NS, g in 1:NG, t in 1:NT)
	return write_rows_csv(path, ["scenario", "unit_id", "time", "reserve_up", "reserve_down"], rows)
end

function write_curtailment_schedule_csv(path, loads, winds, load_curtailment, wind_curtailment, NT, ND, NW, NS)
	load_columns = ["load_$(loads.index[d])_curtailment" for d in 1:ND]
	wind_columns = ["wind_$(winds.index[w])_curtailment" for w in 1:NW]
	rows = (
		Any[
			s,
			t,
			[load_curtailment[scenario_row(ND, s, d), t] for d in 1:ND]...,
			[wind_curtailment[scenario_row(NW, s, w), t] for w in 1:NW]...,
		] for s in 1:NS, t in 1:NT
	)
	return write_rows_csv(path, ["scenario", "time", load_columns..., wind_columns...], rows)
end

function write_power_balance_summary_csv(path, loads, winds, pg, load_curtailment, wind_curtailment, NT, NG, ND, NW, NS, config_param, NC, bess_charge, bess_discharge, ND2, dc_power)
	rows = []
	for s in 1:NS, t in 1:NT
		thermal_generation = sum(pg[scenario_row(NG, s, g), t] for g in 1:NG)
		wind_available = sum(winds.scenarios_curve[s, t] * winds.p_max[w] for w in 1:NW)
		wind_spill = sum(wind_curtailment[scenario_row(NW, s, w), t] for w in 1:NW)
		load_total = sum(loads.load_curve[d, t] for d in 1:ND)
		load_shed = sum(load_curtailment[scenario_row(ND, s, d), t] for d in 1:ND)
		bess_charge_total = (config_param.is_ConsiderBESS == 1 && NC > 0 && bess_charge !== nothing) ? sum(bess_charge[scenario_row(NC, s, c), t] for c in 1:NC) : 0.0
		bess_discharge_total = (config_param.is_ConsiderBESS == 1 && NC > 0 && bess_discharge !== nothing) ? sum(bess_discharge[scenario_row(NC, s, c), t] for c in 1:NC) : 0.0
		data_center_load = (config_param.is_ConsiderDataCentra == 1 && ND2 > 0 && dc_power !== nothing) ? sum(dc_power[scenario_row(ND2, s, dc), t] for dc in 1:ND2) : 0.0
		net_balance = thermal_generation + wind_available - wind_spill + bess_discharge_total - bess_charge_total - (load_total - load_shed) - data_center_load
		push!(
			rows,
			Any[
				s,
				t,
				thermal_generation,
				wind_available - wind_spill,
				load_total - load_shed,
				data_center_load,
				bess_charge_total,
				bess_discharge_total,
				load_shed,
				wind_spill,
				net_balance,
			],
		)
	end
	return write_rows_csv(
		path,
		["scenario", "time", "thermal_generation", "wind_generation", "served_load", "data_center_load", "bess_charge", "bess_discharge", "load_shed", "wind_spill", "net_balance"],
		rows,
	)
end

function write_bess_schedule_csv(path, charge_state, discharge_state, charge_power, discharge_power, energy, NT, NC, NS)
	rows = (Any[s, c, t, charge_state[scenario_row(NC, s, c), t], discharge_state[scenario_row(NC, s, c), t], charge_power[scenario_row(NC, s, c), t], discharge_power[scenario_row(NC, s, c), t], energy[scenario_row(NC, s, c), t]] for s in 1:NS, c in 1:NC, t in 1:NT)
	return write_rows_csv(path, ["scenario", "storage_id", "time", "charge_state", "discharge_state", "charge_power", "discharge_power", "stored_energy"], rows)
end

function write_data_center_schedule_csv(path, DataCentras, dc_power, fv2, fv2lambda, fv2_plus, fv2_minus, fv2lambda_plus, NT, ND2, NS)
	rows = (Any[s, DataCentras.index[dc], t, dc_power[scenario_row(ND2, s, dc), t], fv2[scenario_row(ND2, s, dc), t], fv2lambda[scenario_row(ND2, s, dc), t], fv2_plus[scenario_row(ND2, s, dc), t], fv2_minus[scenario_row(ND2, s, dc), t], fv2lambda_plus[scenario_row(ND2, s, dc), t]] for s in 1:NS, dc in 1:ND2, t in 1:NT)
	return write_rows_csv(path, ["scenario", "data_center_id", "time", "power", "fv2", "fv2lambda", "fv2_plus", "fv2_minus", "fv2lambda_plus"], rows)
end

function write_schedule_summary_txt(path, cost_summary, units, commitment, startup, shutdown, dispatch, reserve_up, reserve_down, NT, NG)
	open(path, "w") do io
		println(io, "Unit Commitment Scheduling Summary")
		println(io, "==================================")
		println(io)
		println(io, "Cost Summary")
		for name in keys(cost_summary)
			println(io, "  ", rpad(string(name), 28), getfield(cost_summary, name))
		end
		println(io)
		println(io, "Unit Status by Time")
		writedlm(io, reshape(["unit_id"; ["t$t" for t in 1:NT]], 1, :), '\t')
		for g in 1:NG
			writedlm(io, reshape([units.index[g]; [commitment[g, t] for t in 1:NT]], 1, :), '\t')
		end
		println(io)
		println(io, "Startup Status by Time")
		writedlm(io, reshape(["unit_id"; ["t$t" for t in 1:NT]], 1, :), '\t')
		for g in 1:NG
			writedlm(io, reshape([units.index[g]; [startup[g, t] for t in 1:NT]], 1, :), '\t')
		end
		println(io)
		println(io, "Shutdown Status by Time")
		writedlm(io, reshape(["unit_id"; ["t$t" for t in 1:NT]], 1, :), '\t')
		for g in 1:NG
			writedlm(io, reshape([units.index[g]; [shutdown[g, t] for t in 1:NT]], 1, :), '\t')
		end
		println(io)
		println(io, "Scenario 1 Generator Dispatch")
		writedlm(io, reshape(["unit_id"; ["t$t" for t in 1:NT]], 1, :), '\t')
		for g in 1:NG
			writedlm(io, reshape([units.index[g]; [dispatch[g, t] for t in 1:NT]], 1, :), '\t')
		end
		println(io)
		println(io, "Scenario 1 Reserve Up / Reserve Down")
		writedlm(io, reshape(["unit_id", "time", "reserve_up", "reserve_down"], 1, :), '\t')
		for g in 1:NG, t in 1:NT
			writedlm(io, reshape([units.index[g], t, reserve_up[g, t], reserve_down[g, t]], 1, :), '\t')
		end
	end
	return path
end
