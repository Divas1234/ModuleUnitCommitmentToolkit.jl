# JuliaHub / General Registry publishing notes

The repository root is already a standard Julia package:

```text
Project.toml
src/ModuleUnitCommitmentToolkit.jl
test/runtests.jl
LICENSE
```

Package metadata:

```text
name   = ModuleUnitCommitmentToolkit
uuid   = ac5da903-c047-492f-9e2d-d451e318368d
version = 0.1.0
```

## Pre-release checks

1. Run `Pkg.test()` from the repository root and confirm that every test passes.
2. Confirm that every direct dependency in `Project.toml` has an upper-bounded `[compat]` entry.
3. Confirm that `src/ModuleUnitCommitmentToolkit.jl` matches the package name exactly.
4. Confirm that an OSI-approved license exists at the top level. This project uses the MIT License.
5. Push the current commit to GitHub and create a `v0.1.0` tag.
6. Review [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) before publishing, especially the
   Gurobi external license, the PowerSystems BSD-3-Clause notice, and the source
   authorization for cases and data under `ref/` and `data/`.

Julia General's automerge rule requires a public package repository URL to end with the package name:

```text
https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl
```

The GitHub repository has been renamed to `ModuleUnitCommitmentToolkit.jl`. Its remote URL is:

```text
https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl.git
```

That name matches the General registry convention for public package repository URLs.

## JuliaHub registration

JuliaHub currently creates General registry requests through Registrator:

1. Sign in to the JuliaHub Packages page and open Registrator.
2. Authorize Registrator to inspect commit permissions on the GitHub repository.
3. Enter the package URL, the `v0.1.0` tag, and the release notes.
4. Registrator opens a General registry pull request.
5. Wait for registry CI and a General maintainer to merge it.
6. JuliaHub periodically syncs registered versions. After the sync, users can run:

   ```julia
   using Pkg
   Pkg.add("ModuleUnitCommitmentToolkit")
   ```

## GitHub registration comment

Install the JuliaRegistrator GitHub App from:

<https://github.com/apps/juliateam-registrator/installations/new>

After the app is installed, comment on the commit or pull request that contains `Project.toml` version `0.1.0`:

```text
@JuliaRegistrator register

Release notes:

- Unified Benchmark, Benders, and CCG solver entry point.
- PowerSystems IEEE case bridge and frequency/data-center examples.
- DataFrame-based input and result reports with CSV snapshots.
```

Registration requires a GitHub or JuliaHub login. It cannot be completed with a local `Pkg` command alone.
