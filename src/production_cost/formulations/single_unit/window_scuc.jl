if !isdefined(@__MODULE__, :_PERIOD_SCUC_MODULES_INCLUDED)
    const _PERIOD_SCUC_MODULES_INCLUDED = true

    using JuMP, DelimitedFiles

    #---------------------------------------------------------------------------------------------------
    # Module Dependencies and Includes
    #---------------------------------------------------------------------------------------------------

    if !isdefined(@__MODULE__, :hydro)
        const hydro = Any
    end
    isdefined(@__MODULE__, :set_objective!) || include("../../../unit_commitment/objectives/entry.jl")
    isdefined(@__MODULE__, :calculate_gsdf) || include("../../../unit_commitment/utilities/entry.jl")
    if !isdefined(@__MODULE__, :pcm_optimizer)
        pcm_optimizer() = _resolve_pcm_optimizer(nothing)
    end
    if !isdefined(@__MODULE__, :pcm_solver_name)
        pcm_solver_name() = occursin("gurobi", lowercase(string(pcm_optimizer()))) ? "gurobi" : "glpk"
    end
    const PCM_CLUSTER_ATTEMPTS = Threads.Atomic{Int}(0)
    const PCM_CLUSTER_SUCCESSES = Threads.Atomic{Int}(0)
    const PCM_CLUSTER_FALLBACKS = Threads.Atomic{Int}(0)
    const PCM_CLUSTER_PREPROCESS_TIME_SEC = Threads.Atomic{Float64}(0.0)
    # 最近一次聚类主问题的真实整数变量数。与仅按 U/Y/Z 估算的
    # commitment 变量数分开记录，因为扩展凸包还包含状态流和出力弧变量。
    const PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES = Threads.Atomic{Int}(0)

    function reset_pcm_cluster_stats!()
        Threads.atomic_xchg!(PCM_CLUSTER_ATTEMPTS, 0)
        Threads.atomic_xchg!(PCM_CLUSTER_SUCCESSES, 0)
        Threads.atomic_xchg!(PCM_CLUSTER_FALLBACKS, 0)
        Threads.atomic_xchg!(PCM_CLUSTER_PREPROCESS_TIME_SEC, 0.0)
        Threads.atomic_xchg!(PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES, 0)
        return snapshot_pcm_cluster_stats()
    end

    function snapshot_pcm_cluster_stats()
        if isdefined(@__MODULE__, :PCMRunStats)
            return PCMRunStats(
                PCM_CLUSTER_ATTEMPTS[],
                PCM_CLUSTER_SUCCESSES[],
                PCM_CLUSTER_FALLBACKS[],
                PCM_CLUSTER_PREPROCESS_TIME_SEC[],
                PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES[],
            )
        end
        return (
            attempts = PCM_CLUSTER_ATTEMPTS[],
            successes = PCM_CLUSTER_SUCCESSES[],
            fallbacks = PCM_CLUSTER_FALLBACKS[],
            preprocess_time_sec = PCM_CLUSTER_PREPROCESS_TIME_SEC[],
            extended_integer_variables = PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES[],
        )
    end
    #---------------------------------------------------------------------------------------------------

    """
    	SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, storages, scenarios_prob, NL)

    Stochastic Unit Commitment (SUC) model for power system optimization (Refactored & Modularized).

    #NOTE -  Arguments
    - `NT::Int64`: Number of time periods
    - `NB::Int64`: Number of buses
    - `NG::Int64`: Number of generators
    - `ND::Int64`: Number of demands/loads
    - `NC::Int64`: Number of energy storage units
    - `ND2::Int64`: Number of data centers
    - `units::unit`: Generator unit data
    - `loads::load`: Load data
    - `winds::wind`: Wind generation data
    - `lines::transmissionline`: Transmission line data
    - `data_centers::data_centra`: Data center data
    - `config_param::config`: Configuration parameters
    - `storages::Any`: Storage system data (Type Any for flexibility, consider defining a specific struct)
    - `scenarios_prob::Float64`: Probability of scenarios (Assumed equal for now if calculated as 1/NS)
    - `NL::Int64`: Number of transmission lines

    # Returns
    - Dictionary containing optimization results, or nothing if optimization fails.
    """
    # NOTE - update boundary conditions
    function update_boundary_conditions(
            interval_scheduling_id, NG::Int64, NT::Int64, units::unit, loads::load, winds::wind, results::AbstractDict{String})

        # FIXME -  update generators parameter_value
        mini_units = deepcopy(units)
        if interval_scheduling_id != 1
            res_up, res_down = get_generators_upoff_durations(units, results["u₀"], results["v₀"], NG)
            # mini_units = deepcopy(units)
            mini_units.x_0 = vec(results["x₀"][1:NG, NT])
            mini_units.p_0 = vec(results["p₀"][1:NG, NT])
            mini_units.t_0 = res_up[:, 1]
            mini_units.t_1 = res_down[:, 1]
        end
        # onoffinit = calculate_initial_unit_status(mini_units, NG)

        from_time = (interval_scheduling_id - 1) * NT + 1
        to_time = interval_scheduling_id * NT
        # FIXME - update loads parameter_value
        mini_loads = deepcopy(loads)
        mini_loads.load_curve = loads.load_curve[:, from_time:to_time]

        # FIXME - update wind parameter_value
        mini_winds = deepcopy(winds)
        mini_winds.scenarios_curve = winds.scenarios_curve[:, from_time:to_time]

        return mini_units, mini_loads, mini_winds
    end

    """Return consecutive on/off durations at the end of a committed window.

    `t_0` and `t_1` are elapsed-state durations, not remaining dwell times.  Keeping
    this meaning consistent is essential because the next UC window derives its
    mandatory initial residence period from `minimum_time - elapsed_duration`.
    """
    function get_generators_upoff_durations(units, shutup_states, shutdown_states, NG)
        res_up, res_down = zeros(Int64, NG, 1), zeros(Int64, NG, 1)
        NT_window = size(shutup_states, 2)
        for i ∈ 1:NG
            last_u = findlast(x -> x > 0.5, shutup_states[i, :])
            last_v = findlast(x -> x > 0.5, shutdown_states[i, :])

            if last_u === nothing && last_v === nothing
                # No startup/shutdown in this window: state didn't change
                if units.x_0[i] > 0.5
                    res_up[i, 1] = max(0, round(Int, units.t_0[i])) + NT_window
                    res_down[i, 1] = 0
                else
                    res_up[i, 1] = 0
                    res_down[i, 1] = max(0, round(Int, units.t_1[i])) + NT_window
                end
            elseif last_u !== nothing && (last_v === nothing || last_u > last_v)
                # Last event was a startup
                res_up[i, 1] = NT_window - last_u + 1
                res_down[i, 1] = 0
            else
                # Last event was a shutdown
                res_up[i, 1] = 0
                res_down[i, 1] = NT_window - last_v + 1
            end
        end
        return res_up, res_down
    end

    if isdefined(@__MODULE__, :UCProblemData)
        function each_period_scucmodel_modules(
                data::UCProblemData;
                scenarios_prob::Float64 = 1.0 / max(1, data.NS),
                interval_scheduling_id::Int64 = 1,
                hydros = nothing,
                NH::Union{Nothing, Int64} = nothing,
                formulation::Symbol = :environment)
            resolved_hydros = hydros === nothing ? (
                index = Int64[],
                locatebus = Int64[],
                p_min = Float64[],
                p_max = Float64[],
                inflow = zeros(Float64, 0, data.NT),
            ) : hydros
            resolved_NH = NH === nothing ? Int64(length(resolved_hydros.locatebus)) : NH
            return each_period_scucmodel_modules(
                data.NT, data.NB, data.NG, data.ND, data.NC, data.ND2,
                data.units, data.loads, data.winds, data.lines, data.data_centers,
                data.config_param, data.storages, scenarios_prob, data.NL,
                interval_scheduling_id, resolved_hydros, resolved_NH;
                formulation = formulation,
            )
        end
    end

    # NOTE - baseline UC function module
    function each_period_scucmodel_modules(NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, units::unit, loads::load,
            winds::wind, lines::transmissionline, data_centers::data_centra, config_param::config, storages::Any,
            scenarios_prob::Float64, NL::Int64, interval_scheduling_id::Int64, hydros::hydro, NH::Int64;
            formulation::Symbol = :environment,
            solver_options = isdefined(@__MODULE__, :current_solver_options) ? current_solver_options() : nothing)
        println("Step-3: Creating dispatching model (Refactored & Modularized)")

        # --- Input Validation ---
        if !validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, data_centers, config_param, storages, scenarios_prob, NL)
            error("Input validation failed. Check your data.")
        end

        # Two solution paths share the same data and rolling-window boundaries:
        # clustered master + physical disaggregation, or the original unit SCUC.
        # This switch therefore changes only the formulation used in the benchmark.
        formulation in (:environment, :standard, :clustered) ||
            throw(ArgumentError("Unsupported PCM formulation: $formulation"))
        clustered_enabled = formulation === :clustered ||
            (formulation === :environment && lowercase(get(ENV, "PCM_USE_CLUSTERED_UC", "false")) in ("1", "true", "yes", "on"))
        if clustered_enabled
            Threads.atomic_add!(PCM_CLUSTER_ATTEMPTS, 1)
            clustered_result=solve_true_clustered_pcm_window(NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros,
                NH; optimizer = pcm_optimizer(), solver_options = solver_options)
            if clustered_result.feasible
                Threads.atomic_add!(PCM_CLUSTER_SUCCESSES, 1)
                println("  ✓ True clustered UC completed ($(length(clustered_result.clusters)) virtual units)")
                return clustered_result.results
            end
            # Never export an unverified aggregate schedule. The physical
            # disaggregation is the feasibility certificate for clustered PCM.
            println("  ⚠ True clustered UC failed at $(clustered_result.stage): $(clustered_result.message); falling back to full unit-network SCUC")
            Threads.atomic_add!(PCM_CLUSTER_FALLBACKS, 1)
            clustered_enabled=false
        end

        # --- Initialization ---
        NS = winds.scenarios_nums
        NW = length(winds.index)
        Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

        # Linearize fuel cost curve (assuming function is in linearization.jl)
        refcost, eachslope = linearizationfuelcurve(units, NG)

        onoffinit = calculate_initial_unit_status(units, NG)

        # --- Model Creation ---
        Δp_contingency = define_contingency_size(units, NG)
        opt_factory = (solver_options !== nothing && solver_options.optimizer !== nothing) ? solver_options.optimizer : pcm_optimizer()
        scuc = Model(opt_factory)
        is_sampling_silent = get(task_local_storage(), :is_sampling_running, false)
        if isdefined(@__MODULE__, :apply_solver_options!) && solver_options !== nothing
            default_gap = parse(Float64, get(ENV, "PCM_MIP_GAP", "0.015"))
            default_threads = pcm_solver_name() == "gurobi" ? max(1, parse(Int, get(ENV, "PCM_SOLVER_THREADS", "24"))) : nothing
            default_limit = tryparse(Float64, get(ENV, "PCM_SOLVER_TIME_LIMIT_SECONDS", ""))
            apply_solver_options!(
                scuc,
                solver_options;
                default_mip_gap = default_gap,
                default_threads = default_threads,
                default_time_limit = default_limit,
                default_silent = is_sampling_silent,
            )
        else
            is_sampling_silent && set_silent(scuc)
            if pcm_solver_name() == "gurobi"
                set_optimizer_attribute(scuc, "MIPGap", parse(Float64, get(ENV, "PCM_MIP_GAP", "0.015")))
                solver_threads = max(1, parse(Int, get(ENV, "PCM_SOLVER_THREADS", "24")))
                set_optimizer_attribute(scuc, "Threads", solver_threads)
                # 大规模算例可通过环境变量统一限制单个滚动窗口的求解时间。
                # 默认不设上限，以保持既有小规模算例的对外行为不变。
                solver_limit = tryparse(Float64, get(ENV, "PCM_SOLVER_TIME_LIMIT_SECONDS", ""))
                solver_limit !== nothing && solver_limit > 0 &&
                    set_optimizer_attribute(scuc, "TimeLimit", solver_limit)
            else
                set_optimizer_attribute(scuc, "tm_lim", 4000)
                set_optimizer_attribute(scuc, "mip_gap", 0.015)
            end
        end
        # --- Define Variables ---
        define_decision_variables!(scuc, NT, NG, ND, NC, ND2, NS, NW, config_param)
        # --- Set Objective ---
        set_objective!(scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

        println("subject to.") # Indicate the start of constraint definitions

        # --- Add Constraints ---
        add_unit_operation_constraints!(scuc, NT, NG, units, onoffinit)
        add_curtailment_constraints!(scuc, NT, ND, NW, NS, loads, winds)
        add_generator_power_constraints!(scuc, NT, NG, NS, units)
        add_reserve_constraints!(scuc, NT, NG, NC, NS, units, loads, winds, config_param)
        add_power_balance_constraints!(scuc, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
        add_ramp_constraints!(scuc, NT, NG, NS, units, onoffinit)
        add_pwl_constraints!(scuc, NT, NG, NS, units)
        if clustered_enabled
            println("\t constraints: 10) transmission limits deferred to unit disaggregation")
        else
            add_transmission_constraints!(
                scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, storages, Gsdf, config_param, ND2, data_centers)
        end
        add_storage_constraints!(scuc, NT, NC, NS, config_param, storages)
        add_data_center_constraints!(scuc, NT, NS, config_param, ND2, data_centers)
        add_frequency_constraints!(scuc, NT, NG, NC, NS, units, storages, config_param, Δp_contingency)
        # --- Solve and Extract Results ---
        results = solve_and_extract_results(
            scuc, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob, eachslope, refcost, config_param,
            units, loads, winds, lines, data_centers; NB = NB)
        if results !== nothing
            if clustered_enabled
                cluster_strict=lowercase(get(ENV, "PCM_CLUSTER_STRICT", "false")) in ("1", "true", "yes", "on")
                clustered=apply_clustered_pcm_optimization!(
                    results, units, loads, winds, lines, config_param, NB, NL; optimizer = pcm_optimizer(),
                    strict = cluster_strict, storages = storages, data_centers = data_centers, hydros = hydros)
                clustered.feasible||error("Clustered PCM disaggregation failed at $(clustered.stage): $(clustered.feedback)")
                if !clustered.network_feasible && config_param.is_network_con==1 && NL>0
                    println("  ↻ Network feedback: adding PTDF constraints and re-solving the current PCM window")
                    add_transmission_constraints!(
                        scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, storages, Gsdf, config_param, ND2, data_centers)
                    results=solve_and_extract_results(
                        scuc, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob, eachslope, refcost, config_param,
                        units, loads, winds, lines, data_centers; NB = NB)
                    results===nothing&&error("Network-feedback re-solve failed")
                    repaired_clusters=build_pcm_clusters(units)
                    results["cluster_ids"]=Float64.([only(c.id for c ∈ repaired_clusters if i in c.unit_indices) for i ∈ 1:NG])
                    results["cluster_disaggregation_feasible"]=ones(Float64, NS, 1)
                    clustered=(feasible = true, strictly_feasible = true, network_feasible = true, stage = :network_feedback_repaired,
                        clusters = repaired_clusters, checks = clustered.checks, results = nothing, feedback = nothing)
                end
                println("  ✓ Clustered UC residence/network disaggregation completed ($(length(clustered.clusters)) clusters, stage=$(clustered.stage))")
            end
            return results
        end
        println("Optimization failed, returning nothing.")
        return nothing
    end # end SUC_scucmodel function
end # end guard _PERIOD_SCUC_MODULES_INCLUDED
