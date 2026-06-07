"""
`add_frequency_constraints!(...)`

Adds linear frequency-security constraints to the UC model.

The constraints use the same aggregate-frequency idea as the reference BFSFR
project: online synchronous units contribute inertia, damping, and primary
response in proportion to their online capacity; converter-interfaced wind can
optionally add virtual inertia/damping or droop response. The resulting model is
kept linear so it can be used by the monolithic UC model, CCG active master, and
Benders master problem.
"""
function add_frequency_constraints!(
		scuc::Model,
		NT,
		NG,
		NC,
		NS,
		units,
		stroges,
		config_param,
		Δp_contingency;
		winds = nothing,
)
	if config_param.is_ConsiderFrequencyControl == 0
		println("\t constraints: 13) frequency control constraints skipped (is_ConsiderFrequencyControl != 1)")
		return nothing
	end

	if !haskey(JuMP.object_dictionary(scuc), :x)
		println("\t constraints: 13) frequency control constraints skipped (x not defined)")
		return nothing
	end

	x = scuc[:x]
	frequency_base_hz = frequency_env_float("FREQUENCY_BASE_HZ", 50.0)
	rocof_limit_hz_per_s = frequency_env_float("FREQUENCY_ROCOF_LIMIT_HZ_PER_S", 5.0)
	qss_limit_hz = frequency_env_float("FREQUENCY_QSS_LIMIT_HZ", 5.0)
	nadir_limit_hz = frequency_env_float("FREQUENCY_NADIR_LIMIT_HZ", qss_limit_hz)
	nadir_response_weight = frequency_env_float("FREQUENCY_NADIR_RESPONSE_WEIGHT", 1.0)

	contingency = max(0.0, Float64(Δp_contingency))
	rocof_pu_per_s = max(rocof_limit_hz_per_s / frequency_base_hz, eps(Float64))
	qss_pu = max(qss_limit_hz / frequency_base_hz, eps(Float64))
	nadir_pu = max(nadir_limit_hz / frequency_base_hz, eps(Float64))

	min_inertia = max(frequency_env_float("FREQUENCY_MIN_INERTIA", 0.0), contingency / (2.0 * rocof_pu_per_s))
	min_qss_response = max(frequency_env_float("FREQUENCY_MIN_QSS_RESPONSE", 0.0), contingency / qss_pu)
	min_nadir_response = max(frequency_env_float("FREQUENCY_MIN_NADIR_RESPONSE", 0.0), contingency / nadir_pu)
	min_primary_response = frequency_env_float("FREQUENCY_MIN_PRIMARY_RESPONSE", 0.0)

	thermal_inertia = @expression(scuc, [t = 1:NT],
		sum(safe_frequency_coeff(units.Hg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in 1:NG))
	thermal_damping = @expression(scuc, [t = 1:NT],
		sum(safe_frequency_coeff(units.Dg, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in 1:NG))
	thermal_primary = @expression(scuc, [t = 1:NT],
		sum(unit_primary_response_coeff(units, i) * safe_frequency_coeff(units.p_max, i) * x[i, t] for i in 1:NG))

	wind_inertia, wind_damping, wind_primary = build_wind_frequency_support(scuc, winds, NS, NT)

	rocof_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
		thermal_inertia[t] + wind_inertia[s, t] >= min_inertia)
	qss_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
		thermal_damping[t] + thermal_primary[t] + wind_damping[s, t] + wind_primary[s, t] >= min_qss_response)
	nadir_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
		thermal_inertia[t] + wind_inertia[s, t] +
		nadir_response_weight * (thermal_damping[t] + thermal_primary[t] + wind_damping[s, t] + wind_primary[s, t]) >= min_nadir_response)
	primary_constr = @constraint(scuc, [s = 1:NS, t = 1:NT],
		thermal_primary[t] + wind_primary[s, t] >= min_primary_response)

	println("\t constraints: 13) frequency control constraints\t\t\t done")
	return (
		rocof = rocof_constr,
		qss = qss_constr,
		nadir = nadir_constr,
		primary = primary_constr,
	)
end

function frequency_env_float(name::String, default::Float64)
	return parse(Float64, get(ENV, name, string(default)))
end

function safe_frequency_coeff(values, index::Int64; default::Float64 = 0.0)
	if values === nothing || index > length(values)
		return default
	end
	value = Float64(values[index])
	return isfinite(value) ? value : default
end

function unit_primary_response_coeff(units, index::Int64)
	kg = safe_frequency_coeff(units.Kg, index)
	rg = safe_frequency_coeff(units.Rg, index; default = 1.0)
	if abs(rg) <= eps(Float64)
		return 0.0
	end
	return max(0.0, kg / rg)
end

function build_wind_frequency_support(scuc::Model, winds, NS::Int64, NT::Int64)
	if winds === nothing
		zero_support = @expression(scuc, [s = 1:NS, t = 1:NT], 0.0)
		return zero_support, zero_support, zero_support
	end

	NW = length(winds.index)
	wind_inertia = @expression(scuc, [s = 1:NS, t = 1:NT],
		sum(wind_virtual_inertia_coeff(winds, w) * wind_available_power(winds, w, s, t) for w in 1:NW))
	wind_damping = @expression(scuc, [s = 1:NS, t = 1:NT],
		sum(wind_virtual_damping_coeff(winds, w) * wind_available_power(winds, w, s, t) for w in 1:NW))
	wind_primary = @expression(scuc, [s = 1:NS, t = 1:NT],
		sum(wind_droop_response_coeff(winds, w) * wind_available_power(winds, w, s, t) for w in 1:NW))
	return wind_inertia, wind_damping, wind_primary
end

function wind_available_power(winds, wind_index::Int64, scenario::Int64, time_index::Int64)
	scenario_index = min(scenario, size(winds.scenarios_curve, 1))
	time_column = min(time_index, size(winds.scenarios_curve, 2))
	return max(0.0, winds.scenarios_curve[scenario_index, time_column] * safe_frequency_coeff(winds.p_max, wind_index))
end

function wind_virtual_inertia_coeff(winds, wind_index::Int64)
	return wind_frequency_mode(winds, wind_index) >= 1.5 ? max(0.0, safe_frequency_coeff(winds.Mw, wind_index)) : 0.0
end

function wind_virtual_damping_coeff(winds, wind_index::Int64)
	return wind_frequency_mode(winds, wind_index) >= 1.5 ? max(0.0, safe_frequency_coeff(winds.Dw, wind_index)) : 0.0
end

function wind_droop_response_coeff(winds, wind_index::Int64)
	if wind_frequency_mode(winds, wind_index) >= 1.5
		return 0.0
	end
	rw = safe_frequency_coeff(winds.Rw, wind_index; default = 1.0)
	if abs(rw) <= eps(Float64)
		return 0.0
	end
	return max(0.0, safe_frequency_coeff(winds.Kw, wind_index) / rw)
end

function wind_frequency_mode(winds, wind_index::Int64)
	return safe_frequency_coeff(winds.Fcmode, wind_index; default = 0.0)
end
