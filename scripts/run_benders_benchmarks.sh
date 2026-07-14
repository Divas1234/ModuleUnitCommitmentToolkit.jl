#!/usr/bin/env bash
set -euo pipefail

SCENARIOS="${SCENARIOS:-5 10 20 50}"
MAX_ITERATIONS="${BENDERS_MAX_ITERATIONS:-180}"
LOG_DIR="${LOG_DIR:-docs/benchmarks/benders/logs}"

mkdir -p "$LOG_DIR"

for scenario_count in $SCENARIOS; do
  echo "Running Benders benchmark with ${scenario_count} scenarios"
  /usr/bin/time -p \
    env BENDERS_SCENARIO_LIMIT="$scenario_count" \
        BENDERS_MAX_ITERATIONS="$MAX_ITERATIONS" \
        BENDERS_VERBOSE_CUTS=0 \
        julia tools/benders/driver.jl \
    > "$LOG_DIR/benders_${scenario_count}.log" \
    2> "$LOG_DIR/benders_${scenario_count}.time"
done
