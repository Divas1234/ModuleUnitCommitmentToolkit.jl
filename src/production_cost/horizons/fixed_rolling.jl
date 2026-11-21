"""
    src/pcm/horizons/fixed_horizon.jl

Pure-function fixed-horizon (non-overlapping) rolling PCM driver.
Replaces the legacy global-variable `rolling_pcm_driver.jl` with explicit
parameter passing, supporting both `SingleUnitFormulation` and
`ClusteredFormulation` as well as full-horizon `Benchmark` (`intervals == 1`).
"""

using Random

function _slice_pcm_window_loads(loads, t_start::Int, t_end::Int)
    total_cols = size(loads.load_curve, 2)
    idx = [mod1(t, total_cols) for t in t_start:t_end]
    return load(loads.index, loads.locatebus, loads.load_curve[:, idx])
end

function _slice_pcm_window_winds(winds, t_start::Int, t_end::Int)
    total_cols = size(winds.scenarios_curve, 2)
    idx = [mod1(t, total_cols) for t in t_start:t_end]
    return WindUnits(
        winds.index,
        winds.locatebus,
        winds.p_max,
        winds.scenarios_prob,
        winds.scenarios_nums,
        winds.scenarios_curve[:, idx],
        winds.Fcmode,
        winds.Kw,
        winds.Rw,
        winds.Mw,
        winds.Dw,
        winds.Tw,
    )
end

function _update_units_initial_state(units, x_end::AbstractVector, p_end::AbstractVector, prev_t0::AbstractVector, window_hours::Int)
    NG = length(units.index)
    new_t0 = similar(Float64.(prev_t0))
    for i in 1:NG
        on_now = x_end[i] >= 0.5
        was_on = units.x_0[i] >= 0.5
        new_t0[i] = (on_now == was_on) ? (Float64(prev_t0[i]) + window_hours) : Float64(window_hours)
    end
    vals = Any[getfield(units, f) for f in fieldnames(typeof(units))]
    for (k, f) in enumerate(fieldnames(typeof(units)))
        if f === :x_0
            vals[k] = Float64.(x_end)
        elseif f === :t_0
            vals[k] = new_t0
        elseif f === :p_0
            vals[k] = Float64.(p_end)
        end
    end
    return ThermalUnits(vals[1:26]...; t_1 = units.t_1)
end

"""
    execute_fixed_horizon_pcm(formulation::AbstractPCMFormulation, policy::FixedHorizonPolicy; cfg::PCMConfig = PCMConfig(), label::String = "")

Execute non-overlapping fixed-horizon PCM (or full-horizon Benchmark when `policy.intervals == 1`)
without mutating any global script state.
"""
function execute_fixed_horizon_pcm(
    formulation::AbstractPCMFormulation,
    policy::FixedHorizonPolicy;
    cfg::PCMConfig = PCMConfig(),
    label::String = "",
)
    Random.seed!(cfg.random_seed)
    t_start_wall = time()

    perf = cfg.performance_mode
    perf in ("fast", "balanced") || throw(ArgumentError("PCM_PERFORMANCE_MODE must be fast or balanced; got '$perf'"))

    env_pairs = Pair{String, String}[]
    if formulation isa ClusteredFormulation
        haskey(ENV, "PCM_CLUSTER_OUTPUT_BINS") || push!(env_pairs, "PCM_CLUSTER_OUTPUT_BINS" => (perf == "fast" ? "5" : "9"))
        haskey(ENV, "PCM_MIP_GAP") || push!(env_pairs, "PCM_MIP_GAP" => (perf == "fast" ? "0.03" : "0.015"))
    else
        haskey(ENV, "PCM_MIP_GAP") || push!(env_pairs, "PCM_MIP_GAP" => (perf == "fast" ? "0.03" : "0.015"))
    end

    formulation_sym = formulation isa ClusteredFormulation ? :clustered : :standard
    method_label = isempty(label) ? (policy.intervals == 1 ? "benchmark" : String(formulation_sym)) : label

    return withenv(env_pairs...) do
        d = load_pcm_excel_data(; data_file = cfg.data_file, network_constraints = cfg.network_constraints)
        apply_pcm_load_profile!(d.loads, cfg.load_profile)
        winds, NW = genscenario(d.WindsFreqParam, 0)
        scenarios_prob = 1.0 / max(1, winds.scenarios_nums)

        mini_NT = policy.window_hours
        n_intervals = policy.intervals
        total_hours = mini_NT * n_intervals
        NG = d.NG

        current_units = d.units
        total_cost = 0.0
        interval_costs = Float64[]
        interval_times = Float64[]
        full_x = zeros(Float64, NG, total_hours)
        full_p = zeros(Float64, NG, total_hours)

        for k in 1:n_intervals
            h_start = (k - 1) * mini_NT + 1
            h_end = k * mini_NT
            win_loads = _slice_pcm_window_loads(d.loads, h_start, h_end)
            win_winds = _slice_pcm_window_winds(winds, h_start, h_end)

            t_win = time()
            results = each_period_scucmodel_modules(
                mini_NT,
                d.NB,
                NG,
                d.ND,
                d.NC,
                d.ND2,
                current_units,
                win_loads,
                win_winds,
                d.lines,
                d.DataCentras,
                d.config_param,
                d.stroges,
                scenarios_prob,
                d.NL,
                d.NH,
                d.hydros,
                k;
                formulation = formulation_sym,
            )
            dt_win = time() - t_win
            push!(interval_times, dt_win)

            win_cost = if haskey(results, "total_cost")
                Float64(results["total_cost"])
            elseif haskey(results, "objective_value")
                Float64(results["objective_value"])
            else
                0.0
            end
            push!(interval_costs, win_cost)
            total_cost += win_cost

            if haskey(results, "x₀") && haskey(results, "p₀")
                x_mat = results["x₀"]
                p_mat = results["p₀"]
                full_x[:, h_start:h_end] .= x_mat[1:NG, 1:mini_NT]
                full_p[:, h_start:h_end] .= p_mat[1:NG, 1:mini_NT]
                current_units = _update_units_initial_state(
                    current_units,
                    x_mat[1:NG, mini_NT],
                    p_mat[1:NG, mini_NT],
                    current_units.t_0,
                    mini_NT,
                )
            end
        end

        elapsed = time() - t_start_wall
        return (
            method = method_label,
            formulation = formulation_sym,
            overlap = false,
            status = "OPTIMAL",
            total_cost = total_cost,
            runtime_seconds = elapsed,
            intervals = n_intervals,
            window_hours = mini_NT,
            total_hours = total_hours,
            interval_costs = interval_costs,
            interval_times = interval_times,
            commitment = full_x,
            dispatch = full_p,
        )
    end
end
