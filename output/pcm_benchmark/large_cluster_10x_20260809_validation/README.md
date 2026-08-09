# 10x homogeneous-unit PCM benchmark

- Input: `data\data_118_clustered_pcm_10x.xlsx`
- Runs per method: 3
- Horizon: 24 h (1 × 24 h)
- Network constraints: 0

2×15 DataFrame
 Row │ method         successful_runs  median_wall_time_sec  median_allocated_mb  median_peak_rss_mb  physical_units  virtual_units  commitment_integer_variables  cluster_attempts  cluster_successes  cluster_fallbacks  median_total_cost  speedup_vs_standard  integer_variable_reduction  cost_delta_vs_standard
     │ String15       Int64            Float64               Float64              Float64             Int64           Int64          Int64                         Int64             Int64              Int64              Float64            Float64              Float64                     Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ standard                     3              336.005             4.10885e5             5697.69            1080             28                         77760                 0                  0                  0          3.78604e7               1.0                       0.0                   0.0
   2 │ clustered_pcm                3               26.0707         4307.66                  1723.34            1080             28                          2016                 3                  3                  0          3.81179e7              12.8882                    0.974074              0.00680139