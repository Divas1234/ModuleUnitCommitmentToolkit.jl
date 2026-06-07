function f_t(x_pre, k)
	# δp₀ = 5
	# δt = 0.05
	# tem = x_pre + (2 * k + 1) * (δt * δt) - 2 * δt
	# ---------------------------------------------------------------------------- #
	#                                   version 2                                  #
	# ---------------------------------------------------------------------------- #
	# H, Δp, R, D, Δt = 4, 0.5, 2, 0.5, 0.05
	# α = 1 / (2 * H) * Δt
	# tem = α * Δp + (1 - α * (1 / R + D)) * x_pre
	# return tem
	# ---------------------------------------------------------------------------- #
	#                                   version 3                                  #
	# ---------------------------------------------------------------------------- #
	δt   = 0.05
	θ    = 2
	str₁ = exp(-1.0 * θ * δt)
	str₂ = exp(-1.0 * θ * ((k - 1) * δt - 8) * (im + 1)) * sin(θ * δt)
	tem  = (exp(im * θ * δt) * x_pre + str₂) * str₁
	return real(tem)
	# ---------------------------------------------------------------------------- #
	#                                   version 4                                  #
	# ---------------------------------------------------------------------------- #
	# δp, H, D, R, T, δt = 0.5, 2, 0.5, 2, 0.01, 0.05
	# new_δp = δp - 1 / (R * T) * exp(-1.0 / T * (k - 1) * δt) * x_pre
	# str₂ = (new_δp - D * x_pre) * δt / (2 * H)
	# tem = str₂ + x_pre
	# return 1.0 * tem
	# return (1/2)*x_pre + (25*x_pre)/(1+x_pre^2) + 8*cos(1.2*(k-1))
end

#process equation
function x_t(f_t, x_pre, k, Q = 1)
	return f_t.(x_pre, k) .+ rand(Normal(0, Q), length(x_pre)) .* 0.0005
end

function h_t(x_cur)
	tem = 2 * x_cur
	# return (1/20)*x_cur^2
	return tem
end

#observation equation
function y_t(h_t, x_cur, R = 1)
	return h_t.(x_cur) .+ rand(Normal(0, R), length(x_cur)) .* 0.0005
end

#initial pdf
function x_0(m, sd = 1)
	# return zeros(m, 1)
	# tem = rand(Normal(0, sd), m)
	# tem1 = zeros(size(tem,1), size(tem,2))
	# return tem1

	# version 2
	# return rand(Normal(0, sd), m) * 0 .+ 2
	# version 3
	return rand(Normal(0, sd), m) * 0.0005 .+ 0
	# return 2
end

function generate_data(x_0, x_t, y_t, tt)
	xt = fill(0.0, tt)                    # initialize state vector
	yt = fill(0.0, tt)                    # initialize measurement vector
	x0 = x_0(1)                           # sample one time from initial state pdf
	x_pre = x0
	for i in 1:tt                         # at each time step, generate the state and
		x_cur = x_t(f_t, x_pre, i, 1)     # measurement using the system equations x_t and y_t
		xt[i] = x_cur[1]
		yt[i] = y_t(h_t, x_cur)[1]
		x_pre = x_cur
	end
	return [xt, yt]
end

function particle_filter(data, x_0, x_t, conditional_likelihoods, N, tt)
	# x_post = Array{Array{Float64},tt}    # initialize x_post
	x_post = zeros(N, tt)
	x = data[1]                           # states
	y = data[2]                           # observations
	x_pre = x_0(N)                        # Initialization: sample N particlesfrom initial state pdf
	for k in 1:tt
		x_k_pre = x_t(f_t, x_pre, k - 1, 1)   # Prediction: sample from p(x_k|x_k-1)
		likelihood = conditional_likelihoods(h_t, y[k], x_k_pre)  # Update: compute weights p(y_k|x_k)
		if likelihood == fill(0.0, N)
			x_k_post = x_k_pre
		else
			total = sum(likelihood)       # Normalization: normalize weights so that they sum to 1
			likelihood = likelihood ./ total
			x_k_post = wsample(x_k_pre, likelihood, length(x_k_pre)) # Resampling: Draw N new particles
		end
		x_post[:, k] = x_k_post
		x_pre = x_k_post
	end
	tem = zeros(tt, 1)
	for i in 1:tt
		tem[i, 1] = sum(x_post[:, i]) / N
	end
	# return x_post, tem
	return tem
end

function conditional_likelihoods(h_t, y, x, R = 1)
	h = h_t.(x)
	likelihoods = pdf.(Normal(0, R), y .- h)
	return likelihoods
end
