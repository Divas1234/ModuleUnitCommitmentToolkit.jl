# C&CG Solver

This folder contains a finite-scenario Column-and-Constraint Generation driver for the stochastic/DRO SCUC model.

Renewable uncertainty is represented by a wind scenario pool generated from `src/renewables`.
When DRO is enabled, the solver uses a finite-support Wasserstein ambiguity set around
the empirical scenario distribution. Scenario distances are computed from normalized
renewable power trajectories:

```text
P = { p >= 0, sum(p) = 1, W(p, p0) <= CCG_DRO_RADIUS }
```

The C&CG loop solves a master problem over active renewable scenarios, evaluates all
candidate single-scenario recourse problems, solves a transport LP for the worst-case
distribution, and adds the most adverse uncovered scenarios.

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
- `CCG_DRO_RADIUS`: Wasserstein ambiguity radius; default `0.05`. Use `0` for empirical stochastic C&CG.
- `CCG_WASSERSTEIN_POWER`: scenario trajectory distance power; default `1.0`.
- `CCG_PARALLEL_RECOURSE`: set to `1`/`true` to evaluate recourse scenarios in parallel; defaults to enabled when Julia has more than one thread.
- `CCG_MASTER_MIP_GAP`: Gurobi gap for the scenario-subset master.
- `CCG_RECOURSE_MIP_GAP`: Gurobi gap for single-scenario recourse checks.
- `CCG_MASTER_THREADS`: Gurobi thread count for the master; default `0` lets Gurobi choose.
- `CCG_RECOURSE_THREADS`: Gurobi thread count for each recourse model; default `1` when parallel recourse is enabled.
- `BENDERS_CONSIDER_BESS`: set to `1` to include storage binary operation.
