#!/usr/bin/env bash
set -euo pipefail

# Native zero-Docker local GitHub Actions CI runner for ModuleUnitCommitmentToolkit.jl.
# Mirrors .github/workflows/ci.yml and optionally .github/workflows/release-macos-dmg.yml.
#
# Usage:
#   bash scripts/run_ci_local.sh              # Workflow lint + Shell + GUI + Julia syntax + Julia tests
#   bash scripts/run_ci_local.sh --fast       # Skip full Julia test suite (fast syntax + GUI check)
#   bash scripts/run_ci_local.sh --dmg        # Also build and verify the macOS DMG installer

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

RUN_JULIA_TESTS=1
RUN_DMG=0

for arg in "$@"; do
  case "$arg" in
    --fast)
      RUN_JULIA_TESTS=0
      ;;
    --dmg)
      RUN_DMG=1
      ;;
    -h|--help)
      echo "Usage: bash scripts/run_ci_local.sh [--fast] [--dmg]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

echo "========================================================================"
echo "Local GitHub Actions CI :: ModuleUnitCommitmentToolkit.jl"
echo "========================================================================"

echo ""
echo "[1/5] GitHub Actions workflow lint (actionlint)..."
if command -v actionlint >/dev/null 2>&1; then
  actionlint
  echo "  [OK] actionlint passed"
else
  echo "  [WARN] actionlint not installed (install via: brew install actionlint)"
fi

echo ""
echo "[2/5] Shell script syntax check..."
bash -n gui/start.sh
bash -n scripts/build_macos_dmg.sh
bash -n scripts/run_ci_local.sh
bash -n scripts/run_benders_benchmarks.sh
echo "  [OK] All shell scripts passed bash -n"

echo ""
echo "[3/5] Python GUI unit tests & HTML build..."
python3 -m py_compile gui/server.py gui/build_html.py test/gui/test_gui_security.py
python3 -m unittest discover -s test/gui -v
python3 gui/build_html.py
test -s gui/index.html
echo "  [OK] GUI tests and HTML build passed"

echo ""
echo "[4/5] Julia Project.toml & full-repo syntax check..."
julia -e '
  using TOML
  proj = TOML.parsefile("Project.toml")
  @assert haskey(proj, "name") && proj["name"] == "ModuleUnitCommitmentToolkit"
  let checked = 0
    for root_dir in ("src", "tools", "test", "gui", "scripts")
      isdir(root_dir) || continue
      for (dir, _, files) in walkdir(root_dir)
        for f in files
          endswith(f, ".jl") || continue
          path = joinpath(dir, f)
          Meta.parseall(read(path, String); filename = path)
          checked += 1
        end
      end
    end
    println("  [OK] Parsed ", checked, " Julia files with zero syntax errors")
  end
'

echo ""
if [ "$RUN_JULIA_TESTS" -eq 1 ]; then
  echo "[5/5] Running full Julia test suite (julia --project=. test/runtests.jl)..."
  julia --project=. test/runtests.jl
  echo "  [OK] Full Julia test suite passed"
else
  echo "[5/5] Skipping full Julia test suite (--fast)"
fi

if [ "$RUN_DMG" -eq 1 ]; then
  echo ""
  echo "[Bonus] Building & verifying macOS DMG..."
  bash scripts/build_macos_dmg.sh
fi

echo ""
echo "========================================================================"
echo "Local CI Complete: ALL CHECKS PASSED"
echo "========================================================================"
