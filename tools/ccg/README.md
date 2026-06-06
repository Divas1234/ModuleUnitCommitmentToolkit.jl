# C&CG Solver

This folder contains a finite-scenario Column-and-Constraint Generation driver for the stochastic/DRO SCUC model.

Renewable uncertainty is represented by a wind scenario pool generated from `src/renewables`.
When DRO is enabled, the solver uses a finite-support total-variation ambiguity set around
the empirical scenario distribution:

```text
P = { p >= 0, sum(p) = 1, ||p - p0||_1 <= CCG_DRO_RADIUS }
```

The C&CG loop solves a master problem over active renewable scenarios, evaluates all
candidate single-scenario recourse problems, computes the worst-case distribution in the
ambiguity set, and adds the most adverse uncovered scenarios.

Run from the repository root:

```powershell
$env:CCG_SCENARIO_LIMIT='20'
$env:CCG_MAX_ITERATIONS='20'
$env:CCG_DRO_ENABLED='1'
$env:CCG_DRO_RADIUS='0.2'
julia -t auto tools\ccg\driver.jl
```

Useful environment variables:

- `CCG_SCENARIO_LIMIT`: candidate scenario pool size.
- `CCG_INITIAL_SCENARIOS`: number of scenarios in the first master; default `min(3, CCG_SCENARIO_LIMIT)`.
- `CCG_INITIAL_POLICY`: `netload` starts from high net-load scenarios; `first` starts from scenario 1.
- `CCG_SCENARIOS_PER_ITERATION`: number of worst uncovered scenarios to add per iteration; default `2`.
- `CCG_MAX_ITERATIONS`: maximum C&CG iterations.
- `CCG_GAP_TOL`: relative optimality gap tolerance.
- `CCG_DRO_ENABLED`: set to `1`/`true` to use the DRO objective and worst-distribution separation; default `true`.
- `CCG_DRO_RADIUS`: total-variation ambiguity radius in `[0, 2]`; default `0.2`. Use `0` for empirical stochastic C&CG.
- `CCG_PARALLEL_RECOURSE`: set to `1`/`true` to evaluate recourse scenarios in parallel; defaults to enabled when Julia has more than one thread.
- `CCG_MASTER_MIP_GAP`: Gurobi gap for the scenario-subset master.
- `CCG_RECOURSE_MIP_GAP`: Gurobi gap for single-scenario recourse checks.
- `CCG_MASTER_THREADS`: Gurobi thread count for the master; default `0` lets Gurobi choose.
- `CCG_RECOURSE_THREADS`: Gurobi thread count for each recourse model; default `1` when parallel recourse is enabled.
- `BENDERS_CONSIDER_BESS`: set to `1` to include storage binary operation.
