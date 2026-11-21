# Extensibility & External Integration Guide

`ModuleUnitCommitmentToolkit.jl` is structured around five pluggable extension points so external research scripts, solvers, data formats, and downstream pipelines can integrate without modifying core package files.

---

## 1. Solver-Agnostic Optimizer Injection

Switch MIP/LP solvers globally or within a task-local scope (thread/task-safe):

```julia
using ModuleUnitCommitmentToolkit
using HiGHS # or Gurobi, CPLEX, SCIP, etc.

# Option A: package-wide default
set_default_uc_optimizer!(HiGHS.Optimizer)

# Option B: scoped override (restored automatically)
result = with_uc_optimizer(HiGHS.Optimizer) do
    solve_uc(algorithm = :benchmark, input = :excel, scenario_limit = 2)
end

# Option C: per-request override
result = solve_uc(algorithm = :benders, optimizer = HiGHS.Optimizer)
```

---

## 2. Custom Input Data Loaders

Register any external data format (JSON, MATPOWER, CSV, database, or custom struct) via `register_uc_data_loader!`:

```julia
register_uc_data_loader!(:my_grid) do; data_file = nothing, kwargs...
    # Build and return the standard NamedTuple of UC data structs
    return my_custom_loader(data_file; kwargs...)
end

data = load_uc_data(input = :my_grid, data_file = "path/to/case.json")
registered_uc_data_loaders() # includes :excel, :powersystems, :powersystems_csv, :my_grid
```

---

## 3. Model Extension Hooks (Variables, Constraints, Objectives)

Inject domain-specific modeling components (e.g., hydrogen electrolyzers, carbon caps, transmission switching) directly into the UC formulation without editing `src/unit_commitment/`:

```julia
register_uc_variable_hook!(:electrolyzer_vars) do model, ctx
    @variable(model, p_elec[1:ctx.NT] >= 0)
end

register_uc_constraint_hook!(:carbon_cap) do model, ctx
    # Add custom constraints using ctx.units, ctx.loads, ctx.NT, etc.
end

register_uc_objective_hook!(:carbon_price) do model, ctx
    # Return an AffExpr to add to the total objective
end

# Clean up when done
clear_all_uc_hooks!()
```

---

## 4. Custom Solver / Algorithm Backends

Register external decomposition, heuristic, or PCM algorithms under `solve_uc`:

```julia
register_uc_algorithm!(:my_solver; aliases = ["custom_uc"]) do req::UCSolveRequest
    data = load_uc_data(req.input)
    # Solve and return a UCSolveResult
    return UCSolveResult(...)
end

solve_uc(algorithm = :my_solver, input = :excel)
```

---

## 5. Result Exporter Hooks

Attach downstream result sinks (Parquet, JSON telemetry, database, GUI) cleanly:

```julia
register_uc_exporter!(:json_sink) do result::UCSolveResult; output_dir = nothing
    # Serialize result to external storage
end

run_uc_exporters(result; output_dir = "output/custom")
```

---

## 6. Directory Architecture Contract

| Directory | Responsibility | Extension Pattern |
| --- | --- | --- |
| `src/` | Core reusable types, model builders, registries, and hooks | Extend via `register_uc_*!` APIs |
| `tools/` | Algorithm drivers (`benchmark/`, `benders/`, `ccg/`, `pcm/`) | Add new solver folder + register via `register_uc_algorithm!` |
| `config/` | Declarative TOML runtime defaults (`runtime_config.toml`) | Override per call via `calibration = (...)` or `*.local.toml` |
| `gui/` | Web dashboard & REST API (`server.py`, `build_html.py`) | Add task entry in `VALID_TASKS` + chart view in `build_html.py` |
| `scripts/` | Repository maintenance & release automation | Standalone CLI utilities |
| `examples/` | End-to-end runnable workflows | Mirror new capabilities with minimal scripts |
