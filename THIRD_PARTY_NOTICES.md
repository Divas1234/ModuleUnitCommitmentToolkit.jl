# Third-party notices

This file records the licensing boundary for the dependencies used by
`ModuleUnitCommitmentToolkit`. It is a compliance aid, not legal advice and
not a substitute for checking the exact versions and artifacts distributed in
a particular product.

## Project source

The project-owned source code is released under the root [MIT license](LICENSE).
That license does not automatically apply to external packages, solver
installations, binary artifacts, test systems, or data files kept under
`ref/` and `data/`.

## Julia package dependencies

The retained Julia dependencies are primarily distributed under MIT or
BSD-family licenses. When redistributing their source, retain the copyright
notices, license texts, and disclaimers supplied by each dependency.

- MIT-family dependencies include `CSV`, `Clustering`, `DataFrames`,
  `DelimitedFiles`, `Distributions`, `JLD2`, `JuMP`, `MathOptInterface`,
  `MultivariateStats`, `TOML`, `UnicodePlots`, and `XLSX`.
- `PowerSystems` and `PowerSystemCaseBuilder` use BSD-3-Clause licensing.
  Preserve their attribution and disclaimer when redistributing them.
- `Gurobi.jl` is a Julia wrapper. The Gurobi Optimizer runtime is separate
  proprietary software and is not granted or redistributed by this project.
  Users and downstream products must obtain their own applicable Gurobi
  license.

The package has no direct `QHull` dependency. Legacy reference visualizations
under the local-only `ref/` archive may use it, but that archive is excluded
from the package repository and release environment. Its installed package has
inconsistent license signals, so it must not be reintroduced into the formal
package dependency graph without upstream clarification.

## Binary artifacts and optional tooling

The package keeps `Plots`, `PlotlyJS`, and `LaTeXStrings` as direct
dependencies because the repository contains supported result-visualization
code. If a downstream application adds video, PDF, or other native-artifact
features, it must review the licenses of the downloaded artifacts separately;
Julia wrapper licenses do not automatically license the wrapped native
binaries.

## Repository data and reference material

The local `ref/` research archive is excluded by `.gitignore` and is not part of
the package release. The files under `data/` are not blanket-covered by the
root MIT license. Before redistributing data or case files, record the source,
copyright holder, and redistribution permission for every external dataset,
document, image, and generated artifact. IEEE/MATPOWER-derived cases must
retain their upstream attribution and be distributed only under terms that
permit the intended use.
