# Project code review

Review date: 2026-07-13

Scope: `src/`, `tools/`, `gui/`, `examples/`, `docs/`, `test/`, and the project entry points.

## Summary

The data pipeline and the basic module tests are stable. The public interface used to be split across package functions, script functions, and legacy positional tuples. This revision adds one data entry point and one algorithm entry point. The remaining focus is the GUI security boundary, output-path decoupling, the positional-tuple compatibility layer, and algorithm-level integration tests. The same pass also corrected three documentation examples that would have misled callers, and restricted the GUI default listen address to the local loopback interface.

## Findings

### P1: The GUI previously listened on every interface and exposed config writes and task launch

`gui/server.py` writes runtime configuration through `/api/config`, starts Julia tasks through `/api/run`, and stops them through `/api/run/cancel`. It originally bound `0.0.0.0:8080` without authentication, CSRF protection, or an origin check. On a shared network, another host could call these local management endpoints.

The default bind is now `127.0.0.1:8080`. A remote bind requires `MODULE_UC_GUI_ALLOW_REMOTE=1`, a bearer token, and an allow-list of origins at the same time. The server also checks body size, task arguments, origin, the authentication header, and API or run rate, and it returns baseline security headers. A public deployment should still add TLS, audit logs, and finer-grained account permissions at the reverse proxy.

### P1: Algorithm entry points were outside the package API (resolved)

`ModuleUnitCommitmentToolkit` mainly exposed data readers, bridges, and the base model functions. Benchmark, Benders, and CCG still required a manual `include("tools/...")`. That caused three problems:

- users of `using ModuleUnitCommitmentToolkit` could not discover the three algorithms directly;
- scripts depended on include order and the current working directory;
- the algorithms did not share input and result types.

`ModuleUnitCommitmentToolkit.solve_uc` is now the single entry point. `algorithm` selects `benchmark`, `benders`, or `ccg`. `input` selects Excel, a native PowerSystems system, or PowerSystems CSV extensions. `calibration` sets runtime calibration parameters in one place. Algorithm implementations still load lazily, so importing the package does not start a solver or write output. The older `tools/` functions remain as a compatibility layer.

### P1: Benders `main` returned a positional tuple, which was costly to maintain and easy to mis-order

`main` in `tools/benders/setup.jl:33` returned 20 positional values. Callers had to remember the order of `NB, NG, NL, ND, NS, NT, NC, ND2`, and Benders, benchmark, and the examples each unpacked that tuple separately. Adding or removing a field could shift values silently, and Julia could not prompt for field names.

`BendersSetup` now provides named fields and keeps a read-only compatibility iterator for the old 20-value unpack. New algorithm calls should use `UCSolveRequest` and `UCSolveResult`. The compatibility iterator can be removed after the migration is finished.

### P2: Copyable examples in the original PowerSystems guide did not match the real signatures

The review found and corrected:

- the extensive-form example was missing the closing parenthesis of `solve_benchmark_uc_powersystems`;
- the CCG example passed a nonexistent positional `data` argument and an `initial_scenarios` keyword;
- the Benders example passed `winds.scenarios_nums` (scenario count) to `NW` (wind-unit count).

Corrected in [`powersystems_algorithms_guide.md`](powersystems_algorithms_guide.md) and
[`powersystems_example.jl`](powersystems_example.jl).

### P2: Output directories depended on `pwd()`, so library calls from another directory wrote results in an unstable location (resolved)

One exporter in `src/unit_commitment/utilities/export_results.jl` used the current working directory as its default output root. The default root is now `output/` under the project root. It can be overridden with `MODULE_UC_OUTPUT_DIR`, the unified entry point's `output_dir`, or an exporter argument. Algorithm run directories and schedule export share that resolution logic.

Callers should set `MODULE_UC_OUTPUT_DIR` explicitly, or pass `output_dir` to the unified entry point. Benchmark and CCG file output already uses the same root resolver. Benders currently returns in-memory results. The unified result object reports the configured `output_dir`, but it does not yet export the same schedule files automatically.

### P2: Algorithm-level and GUI-level integration tests are still thin

The lightweight tests cover data reading, the PowerSystems bridge, model utilities, DRO helpers, and unified-entry routing and calibration. CI includes a one-scenario benchmark/Benders/CCG smoke test and GUI request-validation tests. Full algorithm-quality comparisons, task exclusion, cancellation, and timeout behavior still need to grow. Add:

1. a tolerance comparison between Benders and the extensive-form objective;
2. the CCG maximum-iteration and no-feasible-solution branches;
3. GUI API concurrency, cancellation, and timeout behavior.

## Verification already run

```text
Julia 1.12.6
test/runtests.jl: 236 passed, 236 total
test/fast_interface.jl: 12 passed, 12 total
test/smoke_algorithms.jl: 7 passed, 7 total
test/test_gui_security.py: 4 passed, 4 total
222 Julia files in the project: syntax parse passed
```

`Project.toml` and the current Manifest also report dependency-version drift. Resolve, instantiate, and lock a reproducible environment before a formal release. That drift does not block the documentation and interface corrections in this review.

## Suggested priority

1. Done: named input and result types; the Benders positional tuple is in a compatibility migration.
2. Done: the three-algorithm smoke test is in CI, with the fast routing and data-entry tests kept.
3. Done: the output root is explicit, and library functions no longer default to the caller's `pwd()`.
4. Baseline protection done: the GUI listens only on localhost by default. A remote deployment must configure authentication and origin restrictions first.
