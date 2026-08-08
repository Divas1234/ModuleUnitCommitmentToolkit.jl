# ============================================================================
# Adaptive Overlapping Rolling-Horizon Unit Commitment Modules
#
# This module implements:
# 1. Classification of slow-start vs fast-start generators
# 2. Boundary sensitivity decay factor calculation for steady state
# 3. Strong net-load ramping event detection for tight-balance periods
# 4. Composite adaptive overlapping window calculation
# 5. Boundary condition transmission from committed execution windows
# ============================================================================
# include("period_scuc_modules.jl")

if !isdefined(@__MODULE__, :_ADAPTIVE_PERIOD_SCUC_MODULES_INCLUDED)
	const _ADAPTIVE_PERIOD_SCUC_MODULES_INCLUDED = true

	# include("period_scuc_modules.jl")
	include("overlap_predictor.jl")
	using .OverlapPredictor
	using LinearAlgebra, Statistics

	## 
	"""
		classify_generator_speed(units::unit; slow_threshold::Float64 = 4.0)

	Classify generators into slow-start and fast-start units based on minimum up/down times.

	# Arguments
	- `units`: A struct containing unit information
	- `slow_threshold`: The threshold for classifying slow-start units

	# Returns

	  - `slow_unit_indices::Vector{Int64}`: Indices of slow-start units
	  - `fast_unit_indices::Vector{Int64}`: Indices of fast-start units
	  - `T_unit_overlap::Int64`: Required overlap time to cover slow unit dwell constraints
	"""

	function classify_generator_speed(units::unit; slow_threshold::Float64 = 4.0)
		NG = length(units.index)
		slow_unit_indices = Int64[]
		fast_unit_indices = Int64[]
		max_slow_dwell = 0.0

		for i ∈ 1:NG
			max_dwell = max(units.min_shutup_time[i], units.min_shutdown_time[i])
			if max_dwell >= slow_threshold
				push!(slow_unit_indices, i)
				if max_dwell > max_slow_dwell
					max_slow_dwell = max_dwell
				end
			else
				push!(fast_unit_indices, i)
			end
		end

		T_unit_overlap = Int64(ceil(max_slow_dwell))
		return slow_unit_indices, fast_unit_indices, T_unit_overlap
	end

	## SECTION
	"""
		calculate_boundary_sensitivity_decay(alpha::Float64, epsilon::Float64)

	Calculate steady-state overlap window length based on boundary sensitivity decay factor alpha.
	Decay formula: S(k) = (1 - alpha)^k <= epsilon.

	# Returns

	  - `T_steady_overlap::Int64`: Minimum steady-state overlap window size
	"""
	function calculate_boundary_sensitivity_decay(alpha::Float64, epsilon::Float64)
		if alpha <= 0.0 || alpha >= 1.0
			error("Boundary sensitivity decay factor alpha must be in (0, 1). Got: $alpha")
		end
		# (1 - alpha)^k <= epsilon  =>  k >= log(epsilon) / log(1 - alpha)
		k = ceil(Int64, log(epsilon) / log(1.0 - alpha))
		return max(1, k)
	end

	"""
		detect_ramp_events_and_overlap(loads::load, winds::wind, start_time::Int64, exec_NT::Int64, max_lookahead::Int64, ramp_threshold_ratio::Float64 = 1.25, uncertainty_threshold_ratio::Float64 = 1.20)

	Detect net-load ramping and multi-scenario uncertainty events in the lookahead horizon and calculate required adaptive ramp/uncertainty overlap window.

	# Net Load Perspective:

	Net Load for scenario s at time t:
	P_net(s, t) = sum_d P_load,d(t) - sum_w P_wind_max,w * scenarios_curve(s, t)

	Both net-load ramp rate variations (|P_net(s, t+1) - P_net(s, t)|) and multi-scenario net-load volatility/uncertainty (std_s(P_net(s, t))) are evaluated to determine the lookahead overlap window.

	# Returns

	  - `is_ramp_event::Bool`: Whether a strong net-load ramp/uncertainty event is detected in the lookahead horizon
	  - `T_ramp_overlap::Int64`: Required overlap window length to envelop the net-load event
	"""
	function detect_ramp_events_and_overlap(loads::load, winds::wind, start_time::Int64, exec_NT::Int64, max_lookahead::Int64, ramp_threshold_ratio::Float64 = 1.25, uncertainty_threshold_ratio::Float64 = 1.20)
		total_time_avail = size(loads.load_curve, 2)
		end_horizon = min(total_time_avail, start_time + exec_NT + max_lookahead - 1)

		if end_horizon <= start_time + exec_NT
			return false, 0
		end

		# Aggregate system load P_load(t) across all buses
		total_load = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
		horizon_len = length(total_load)

		# Multi-scenario Wind Power & Net Load Matrix: NS × horizon_len
		NS = winds.scenarios_nums
		total_wind_cap = sum(winds.p_max)

		# Calculate multi-scenario Net Load: P_net(s, t) = P_load(t) - P_wind(s, t)
		net_load_matrix = zeros(NS, horizon_len)
		for s ∈ 1:NS
			net_load_matrix[s, :] = total_load .- (total_wind_cap .* winds.scenarios_curve[s, start_time:end_horizon])
		end

		# 1. Ramping rates of Net Load calculated scenario-by-scenario
		# R(s, t) = |P_net(s, t+1) - P_net(s, t)|
		# Find the earliest ramping event in the lookahead horizon across all scenarios
		lookahead_start_idx = exec_NT
		earliest_ramp_idx = nothing

		for s ∈ 1:NS
			# Ramping rates for this specific scenario
			scen_ramps = [abs(net_load_matrix[s, t + 1] - net_load_matrix[s, t]) for t ∈ 1:(horizon_len - 1)]
			mean_scen_ramp = mean(scen_ramps)
			scen_threshold = ramp_threshold_ratio * mean_scen_ramp

			# Lookahead ramp rates for this specific scenario
			lookahead_scen_ramps = scen_ramps[lookahead_start_idx:end]

			# Find first lookahead index exceeding the scenario-specific threshold
			scen_ramp_idx = findfirst(r -> r >= scen_threshold, lookahead_scen_ramps)
			if scen_ramp_idx !== nothing
				if earliest_ramp_idx === nothing
					earliest_ramp_idx = scen_ramp_idx
				else
					earliest_ramp_idx = min(earliest_ramp_idx, scen_ramp_idx)
				end
			end
		end

		# 2. Multi-scenario Net Load Uncertainty (standard deviation across scenarios)
		net_load_std = [std(net_load_matrix[:, t]) for t ∈ 1:horizon_len]
		mean_std = mean(net_load_std)
		std_threshold = uncertainty_threshold_ratio * mean_std
		lookahead_stds = net_load_std[lookahead_start_idx:end]

		# filter the possible strong ramping or high uncertainty events in the lookahead horizon.
		high_uncertainty_idx = findfirst(s_val -> s_val >= std_threshold && std_threshold > 1e-4, lookahead_stds)

		event_indices = Int64[]
		if earliest_ramp_idx !== nothing
			push!(event_indices, earliest_ramp_idx)
		end
		if high_uncertainty_idx !== nothing
			push!(event_indices, high_uncertainty_idx)
		end

		if !isempty(event_indices)
			first_event_idx = minimum(event_indices)
			# Required lookahead overlap to cover the net-load event plus 2h buffer
			T_ramp_overlap = first_event_idx + 2
			T_ramp_overlap = min(T_ramp_overlap, max_lookahead)
			return true, T_ramp_overlap
		else
			return false, 0
		end
	end

	"""
		TrainedLossModels

	A structure holding the calibrated parameters for regression and neural network models
	mapping normalized load, online capacity, boundary commitment deviation, and
	overlap size to subproblem solving accuracy loss.
	"""
	mutable struct TrainedLossModels
		mode::String
		beta::Vector{Float64}
		W1::Matrix{Float64}
		b1::Vector{Float64}
		W2::Matrix{Float64}
		b2::Float64
	end

	function TrainedLossModels(mode::String = "decay")
		# Default pre-set parameters
		# Regression features are:
		# [1, L_norm, U_norm, X_delta_norm, X_switch_ratio, H].
		# X_delta_norm and X_switch_ratio quantify how much the current
		# rolling-boundary commitment differs from the base initial state.
		beta = [-0.5, 0.8, -0.4, 0.6, 0.4, -0.3]
		W1 = [ 0.5   0.2   0.4   0.2  -1.2;
			  -0.3   0.4   0.3   0.1  -0.8;
			   0.7  -0.5   0.5   0.2  -1.5;
			  -0.2  -0.3   0.4   0.3  -1.0]
		b1 = [0.1, -0.2, 0.3, 0.0]
		W2 = [0.4 0.3 0.5 0.6]
		b2 = -0.1
		return TrainedLossModels(mode, beta, W1, b1, W2, b2)
	end

	"""
		predict_accuracy_loss_neural_network(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64)

	Evaluate a pre-trained feedforward neural network (1 hidden layer of 4 neurons)
	mapping normalized load level, normalized online unit capacity, boundary-state
	deviation, and candidate overlap window H to the predicted subproblem solving
	accuracy loss.
	"""
	function predict_accuracy_loss_neural_network(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64)
		# Inputs: normalized load, online capacity, boundary-state deviation,
		# switched-unit ratio, normalized overlap window H (H/12).
		x = [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H) / 12.0]

		# Predefined weights and biases (representing typical sensitivity characteristics)
		W1 = [ 0.5   0.2   0.4   0.2  -1.2;
			  -0.3   0.4   0.3   0.1  -0.8;
			   0.7  -0.5   0.5   0.2  -1.5;
			  -0.2  -0.3   0.4   0.3  -1.0]
		b1 = [0.1, -0.2, 0.3, 0.0]
		W2 = [0.4 0.3 0.5 0.6]
		b2 = -0.1

		hidden = tanh.(W1 * x + b1)
		output_raw = (W2 * hidden)[1] + b2
		loss = 1.0 / (1.0 + exp(-output_raw))
		return loss
	end

	"""
		predict_accuracy_loss_neural_network_custom(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64, models::TrainedLossModels)

	Evaluate neural network using calibrated weights.
	"""
	function predict_accuracy_loss_neural_network_custom(L_norm::Float64, U_norm::Float64, X_delta_norm::Float64, X_switch_ratio::Float64, H::Int64, models::TrainedLossModels)
		x = [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H) / 12.0]
		hidden = tanh.(models.W1 * x + models.b1)
		output_raw = (models.W2 * hidden)[1] + models.b2
		loss = 1.0 / (1.0 + exp(-output_raw))
		return loss
	end

	"""
		train_neural_network_backprop(X_data::Matrix{Float64}, Y_data::Vector{Float64}; epochs=600, lr=0.05)

	Simple gradient descent backpropagation to train feedforward neural network weights.
	"""
	function train_neural_network_backprop(X_data::Matrix{Float64}, Y_data::Vector{Float64}; epochs = 600, lr = 0.05)
		W1 = [ 0.5   0.2   0.4   0.2  -1.2;
			  -0.3   0.4   0.3   0.1  -0.8;
			   0.7  -0.5   0.5   0.2  -1.5;
			  -0.2  -0.3   0.4   0.3  -1.0]
		b1 = [0.1, -0.2, 0.3, 0.0]
		W2 = [0.4 0.3 0.5 0.6]
		b2 = -0.1

		N = size(X_data, 1)
		for epoch ∈ 1:epochs
			for i ∈ 1:N
				x = X_data[i, :]
				y = Y_data[i]

				# Forward
				h_raw = W1 * x + b1
				h = tanh.(h_raw)
				o_raw = (W2 * h)[1] + b2
				pred = 1.0 / (1.0 + exp(-o_raw))

				# Backward
				d_loss = pred - y
				d_o_raw = d_loss * pred * (1.0 - pred)

				d_W2 = d_o_raw .* h'
				d_b2 = d_o_raw

				d_h = W2' * d_o_raw
				d_h_raw = d_h .* (1.0 .- h .^ 2)

				d_W1 = d_h_raw * x'
				d_b1 = d_h_raw

				# Update
				W1 .-= lr .* d_W1
				b1 .-= lr .* d_b1
				W2 .-= lr .* d_W2
				b2 -= lr * d_b2
			end
		end
		return W1, b1, W2, b2
	end

	"""
		commitment_boundary_deviation(units::unit, x_0_curr::AbstractVector{<:Real}, x_ref_curr::Union{Nothing, AbstractVector{<:Real}} = nothing)

	Return capacity-weighted and count-based measures of how strongly the
	inherited rolling-boundary commitment differs from a local reference
	commitment. The preferred reference is the first-period commitment from a
	subproblem solved at the same start time while ignoring the prior interval's
	boundary conditions. If no reference is supplied, fall back to the original
	input boundary state.
	"""
	function commitment_boundary_deviation(units::unit, x_0_curr::AbstractVector{<:Real}, x_ref_curr::Union{Nothing, AbstractVector{<:Real}} = nothing)
		NG = length(units.index)
		total_capacity = sum(units.p_max)
		if total_capacity <= 0.0
			total_capacity = 1.0
		end
		x_ref = x_ref_curr === nothing ? units.x_0 : x_ref_curr
		x_base = Float64.(x_ref[1:NG] .> 0.5)
		x_curr = Float64.(x_0_curr[1:NG] .> 0.5)
		status_delta = abs.(x_curr .- x_base)
		X_delta_norm = clamp(sum(units.p_max[1:NG] .* status_delta) / total_capacity, 0.0, 1.0)
		X_switch_ratio = clamp(sum(status_delta) / NG, 0.0, 1.0)
		return X_delta_norm, X_switch_ratio
	end

	function commitment_deviation_decay_overlap(
			X_delta_norm::Float64, X_switch_ratio::Float64,
			epsilon_state::Float64, min_overlap::Int64, max_overlap::Int64;
			alpha_state::Float64 = 0.25)
		A0 = clamp(max(X_delta_norm, X_switch_ratio), 0.0, 1.0)
		if A0 <= epsilon_state
			return min_overlap
		end
		# Boundary commitment deviation is treated as an initial disturbance
		# amplitude A0. Its residual influence after H overlap hours follows
		# A(H) = A0 * (1 - alpha_state)^H. Larger inherited commitment
		# deviations therefore impose a longer steady-state overlap floor.
		H_state = ceil(Int64, log(epsilon_state / A0) / log(1.0 - alpha_state))
		return clamp(max(min_overlap, H_state), min_overlap, max_overlap)
	end

	"""
		solve_local_reference_commitment(...)

	Solve a local economic reference subproblem for the same rolling interval
	while intentionally ignoring the prior interval's inherited boundary
	conditions. Its first-period commitment is used as `x_ref_curr`, the local
	benchmark for measuring boundary-state deviation in T_steady.
	"""
	function solve_local_reference_commitment(
			loads::load, winds::wind, units::unit, lines::transmissionline,
			DataCentras::data_centra, config_param::config, stroges::Any,
			scenarios_prob::Float64, hydros::hydro, start_time::Int64,
			exec_NT::Int64, max_overlap::Int64, NB::Int64, NG::Int64,
			ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64,
			interval_scheduling_id::Int64 = 1)
		total_time_avail = size(loads.load_curve, 2)
		remaining_overlap = total_time_avail - (start_time + exec_NT - 1)
		reference_overlap = max(0, min(max_overlap, remaining_overlap))
		total_NT_ref = exec_NT + reference_overlap
		ref_units, ref_loads, ref_winds = update_adaptive_boundary_conditions(
			1, NG, exec_NT, total_NT_ref, start_time, units, loads, winds, nothing
		)
		ref_results = each_period_scucmodel_modules(
			total_NT_ref, NB, NG, ND, NC, ND2, ref_units, ref_loads, ref_winds,
			lines, DataCentras, config_param, stroges, scenarios_prob, NL,
			interval_scheduling_id, hydros, NH
		)
		if ref_results === nothing || !haskey(ref_results, "x₀")
			return nothing
		end
		return Float64.(ref_results["x₀"][:, 1] .> 0.5)
	end

	function load_following_commitment(units::unit, target_capacity::Float64)
		NG = length(units.index)
		x = zeros(Float64, NG)
		order = sortperm(units.p_max; rev = true)
		online_capacity = 0.0
		for i ∈ order
			x[i] = 1.0
			online_capacity += units.p_max[i]
			if online_capacity >= target_capacity
				break
			end
		end
		return x
	end

	"""
		sample_and_train_loss_models(
			loads::load, winds::wind, units::unit, lines::transmissionline,
			DataCentras::data_centra, config_param::config, stroges::Any, scenarios_prob::Float64,
			hydros::hydro, exec_NT::Int64, min_overlap::Int64, max_overlap::Int64,
			NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64
		)

	Calibrate/fit accuracy loss mapping models on-the-fly by sampling different load levels,
	online unit configurations, and overlap sizes, solving subproblems and calculating relative cost error.
	"""
	function sample_and_train_loss_models(loads::load, winds::wind, units::unit, lines::transmissionline, DataCentras::data_centra, config_param::config, stroges::Any, scenarios_prob::Float64,
			hydros::hydro, exec_NT::Int64, min_overlap::Int64, max_overlap::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NL::Int64, NH::Int64)
		println("\n" * "="^80)
		println("SAMPLING AND CALIBRATING ACCURACY LOSS MAPPING MODEL...")
		println("="^80)

		# Use Task Local Storage to silence solvers during sampling
		task_local_storage(:is_sampling_running, true)

		# Grid search parameters.
		#
		# T_steady is meant to capture the decaying accuracy influence of the
		# inherited commitment boundary. Therefore the calibration set must not
		# be limited to hour 1 and a single starting commitment. We sample
		# representative start times across the simulation horizon and several
		# boundary commitment states for each start time.
		load_scales = [0.95, 1.05]
		total_time_avail = size(loads.load_curve, 2)
		latest_start = max(1, total_time_avail - exec_NT - max_overlap + 1)
		middle_start = max(1, min(latest_start, div(latest_start + 1, 2)))
		start_time_candidates = unique(clamp.(
			[1, middle_start, latest_start],
			1,
			latest_start
		))
		overlap_sizes = [min_overlap, Int64(round((min_overlap + max_overlap)/2)), max_overlap]

		X_list = Vector{Float64}[]
		Y_list = Float64[]

		peak_load = maximum(sum(loads.load_curve; dims = 1))
		if peak_load <= 0.0
			;
			peak_load = 1.0;
		end
		total_capacity = sum(units.p_max)
		if total_capacity <= 0.0
			;
			total_capacity = 1.0;
		end

		sample_count = 0
		try
			for start_time ∈ start_time_candidates
				base_end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)
				base_load_slice = sum(loads.load_curve[:, start_time:base_end_horizon]; dims = 1)[1, :]
				total_wind_cap = sum(winds.p_max)
				base_net_load = zeros(length(base_load_slice))
				for t ∈ eachindex(base_load_slice)
					avg_wind_factor = mean(winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)])
					base_net_load[t] = base_load_slice[t] - total_wind_cap * avg_wind_factor
				end

				for l_scale ∈ load_scales
					target_capacity = max(mean(base_net_load) * l_scale * 1.15, 0.0)
					ref_x_curr = load_following_commitment(units, target_capacity)
					try
						ref_units = deepcopy(units)
						ref_loads = deepcopy(loads)
						ref_loads.load_curve = loads.load_curve[:, start_time:base_end_horizon] .* l_scale
						ref_winds = deepcopy(winds)
						ref_winds.scenarios_curve = winds.scenarios_curve[:, start_time:base_end_horizon]
						ref_results = each_period_scucmodel_modules(
							exec_NT + max_overlap, NB, NG, ND, NC, ND2, ref_units, ref_loads,
							ref_winds, lines, DataCentras, config_param, stroges,
							scenarios_prob, NL, 1, hydros, NH
						)
						if ref_results !== nothing && haskey(ref_results, "x₀")
							ref_x_curr = Float64.(ref_results["x₀"][:, 1] .> 0.5)
						end
					catch e
						# Keep the deterministic load-following reference if the
						# local no-boundary reference solve is unavailable.
					end
					x_perturbations = [
						Float64.(units.x_0),
						ref_x_curr
					]

					for x_init ∈ x_perturbations
						mini_units = deepcopy(units)
						mini_units.x_0 = x_init

						end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)

						mini_loads = deepcopy(loads)
						mini_loads.load_curve = loads.load_curve[:, start_time:end_horizon] .* l_scale

						mini_winds = deepcopy(winds)
						mini_winds.scenarios_curve = winds.scenarios_curve[:, start_time:end_horizon]

						# Ground truth (max overlap)
						total_NT_true = exec_NT + max_overlap

						# Input metrics calculation
						total_load_lookahead = sum(mini_loads.load_curve; dims = 1)[1, :]
						total_wind_cap = sum(winds.p_max)
						net_load_lookahead = zeros(length(total_load_lookahead))
						for t ∈ eachindex(total_load_lookahead)
							avg_wind_factor = mean(winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)])
							net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
						end
						avg_net_load = mean(net_load_lookahead)
						L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)

						online_capacity = sum(units.p_max[i] * x_init[i] for i ∈ 1:NG)
						U_norm = clamp(online_capacity / total_capacity, 0.0, 1.0)
						X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_init, ref_x_curr)

					#%% Solve ground truth
					res_true = nothing
					try
						res_true = each_period_scucmodel_modules(total_NT_true, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, 1, hydros, NH)
					catch e
						continue
					end

					if res_true === nothing
						;
						continue;
					end

					committed_res_true = truncate_and_commit_results(res_true, exec_NT)
					committed_cost_true = compute_committed_cost(committed_res_true, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, 1, hydros, scenarios_prob)
					C_true = sum(committed_cost_true)
					if C_true <= 1.0
						;
						continue;
					end

					sample_count += 1

					#%% Evaluate each candidate overlap size

					for H ∈ overlap_sizes
						total_NT_H = exec_NT + H
						res_H = nothing
						try
							res_H = each_period_scucmodel_modules(total_NT_H, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, 1, hydros, NH)
						catch e
							continue
						end

						if res_H === nothing
							;
							continue;
						end

						committed_res_H = truncate_and_commit_results(res_H, exec_NT)
						committed_cost_H = compute_committed_cost(committed_res_H, exec_NT, mini_units, mini_loads, mini_winds, lines, DataCentras, config_param, 1, hydros, scenarios_prob)
						C_H = sum(committed_cost_H)

						# Accuracy loss combines cost deviation and commitment
						# state deviation. Cost-only labels often make small
						# overlaps look acceptable even when they leave a
						# different terminal commitment for the next interval.
						cost_loss = abs(C_H - C_true) / C_true
						state_loss, switch_loss = commitment_boundary_deviation(
							units, committed_res_H["x₀"][:, exec_NT],
							committed_res_true["x₀"][:, exec_NT]
						)
						loss_val = cost_loss + 0.50 * state_loss + 0.25 * switch_loss

						# Record sample
						push!(X_list, [L_norm, U_norm, X_delta_norm, X_switch_ratio, Float64(H)])
						push!(Y_list, loss_val)
					end
				end
				end
			end
		finally
			task_local_storage(:is_sampling_running, false)
		end

		println("Sampling completed. Total valid scenarios solved: $sample_count. Samples collected: $(length(Y_list))")

		models = TrainedLossModels("regression")

		if length(Y_list) < 4
			println("Warning: Too few successful samples collected. Using default preset coefficients.")
			return models
		end

		# 1. Fit Regression Model:
		# ln(Loss) = b0 + b1*L + b2*U + b3*X_delta + b4*X_switch + b5*H
		try
			X_reg = zeros(length(Y_list), 6)
			Y_reg = zeros(length(Y_list))
			for k ∈ eachindex(Y_list)
				X_reg[k, :] = [1.0, X_list[k][1], X_list[k][2], X_list[k][3], X_list[k][4], X_list[k][5]]
				Y_reg[k] = log(max(Y_list[k], 1e-6))
			end
			# Ridge regularized least squares
			X_reg_sq = X_reg' * X_reg + 1e-4 * I
			beta = X_reg_sq \ (X_reg' * Y_reg)
			if beta[6] >= 0.0
				beta[6] = -0.3 # Ensure physical decay constraint
			end
			models.beta = beta
			println("  ✓ Regression model calibrated: ln(Loss) = $(round(beta[1], digits=2)) + $(round(beta[2], digits=2))*L_norm + $(round(beta[3], digits=2))*U_norm + $(round(beta[4], digits=2))*X_delta_norm + $(round(beta[5], digits=2))*X_switch_ratio + $(round(beta[6], digits=2))*H")
		catch e
			println("  ⚠ Regression model calibration failed. Using defaults. Error: $e")
		end

		# 2. Fit Neural Network Model
		try
			X_nn = zeros(length(Y_list), 5)
			Y_nn = zeros(length(Y_list))
			for k ∈ 1:length(Y_list)
				X_nn[k, :] = [X_list[k][1], X_list[k][2], X_list[k][3], X_list[k][4], X_list[k][5] / 12.0]
				Y_nn[k] = Y_list[k]
			end
			W1, b1, W2, b2 = train_neural_network_backprop(X_nn, Y_nn)
			models.W1 = W1
			models.b1 = b1
			models.W2 = W2
			models.b2 = b2
			println("  ✓ Neural Network model calibrated successfully.")
		catch e
			println("  ⚠ Neural network calibration failed. Using defaults.")
		end

		return models
	end

	"""
		compute_steady_state_overlap_mapping(
			loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64,
			epsilon::Float64, min_overlap::Int64, max_overlap::Int64, x_0_curr::Vector{Float64},
			mode::String, trained_models
		)

	Quantitatively determine steady-state overlap window size steady_state_overlap_h based on
	the predicted solving accuracy loss under specific load level and startup/shutdown plans.
	"""
	function compute_steady_state_overlap_mapping(
			loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64, epsilon::Float64, min_overlap::Int64, max_overlap::Int64, x_0_curr::Vector{Float64}, mode::String = "regression", trained_models = nothing, x_ref_curr::Union{Nothing, Vector{Float64}} = nothing)
		# Estimate system characteristics
		total_time_avail = size(loads.load_curve, 2)
		end_horizon = min(total_time_avail, start_time + exec_NT + max_overlap - 1)

		# Peak load for normalization
		peak_load = maximum(sum(loads.load_curve; dims = 1))
		if peak_load <= 0.0
			peak_load = 1.0
		end

		# Total generation capacity for normalization
		total_capacity = sum(units.p_max)
		if total_capacity <= 0.0
			total_capacity = 1.0
		end

		# Average net load in the lookahead horizon
		total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
		total_wind_cap = sum(winds.p_max)
		net_load_lookahead = zeros(length(total_load_lookahead))
		for t ∈ eachindex(total_load_lookahead)
			scen_curves = winds.scenarios_curve[:, min(total_time_avail, start_time + t - 1)]
			avg_wind_factor = mean(scen_curves)
			net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
		end
		avg_net_load = mean(net_load_lookahead)
		L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)

		# Online generator capacity at start of interval
		NG = length(units.index)
		online_capacity = sum(units.p_max[i] * x_0_curr[i] for i ∈ 1:NG)
		U_norm = clamp(online_capacity / total_capacity, 0.0, 1.0)
		X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_0_curr, x_ref_curr)
		epsilon_state = clamp(epsilon / 2.0, 0.01, 0.08)
		state_decay_floor = commitment_deviation_decay_overlap(
			X_delta_norm, X_switch_ratio, epsilon_state, min_overlap, max_overlap
		)

		models = (trained_models !== nothing) ? trained_models : TrainedLossModels(mode)

		# Find the smallest overlap window H such that predicted accuracy loss <= epsilon
		model_selected_H = max_overlap
		for H ∈ min_overlap:max_overlap
			loss = 0.0
			if mode == "regression"
				beta = models.beta
				if length(beta) >= 6
					loss = exp(beta[1] + beta[2] * L_norm + beta[3] * U_norm + beta[4] * X_delta_norm + beta[5] * X_switch_ratio + beta[6] * H)
				else
					loss = exp(beta[1] + beta[2] * L_norm + beta[3] * U_norm + beta[4] * H)
				end
			elseif mode == "neural_network"
				loss = predict_accuracy_loss_neural_network_custom(L_norm, U_norm, X_delta_norm, X_switch_ratio, H, models)
			else
				return calculate_boundary_sensitivity_decay(0.25, epsilon)
			end

			if loss <= epsilon
				model_selected_H = H
				break
			end
		end

		return max(model_selected_H, state_decay_floor)
	end

	"""
		compute_adaptive_overlap_window(
			loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64,
			alpha::Float64, epsilon::Float64, min_overlap::Int64, max_overlap::Int64,
			pre_scheduling_results, interval_scheduling_id, steady_state_mode, trained_models
		)

	Compute composite adaptive overlapping window size considering:

	 1. Steady-state boundary sensitivity decay / Dynamic Accuracy Loss Mapping
	 2. Slow-start generator dwell requirements (dynamic remaining dwell time tracking)
	 3. Strong Net Load ramping & multi-scenario uncertainty coverage
	"""
	function compute_adaptive_overlap_window(loads::load, winds::wind, units::unit, start_time::Int64, exec_NT::Int64, alpha::Float64 = 0.25, epsilon::Float64 = 0.05, min_overlap::Int64 = 2,
			max_overlap::Int64 = 12, pre_scheduling_results = nothing, interval_scheduling_id = 1, steady_state_mode::String = "decay", trained_models = nothing, x_ref_curr::Union{Nothing, Vector{Float64}} = nothing)
		NG = length(units.index)

		# Extract dynamic remaining dwell times of units at start of current interval
		t_0_curr = deepcopy(units.t_0)
		t_1_curr = deepcopy(units.t_1)
		x_0_curr = deepcopy(units.x_0)

		if interval_scheduling_id != 1 && pre_scheduling_results !== nothing
			# Get remaining up/down times from pre_scheduling_results committed window
			u_sub = pre_scheduling_results["u₀"][:, 1:exec_NT]
			v_sub = pre_scheduling_results["v₀"][:, 1:exec_NT]
			res_up, res_down = get_generators_upoff_durations(units, u_sub, v_sub, NG)
			t_0_curr = res_up[:, 1]
			t_1_curr = res_down[:, 1]
			x_0_curr = pre_scheduling_results["x₀"][:, exec_NT]
		end

		if startswith(steady_state_mode, "fixed_")
			fixed_val = parse(Int, split(steady_state_mode, "_")[2])
			T_overlap = fixed_val
			# Clamping at boundary for last interval
			if interval_scheduling_id == 7
				total_time_avail = size(loads.load_curve, 2)
				remaining_time = total_time_avail - (start_time + exec_NT - 1)
				T_overlap = min(T_overlap, remaining_time)
				T_overlap = max(0, T_overlap)
			end
			return T_overlap, false, fixed_val, 0, 0
		end

		if steady_state_mode == "ml_prediction"
			# Extract system-independent features
			total_capacity = sum(units.p_max)
			U_norm = total_capacity > 0.0 ? sum(x_0_curr .* units.p_max) / total_capacity : 0.0
			online_remaining = [x_0_curr[i] > 0.5 ? max(0.0, t_0_curr[i]) : 0.0 for i ∈ 1:NG]
			offline_remaining = [x_0_curr[i] <= 0.5 ? max(0.0, t_1_curr[i]) : 0.0 for i ∈ 1:NG]
			T_dwell_rem = max(0.0, maximum(online_remaining), maximum(offline_remaining))
			X_delta_norm, X_switch_ratio = commitment_boundary_deviation(units, x_0_curr, x_ref_curr)

			end_horizon = min(size(loads.load_curve, 2), start_time + exec_NT + max_overlap - 1)
			total_load_lookahead = sum(loads.load_curve[:, start_time:end_horizon]; dims = 1)[1, :]
			total_wind_cap = sum(winds.p_max)

			net_load_lookahead = zeros(length(total_load_lookahead))
			for t ∈ eachindex(total_load_lookahead)
				scen_curves = winds.scenarios_curve[:, min(size(loads.load_curve, 2), start_time + t - 1)]
				avg_wind_factor = mean(scen_curves)
				net_load_lookahead[t] = total_load_lookahead[t] - total_wind_cap * avg_wind_factor
			end

			avg_net_load = mean(net_load_lookahead)
			peak_load = maximum(sum(loads.load_curve; dims = 1))
			if peak_load <= 0.0
				peak_load = 1.0
			end
			L_norm = clamp(avg_net_load / peak_load, 0.0, 1.0)
			sigma_load = std(total_load_lookahead)

			wind_ramps = [abs(winds.scenarios_curve[s, t + 1] - winds.scenarios_curve[s, t]) for s ∈ 1:winds.scenarios_nums, t ∈ start_time:(end_horizon - 1)]
			R_wind_max = isempty(wind_ramps) ? 0.0 : maximum(wind_ramps)

			feat_vec = [U_norm, T_dwell_rem, L_norm, sigma_load, R_wind_max, X_delta_norm, X_switch_ratio]

			T_o_pred = OverlapPredictor.predict_overlap(feat_vec; min_overlap = min_overlap, max_overlap = max_overlap)

			T_overlap = T_o_pred
			# Clamping at boundary for last interval
			if interval_scheduling_id == 7
				total_time_avail = size(loads.load_curve, 2)
				remaining_time = total_time_avail - (start_time + exec_NT - 1)
				T_overlap = min(T_overlap, remaining_time)
				T_overlap = max(0, T_overlap)
			end

			return T_overlap, false, T_o_pred, 0, 0
		end

		# 1. Steady-state overlap window.
		#
		# For "regression" and "neural_network" modes, T_steady is calculated by
		# compute_steady_state_overlap_mapping(...). That function predicts the
		# accuracy loss associated with candidate overlap lengths H and selects
		# the smallest H whose predicted loss is <= epsilon.
		#
		# This branch is intentionally separate from "ml_prediction": the CART
		# predictor branch above directly returns an overlap value and therefore
		# does not exercise the T_steady/T_unit/T_ramp aggregation used here.
		T_steady = 0
		if steady_state_mode == "decay"
			T_steady = calculate_boundary_sensitivity_decay(alpha, epsilon)
		else
			T_steady = compute_steady_state_overlap_mapping(loads, winds, units, start_time, exec_NT, epsilon, min_overlap, max_overlap, x_0_curr, steady_state_mode, trained_models, x_ref_curr)
		end

		# 2. Dynamic thermal-unit dwell requirement.
		#
		# T_unit must describe the *remaining* boundary restriction at the start
		# of the current subproblem, not the static maximum minimum-up/down time
		# of all slow units. For currently online thermal units, t_0_curr is the
		# remaining minimum online time before they may be shut down. For currently
		# offline thermal units, t_1_curr is the remaining minimum offline time
		# before they may be started up. These values are already measured at the
		# current interval boundary, so do not subtract exec_NT again here.
		online_remaining = [x_0_curr[i] > 0.5 ? max(0.0, t_0_curr[i]) : 0.0 for i ∈ 1:NG]
		offline_remaining = [x_0_curr[i] <= 0.5 ? max(0.0, t_1_curr[i]) : 0.0 for i ∈ 1:NG]
		T_dwell_rem = max(0.0, maximum(online_remaining), maximum(offline_remaining))
		T_unit = Int64(ceil(T_dwell_rem))

		#STUB:  3. Net-load ramping and uncertainty event detection
		is_ramp, T_ramp = detect_ramp_events_and_overlap(loads, winds, start_time, exec_NT, max_overlap)

		# Composite overlap calculation
		T_overlap_raw = max(T_steady, T_unit, T_ramp)
		T_overlap = clamp(T_overlap_raw, min_overlap, max_overlap)

		# Ensure total window does not exceed remaining simulation time
		total_time_avail = size(loads.load_curve, 2)
		max_possible_overlap = total_time_avail - (start_time + exec_NT - 1)
		T_overlap = max(0, min(T_overlap, max_possible_overlap))

		return T_overlap, is_ramp, T_steady, T_unit, T_ramp
	end

	"""
		update_adaptive_boundary_conditions(
			interval_scheduling_id::Int64,
			NG::Int64,
			exec_NT::Int64,
			total_NT::Int64,
			start_time::Int64,
			units::unit,
			loads::load,
			winds::wind,
			results::Union{Dict{String, Array{Float64}}, Nothing}
		)

	Update initial boundary conditions and slice time-series inputs for an adaptive window simulation.
	Boundary conditions (x_0, p_0, t_0, t_1) are extracted from time step `exec_NT` of previous results.
	"""
	function update_adaptive_boundary_conditions(interval_scheduling_id::Int64, NG::Int64, exec_NT::Int64, total_NT::Int64, start_time::Int64, units::unit, loads::load, winds::wind, results::Union{Dict{String, Array{Float64}}, Nothing})
		mini_units = deepcopy(units)

		if interval_scheduling_id != 1 && results !== nothing
			# Extract initial state from end of committed execution window (exec_NT) of prior interval
			mini_units.x_0 = results["x₀"][:, exec_NT]
			mini_units.p_0 = results["p₀"][:, exec_NT]

			# Calculate remaining dwell times up to step exec_NT
			u_sub = results["u₀"][:, 1:exec_NT]
			v_sub = results["v₀"][:, 1:exec_NT]
			res_up, res_down = get_generators_upoff_durations(units, u_sub, v_sub, NG)
			mini_units.t_0 = res_up[:, 1]
			mini_units.t_1 = res_down[:, 1]
		end

		to_time = start_time + total_NT - 1

		mini_loads = deepcopy(loads)
		mini_loads.load_curve = loads.load_curve[:, start_time:to_time]

		mini_winds = deepcopy(winds)
		mini_winds.scenarios_curve = winds.scenarios_curve[:, start_time:to_time]

		return mini_units, mini_loads, mini_winds
	end

	"""
		truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)

	Extract and return only the committed execution period (1:exec_NT) from total window results.
	"""
	function truncate_and_commit_results(results::Dict{String, Array{Float64}}, exec_NT::Int64)
		committed_results = Dict{String, Array{Float64}}()
		for (k, v) ∈ results
			if ndims(v) == 2 && size(v, 2) >= exec_NT
				committed_results[k] = v[:, 1:exec_NT]
			elseif ndims(v) == 3 && size(v, 2) >= exec_NT
				committed_results[k] = v[:, 1:exec_NT, :]
			elseif ndims(v) == 1
				committed_results[k] = v
			else
				committed_results[k] = v
			end
		end
		return committed_results
	end

	"""
		compute_committed_cost(
			committed_results::Dict{String, Array{Float64}},
			exec_NT::Int64,
			units::unit,
			loads::load,
			winds::wind,
			lines::transmissionline,
			DataCentras::data_centra,
			config_param::config,
			interval_scheduling_id::Int64,
			hydros::hydro,
			scenarios_prob::Float64
		)

	Compute 1x7 scheduling cost vector for the committed execution period (1:exec_NT).
	"""
	function compute_committed_cost(
			committed_results::Dict{String, Array{Float64}}, exec_NT::Int64, units::unit, loads::load, winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config, interval_scheduling_id::Int64, hydros::hydro, scenarios_prob::Float64)
		NS = winds.scenarios_nums
		NW = length(winds.index)
		NG = length(units.index)
		NB = length(units.locatebus)
		ND = length(loads.locatebus)
		NC = 0
		ND2 = length(DataCentras.locatebus)
		NH = length(hydros.locatebus)

		refcost, eachslope = linearizationfuelcurve(units, NG)

		committed_winds = deepcopy(winds)
		committed_winds.scenarios_curve = winds.scenarios_curve[:, 1:exec_NT]

		su_cost = committed_results["su_cost"]
		sd_cost = committed_results["sd_cost"]
		pgₖ = committed_results["pₖ"]
		pg₀ = committed_results["p₀"]
		x₀ = committed_results["x₀"]
		seq_sr⁺ = committed_results["seq_sr⁺"]
		seq_sr⁻ = committed_results["seq_sr⁻"]
		pᵨ = committed_results["pᵨ"]
		pᵩ = committed_results["pᵩ"]

		# Set global scenarios_prob if required by exported_scheduling_cost
		global scenarios_prob = scenarios_prob

		str = exported_scheduling_cost(NS, exec_NT, NB, NG, ND, NC, ND2, NH, units, loads, committed_winds, lines, DataCentras, config_param, interval_scheduling_id, su_cost, sd_cost, pgₖ, pg₀, x₀, seq_sr⁺, seq_sr⁻, pᵨ, pᵩ, eachslope, refcost)
		return str
	end
end # end guard _ADAPTIVE_PERIOD_SCUC_MODULES_INCLUDED
