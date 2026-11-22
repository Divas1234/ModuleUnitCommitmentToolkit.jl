"""
Structured terminal diagnostics & execution logging for `tools/*/example_run.jl`.

Provides a unified CLI/ENV option set covering 6 observability layers:
1. Active constraint checklist (which constraints enter the model)
2. Model & input integrity verification results
3. Optimization start/finish timestamps and live solver progress
4. Post-solve key results summary printed to terminal
5. Artifact save timing and exact output directory / file listing
6. Persistent execution log file under `output/logs/`
"""

using Dates
using Printf

Base.@kwdef mutable struct UCExampleOptions
    scenario_limit::Int = 2
    fast_direct::Bool = false
    verbosity::Symbol = :summary
    show_constraints::Bool = false
    show_integrity::Bool = false
    show_solver_log::Bool = false
    show_results::Bool = true
    show_artifacts::Bool = true
    save_log::Bool = true
    log_file::Union{Nothing, String} = nothing
    help::Bool = false
end

function _example_env_flag(key::String, default::Bool)
    raw = lowercase(strip(get(ENV, key, "")))
    isempty(raw) && return default
    return raw in ("1", "true", "yes", "on")
end

function print_example_run_usage(script_path::AbstractString; supports_fast::Bool = false)
    fast_line = supports_fast ? "  --fast                   Enable Benders fast direct solve mode\n" : ""
    println(
        """
        Usage:
          julia --project=. $(script_path) [scenario_limit] [OPTIONS]

        Diagnostic & Output Options:
          --all-details            Enable ALL 6 detail layers (constraints, integrity, solver log, results, artifacts, log file)
          --show-constraints       [1] Print active constraint modules & custom hooks entering the model
          --show-integrity         [2] Print post-build data & model integrity validation checks
          --show-solver-log        [3] Print optimization timestamps & live solver/iteration output
          --show-results           [4] Print key optimization results & cost breakdown to terminal (default: on)
          --show-artifacts         [5] Print save timestamp, output folder, and written artifact files (default: on)
          --log-file[=PATH]        [6] Write detailed execution log file (default: output/logs/<algo>_<timestamp>.log)
          --no-log                 Disable writing the execution log file
          --verbosity=MODE         One of: summary, detailed, verbose (default: summary)
          -v, --verbose            Shortcut for --verbosity=verbose --show-solver-log
        $(fast_line)  -h, --help               Show this help message

        Environment Shortcuts:
          UC_EXAMPLE_DETAILS=1     Equivalent to --all-details
        """,
    )
    return nothing
end

function parse_example_run_args(args::AbstractVector{<:AbstractString}; default_scenarios::Int = 2)
    all_env = _example_env_flag("UC_EXAMPLE_DETAILS", false)
    opts = UCExampleOptions(
        scenario_limit = default_scenarios,
        show_constraints = all_env || _example_env_flag("UC_SHOW_CONSTRAINTS", false),
        show_integrity = all_env || _example_env_flag("UC_SHOW_INTEGRITY", false),
        show_solver_log = all_env || _example_env_flag("UC_SHOW_SOLVER_LOG", false),
        show_results = true,
        show_artifacts = true,
        save_log = true,
    )
    if all_env
        opts.verbosity = :verbose
    end

    for raw in args
        arg = String(raw)
        if arg in ("-h", "--help")
            opts.help = true
        elseif arg == "--fast"
            opts.fast_direct = true
        elseif arg == "--all-details"
            opts.show_constraints = true
            opts.show_integrity = true
            opts.show_solver_log = true
            opts.show_results = true
            opts.show_artifacts = true
            opts.save_log = true
            opts.verbosity = :verbose
        elseif arg == "--show-constraints"
            opts.show_constraints = true
        elseif arg == "--show-integrity"
            opts.show_integrity = true
        elseif arg == "--show-solver-log"
            opts.show_solver_log = true
            opts.verbosity = :verbose
        elseif arg == "--show-results"
            opts.show_results = true
        elseif arg == "--no-results"
            opts.show_results = false
        elseif arg == "--show-artifacts"
            opts.show_artifacts = true
        elseif arg == "--no-artifacts"
            opts.show_artifacts = false
        elseif arg == "--no-log"
            opts.save_log = false
        elseif arg == "--log-file"
            opts.save_log = true
        elseif startswith(arg, "--log-file=")
            opts.save_log = true
            opts.log_file = split(arg, "="; limit = 2)[2]
        elseif arg in ("-v", "--verbose")
            opts.verbosity = :verbose
            opts.show_solver_log = true
        elseif arg == "--detailed"
            opts.verbosity = :detailed
        elseif startswith(arg, "--verbosity=")
            mode = Symbol(lowercase(split(arg, "="; limit = 2)[2]))
            mode in (:summary, :detailed, :verbose) || throw(ArgumentError("Invalid verbosity: $(mode)"))
            opts.verbosity = mode
            mode === :verbose && (opts.show_solver_log = true)
        elseif !startswith(arg, "-")
            opts.scenario_limit = parse(Int, arg)
        else
            throw(ArgumentError("Unknown option: $(arg). Run with --help to see available flags."))
        end
    end
    return opts
end

"""
    resolve_uc_example_options(args; scenario_limit = 2, fast_direct = false,
        show_constraints = false, show_integrity = false, show_solver_log = false,
        show_results = true, show_artifacts = true, save_log = true,
        log_file = nothing, verbosity = :summary)

Build a `UCExampleOptions` from explicit keyword defaults when `args` is empty,
or parse CLI overrides from `args` (inheriting `scenario_limit` as default).
"""
function resolve_uc_example_options(
    args::AbstractVector{<:AbstractString};
    scenario_limit::Int = 2,
    fast_direct::Bool = false,
    show_constraints::Bool = false,
    show_integrity::Bool = false,
    show_solver_log::Bool = false,
    show_results::Bool = true,
    show_artifacts::Bool = true,
    save_log::Bool = true,
    log_file::Union{Nothing, String} = nothing,
    verbosity::Symbol = :summary,
)
    if isempty(args)
        return UCExampleOptions(
            scenario_limit = scenario_limit,
            fast_direct = fast_direct,
            verbosity = show_solver_log ? :verbose : verbosity,
            show_constraints = show_constraints,
            show_integrity = show_integrity,
            show_solver_log = show_solver_log,
            show_results = show_results,
            show_artifacts = show_artifacts,
            save_log = save_log,
            log_file = log_file,
        )
    end
    return parse_example_run_args(args; default_scenarios = scenario_limit)
end

function _diag_emit(log_lines::Vector{String}, msg::AbstractString)
    println(msg)
    push!(log_lines, String(msg))
    return nothing
end

function _diag_timestamp()
    return Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
end

function _print_constraint_inventory(log_lines::Vector{String}, cfg::UCConfig, prob::UCProblemData)
    _diag_emit(log_lines, "\n[1/6] Active Constraint Modules Entering the Model")
    _diag_emit(log_lines, "-"^72)
    items = [
        ("Thermal Unit Operation (Min Up/Down, Binary Logic, Startup/Shutdown)", cfg.is_thermal_unit_con == 1),
        ("Generator Power & Ramp-Up/Down Limits", cfg.is_thermal_unit_con == 1),
        ("Piecewise Linear Fuel Cost ($(cfg.num_segments) segments)", cfg.is_piecewise_linear == 1),
        ("Active Load & Load/Wind Curtailment Limits", cfg.is_active_load == 1),
        ("System Power Balance & Spinning Reserve Limits", cfg.is_system_con == 1),
        ("Stochastic Wind Integration ($(prob.NW) wind farms x $(prob.NS) scenarios)", cfg.is_wind_unit_con == 1 && cfg.is_wind_integration == 1),
        ("Transmission Network DC-OPF Limits ($(prob.NL) lines)", cfg.is_network_con == 1),
        ("Battery Energy Storage / BESS Constraints ($(prob.NC) units)", cfg.consider_bess == 1 && prob.NC > 0),
        ("Data Center Flexible Load Constraints ($(prob.ND2) sites)", cfg.consider_data_center == 1 && prob.ND2 > 0),
        ("Frequency Security (Nadir / QSS / RoCoF) Constraints", cfg.consider_frequency_control == 1),
        ("Multi-Cut Benders Disaggregation", cfg.consider_multi_cuts == 1),
    ]
    active_count = 0
    for (name, enabled) in items
        enabled && (active_count += 1)
        tag = enabled ? "[ ON  ]" : "[ OFF ]"
        _diag_emit(log_lines, "  $tag $name")
    end
    _diag_emit(log_lines, "  Summary: $(active_count)/$(length(items)) built-in constraint groups active.")
    return nothing
end

function _print_integrity_report(log_lines::Vector{String}, prob::UCProblemData)
    _diag_emit(log_lines, "\n[2/6] Model & Input Integrity Verification")
    _diag_emit(log_lines, "-"^72)
    scenarios_prob = 1.0 / max(1, prob.NS)
    base_ok = validate_inputs(prob; scenarios_prob = scenarios_prob)
    total_pmax = sum(prob.units.p_max)
    peak_load = maximum(sum(prob.loads.load_curve; dims = 1))
    checks = [
        ("Core validate_inputs(UCProblemData)", base_ok),
        ("Dimensions positive (NB=$(prob.NB), NG=$(prob.NG), NL=$(prob.NL), ND=$(prob.ND), NT=$(prob.NT), NS=$(prob.NS))", prob.NB > 0 && prob.NG > 0 && prob.NT > 0 && prob.NS > 0),
        ("Generator bounds valid (all p_max >= p_min)", all(prob.units.p_max .>= prob.units.p_min)),
        ("Transmission line limits non-negative", all(prob.lines.p_max .>= 0)),
        ("Load curve finite and non-negative", all(isfinite, prob.loads.load_curve) && all(prob.loads.load_curve .>= 0)),
        ("Wind scenarios finite and non-negative", all(isfinite, prob.winds.scenarios_curve) && all(prob.winds.scenarios_curve .>= 0)),
        (@sprintf("Generation adequacy (Total Pmax=%.2f >= Peak Load=%.2f)", total_pmax, peak_load), total_pmax >= peak_load),
    ]
    passed = count(last, checks)
    for (label, ok) in checks
        _diag_emit(log_lines, "  [$(ok ? "PASS" : "WARN")] $label")
    end
    _diag_emit(log_lines, "  Integrity Score: $(passed)/$(length(checks)) checks passed.")
    return nothing
end

function _snapshot_output_files(root::AbstractString)
    snap = Dict{String, Float64}()
    isdir(root) || return snap
    for (dir, _, files) in walkdir(root)
        for f in files
            p = joinpath(dir, f)
            snap[p] = mtime(p)
        end
    end
    return snap
end

function _print_key_results(log_lines::Vector{String}, result::UCSolveResult, elapsed_sec::Float64)
    _diag_emit(log_lines, "\n[4/6] Key Optimization Results")
    _diag_emit(log_lines, "-"^72)
    details = result.details
    status = hasproperty(details, :status) ? details.status : "UNKNOWN"
    lb = hasproperty(details, :lower_bound) ? details.lower_bound : nothing
    ub = hasproperty(details, :upper_bound) ? details.upper_bound : nothing
    gap = hasproperty(details, :gap) ? details.gap : nothing
    iters = hasproperty(details, :iterations) ? details.iterations : nothing

    _diag_emit(log_lines, "  Algorithm       : $(result.algorithm)")
    _diag_emit(log_lines, "  Input Source    : $(result.input)")
    _diag_emit(log_lines, "  Status          : $(status)")
    lb !== nothing && _diag_emit(log_lines, @sprintf("  Lower Bound     : %.4f", Float64(lb)))
    ub !== nothing && _diag_emit(log_lines, @sprintf("  Upper Bound     : %.4f", Float64(ub)))
    gap !== nothing && _diag_emit(log_lines, @sprintf("  Optimality Gap  : %.6e", Float64(gap)))
    iters !== nothing && _diag_emit(log_lines, "  Iterations      : $(iters)")
    _diag_emit(log_lines, @sprintf("  Wall Time       : %.3f s", elapsed_sec))

    if hasproperty(details, :cost_summary) && details.cost_summary !== nothing
        cs = details.cost_summary
        _diag_emit(log_lines, "  Cost Breakdown  :")
        for k in keys(cs)
            val = getfield(cs, k)
            if val isa Real
                _diag_emit(log_lines, @sprintf("    - %-24s : %.4f", string(k), Float64(val)))
            end
        end
    end
    return nothing
end

function _print_artifact_report(log_lines::Vector{String}, output_dir::AbstractString, before_snap::Dict{String, Float64}, after_snap::Dict{String, Float64})
    _diag_emit(log_lines, "\n[5/6] Result Persistence & Saved Folders")
    _diag_emit(log_lines, "-"^72)
    _diag_emit(log_lines, "  Saved Timestamp : $(_diag_timestamp())")
    _diag_emit(log_lines, "  Output Root Dir : $(output_dir)")
    changed = String[]
    for (p, mt) in after_snap
        if !haskey(before_snap, p) || mt > before_snap[p]
            push!(changed, p)
        end
    end
    sort!(changed)
    if isempty(changed)
        _diag_emit(log_lines, "  New/Updated Files: (none detected in output directory)")
    else
        dirs = sort!(unique(dirname.(changed)))
        _diag_emit(log_lines, "  Target Folders ($(length(dirs))):")
        for d in dirs
            _diag_emit(log_lines, "    - $(d)")
        end
        _diag_emit(log_lines, "  Saved Files ($(length(changed))):")
        for p in first(changed, 20)
            _diag_emit(log_lines, "    - $(relpath(p, output_dir))")
        end
        length(changed) > 20 && _diag_emit(log_lines, "    ... and $(length(changed) - 20) more files")
    end
    return nothing
end

function _strip_ansi(s::AbstractString)
    return replace(s, r"\e\[[0-9;]*[A-Za-z]" => "")
end

function _run_with_terminal_tee(fn::Function, log_lines::Vector{String})
    orig_stdout = stdout
    orig_stderr = stderr
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    captured = IOBuffer()
    reader = @async begin
        try
            while !eof(pipe.out)
                chunk = String(readavailable(pipe.out))
                isempty(chunk) && continue
                write(orig_stdout, chunk)
                flush(orig_stdout)
                write(captured, _strip_ansi(chunk))
            end
        catch
        end
    end
    result = try
        redirect_stdout(pipe.in) do
            redirect_stderr(pipe.in) do
                fn()
            end
        end
    finally
        flush(pipe.in)
        close(pipe.in)
        wait(reader)
        close(pipe.out)
    end
    body = String(take!(captured))
    if !isempty(body)
        append!(log_lines, split(chomp(body), '\n'))
    end
    return result
end

"""
    run_uc_example_workflow(alg::AbstractUCAlgorithm, opts::UCExampleOptions; algo_name, input = :excel, calibration = NamedTuple(), optimizer = nothing)

Execute a UC algorithm example with structured 6-stage terminal observability and
optional persistent log file output (capturing the full optimization process).
"""
function run_uc_example_workflow(
    alg::AbstractUCAlgorithm,
    opts::UCExampleOptions;
    algo_name::AbstractString,
    input::Symbol = :excel,
    calibration = NamedTuple(),
    optimizer = nothing,
    extra_kwargs...,
)
    log_lines = String[]
    ts_tag = Dates.format(now(), "yyyymmdd_HHMMSS")
    output_root = uc_output_root()
    resolved_log = opts.save_log ? something(opts.log_file, joinpath(output_root, "logs", "$(algo_name)_example_$(ts_tag).log")) : nothing

    _diag_emit(log_lines, "="^72)
    _diag_emit(log_lines, "UC Example Run :: $(uppercase(String(algo_name)))  |  $(_diag_timestamp())")
    _diag_emit(log_lines, "  Scenarios=$(opts.scenario_limit), Verbosity=$(opts.verbosity), Constraints=$(opts.show_constraints), Integrity=$(opts.show_integrity), SolverLog=$(opts.show_solver_log)")
    _diag_emit(log_lines, "="^72)

    if opts.show_constraints || opts.show_integrity
        raw_data = load_uc_data(input = input, scenario_limit = opts.scenario_limit)
        prob = UCProblemData(raw_data)
        opts.show_constraints && _print_constraint_inventory(log_lines, prob.config_param, prob)
        opts.show_integrity && _print_integrity_report(log_lines, prob)
    end

    before_snap = opts.show_artifacts ? _snapshot_output_files(output_root) : Dict{String, Float64}()

    opt_name = optimizer === nothing ? string(default_uc_optimizer()) : string(optimizer)
    _diag_emit(log_lines, "\n[3/6] Starting Optimization")
    _diag_emit(log_lines, "-"^72)
    _diag_emit(log_lines, "  Start Time      : $(_diag_timestamp())")
    _diag_emit(log_lines, "  Optimizer       : $(opt_name)")
    _diag_emit(log_lines, "  Solver Output   : $(opts.show_solver_log ? "STREAMING LIVE + LOGGED (verbosity=:verbose)" : "COMPACT (pass --show-solver-log or --all-details for live solver trace)")")

    t0 = time()
    solve_call = () -> solve_uc(
        alg;
        input = input,
        scenario_limit = opts.scenario_limit,
        verbosity = opts.show_solver_log ? :verbose : opts.verbosity,
        calibration = calibration,
        optimizer = optimizer,
        extra_kwargs...,
    )
    result = (resolved_log !== nothing && opts.show_solver_log) ?
        _run_with_terminal_tee(solve_call, log_lines) :
        solve_call()
    elapsed_sec = time() - t0
    _diag_emit(log_lines, @sprintf("  Finish Time     : %s  (elapsed: %.3f s)", _diag_timestamp(), elapsed_sec))

    opts.show_results && _print_key_results(log_lines, result, elapsed_sec)

    if opts.show_artifacts
        after_snap = _snapshot_output_files(result.output_dir)
        _print_artifact_report(log_lines, result.output_dir, before_snap, after_snap)
    end

    if resolved_log !== nothing
        mkpath(dirname(resolved_log))
        _diag_emit(log_lines, "\n[6/6] Execution Log File")
        _diag_emit(log_lines, "-"^72)
        _diag_emit(log_lines, "  Log Path        : $(resolved_log)")
        write(resolved_log, join(log_lines, "\n") * "\n")
    end

    return result
end
