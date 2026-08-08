# IEEE-6 PCM Criteria Archive Manifest

- Archive directory: $absBatch
- Scenario: ieee6
- Source input: data/data.xlsx
- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Operational runtime metric: SubproblemSolveTime_sec
- Excluded from operational runtime: offline calibration time and local no-boundary reference solve time

## Contents

- `criteria_comparison_all_scenarios.csv` - `detailed_comparison_report.md` - `ieee6/avg_overlap_by_mode.svg` - `ieee6/cost_gap_by_mode.svg` - `ieee6/criteria_combination_intervals.csv` - `ieee6/criteria_combination_performance.csv` - `ieee6/criteria_intervals_detailed.csv` - `ieee6/criteria_performance_detailed.csv` - `ieee6/criteria_performance_summary.csv` - `ieee6/criteria_performance_summary.md` - `ieee6/detailed_scenario_report.md` - `ieee6/input_data_ieee6.xlsx` - `ieee6/interval_overlap_by_mode.svg` - `ieee6/load_curve_168h.csv` - `ieee6/load_curve_summary.csv` - `ieee6/load_curve.svg` - `ieee6/memory_by_mode.svg` - `ieee6/run_metadata.txt` - `ieee6/solve_time_by_mode.svg` - `steady_state_overlap_method.md`

## Key Entry Points

- ieee6/criteria_combination_performance.csv: performance comparison across overlap-criteria combinations.
- ieee6/criteria_combination_intervals.csv: interval-level overlap-window decomposition.
- ieee6/criteria_performance_summary.md: concise IEEE-6 result summary.
- ieee6/detailed_scenario_report.md: detailed scenario report with embedded chart links.
- detailed_comparison_report.md: batch-level comparison report.
- criteria_comparison_all_scenarios.csv: batch-level consolidated comparison table.
- ieee6/input_data_ieee6.xlsx: archived input load/system data used for this run.
- steady_state_overlap_method.md: method description aligned with the current PCM implementation.
