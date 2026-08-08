# JuliaHub / General Registry Publishing Notes

The repository root follows the standard Julia package layout:

```text
Project.toml
src/ModuleUnitCommitmentToolkit.jl
test/runtests.jl
LICENSE
```

Package metadata:

```text
name    = ModuleUnitCommitmentToolkit
uuid    = ac5da903-c047-492f-9e2d-d451e318368d
version = 0.1.0
```

## Pre-Publish Checklist

1. Run `Pkg.test()` from the repository root and confirm that all tests pass.
2. Confirm that every direct dependency in `Project.toml` has a bounded `[compat]` entry.
3. Confirm that `src/ModuleUnitCommitmentToolkit.jl` exactly matches the package name.
4. Confirm that the repository root contains an OSI-approved license; this project uses the MIT License.
5. Push the release commit to GitHub and create the `v0.1.0` tag.
6. Review [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md), especially Gurobi external licensing, the PowerSystems BSD-3-Clause notice, and the provenance of cases and data under `ref/` and `data/`.

Julia General auto-merge rules expect the public package repository URL to end with the package name:

```text
https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl
```

The repository has been renamed to `ModuleUnitCommitmentToolkit.jl`, and the remote URL is:

```text
https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl.git
```

This naming satisfies the Julia General registry repository-name convention.

## JuliaHub Registration Flow

JuliaHub currently uses Registrator to create General registry registration requests:

1. Sign in to JuliaHub and open the Packages page.
2. Authorize Registrator to inspect the GitHub repository.
3. Fill in the package URL, tag `v0.1.0`, and release notes.
4. Registrator creates a General registry pull request.
5. Wait for registry CI and General maintainers to merge it.
6. After JuliaHub syncs the registered version, users can install the package with:

```julia
using Pkg
Pkg.add("ModuleUnitCommitmentToolkit")
```

## GitHub Registration Comment

The JuliaRegistrator GitHub App installation page is:

<https://github.com/apps/juliateam-registrator/installations/new>

After installing the app, comment on the release commit or pull request that contains `Project.toml` version `0.1.0`:

```text
@JuliaRegistrator register

Release notes:

- Unified Benchmark, Benders, and CCG solver entry point.
- PowerSystems IEEE case bridge and frequency/data-center examples.
- DataFrame-based input and result reports with CSV snapshots.
```

Registration requires GitHub or JuliaHub account authorization; it cannot be completed only with local `Pkg` commands.
