# Project Code Review

Review date: 2026-07-13

Scope: `src/`, `tools/`, `gui/`, `examples/`, `docs/`, `test/`, and the package entry files.

## Executive Summary

The data pipeline and lightweight module tests are stable. The previous public interface was split across package functions, script-level functions, and legacy positional tuples. The current implementation adds a unified data entry point and unified algorithm entry point. Remaining engineering priorities are GUI security boundaries, output-path decoupling, cleanup of legacy tuple compatibility, and broader algorithm-level integration tests.

## Findings

### P1: GUI endpoints previously listened on all network interfaces

`gui/server.py` exposes `/api/config`, `/api/run`, and `/api/run/cancel`. These endpoints can write runtime configuration, start Julia tasks, and stop running tasks. Binding the server to `0.0.0.0:8080` without authentication, CSRF protection, or origin restrictions would allow other hosts on a shared network to trigger local management actions.

The default bind address is now `127.0.0.1:8080`. Remote binding requires `MODULE_UC_GUI_ALLOW_REMOTE=1`, a bearer token, and an allow-list of origins. The service also validates request size, task parameters, origin, authentication headers, and API/run rate limits, and returns baseline security headers. Public deployments should still add TLS, audit logging, and finer-grained account permissions at the reverse-proxy or service layer.

### P1: Algorithm entry points were not exposed through one package API

`ModuleUnitCommitmentToolkit` originally exposed data reading, bridging, and model utilities, while Benchmark, Benders, and CCG entry points required manual `include("tools/...")` calls. This made algorithms hard to discover from `using ModuleUnitCommitmentToolkit`, made scripts sensitive to include order and current working directory, and prevented a common input/result contract.

The package now provides `ModuleUnitCommitmentToolkit.solve_uc`. It uses `algorithm` to select `benchmark`, `benders`, or `ccg`, uses `input` to select Excel, native PowerSystems, or PowerSystems CSV data, and centralizes runtime calibration. Algorithm implementations remain lazily loaded so importing the package does not start solvers or create output side effects. Lower-level `tools/` functions remain as compatibility layers.

### P1: Benders setup returned a long positional tuple

`tools/benders/setup.jl` previously returned 20 positional values, so callers had to remember the exact order of fields such as `NB`, `NG`, `NL`, `ND`, `NS`, `NT`, `NC`, and `ND2`. Any field insertion or deletion could silently shift values.

`BendersSetup` now provides named-field access while preserving a read-only compatibility iterator for legacy 20-element destructuring. New code should use `UCSolveRequest` and `UCSolveResult`. The compatibility iterator can be removed after downstream callers migrate.

### P2: PowerSystems examples did not match real signatures

The review found and corrected several misleading examples: an extensive-form example missed a closing parenthesis, a CCG example passed an unsupported positional `data` argument and unsupported `initial_scenarios` keyword, and a Benders example passed `winds.scenarios_nums` where `NW` was expected.

The corrections are in `docs/powersystems_algorithms_guide.md` and related unified API examples.

### P2: Output paths depended on `pwd()`

Some export utilities previously used the current working directory as the output base. Results could therefore move when library functions were called from notebooks, services, or CI jobs.

The default output root is now the project-level `output/` directory. Callers can override it with `MODULE_UC_OUTPUT_DIR`, the unified-entry `output_dir` keyword, or export-function arguments. Benchmark and CCG scheduling outputs now share this output-root resolver. Benders currently returns in-memory results through the unified result object and does not automatically export the same scheduling files.

### P2: Algorithm and GUI integration tests remain thin

Lightweight tests cover data reading, PowerSystems bridging, model utilities, DRO helpers, unified-entry routing, and calibration behavior. CI includes smoke tests for Benchmark, Benders, CCG, and GUI request validation. Broader tests should continue to cover objective comparisons, task locking, cancellation, timeout behavior, and malformed GUI/API inputs.

## Recommended Next Steps

1. Add tolerance-based objective comparisons between Benders and extensive-form results.
2. Add CCG tests for maximum-iteration handling and infeasible recourse cases.
3. Add GUI tests for concurrent run rejection, cancellation, invalid tokens, and oversized payloads.
4. Complete migration away from positional Benders setup destructuring.
5. Keep documentation examples aligned with the public `solve_uc` interface.
