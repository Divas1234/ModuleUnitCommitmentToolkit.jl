"""
    ModuleUnitCommitmentToolkit

Industrial-grade Julia package for Security-Constrained Unit Commitment (SCUC),
Stochastic / Distributionally Robust UC (Wasserstein DRO-CCG), Strengthened
Multi-Cut Benders Decomposition, and 2×2 Production Cost Modeling (PCM).
(工业级安全约束机组组合工具包：覆盖扩展型基准、强化多割 Benders、Wasserstein DRO-CCG 与 2×2 生产成本模拟。)

Module Load & Dependency Architecture (模块加载与依赖架构):
  core/{environment,runtime,optimizer,api_types,reporting}
      │
      ├──► renewables/stochastic_simulation.jl        (风电场景生成)
      ├──► input_data/readers.jl                      (Excel / PowerSystems 数据适配)
      ├──► unit_commitment/scuc_model.jl              (约束库: 机组/网络/储能/数据中心/H-D 频率域)
      ├──► production_cost/entry.jl                   (2×2 PCM: 单机/聚类 × 固定/自适应交叠)
      ├──► algorithms/entry.jl                        (Benchmark / 强化 Benders / DRO-CCG)
      └──► core/{solver_interface,execution_diagnostics,deprecations}.jl  (统一 solve_uc 入口)
"""
module ModuleUnitCommitmentToolkit

# Core infrastructure: environment, runtime config, optimizer, API types, reporting
include("core/environment_config.jl")
include("core/runtime_config.jl")
include("core/optimizer_config.jl")
include("core/api_types.jl")
include("core/output_reporting.jl")

# Renewable simulation
include("renewables/stochastic_simulation.jl")

# Input data loaders and bridges
include("input_data/readers.jl")

# Unit commitment models and constraints
include("unit_commitment/scuc_model.jl")

# Production Cost Modeling (PCM) core library (2x2 orthogonal matrix + Benchmark)
include("production_cost/entry.jl")
using .ClusteredDisaggregation

# Precompiled core UC algorithms (Benders, C&CG, Extensive-Form Benchmark)
include("algorithms/entry.jl")

# Unified data/algorithm orchestration entry point.
include("core/solver_interface.jl")
include("core/execution_diagnostics.jl")
include("core/deprecations.jl")

# Public package-level entry points (canonical BlueStyle names + legacy aliases).
export solve_scuc_model,
    SUC_scucmodel,
    validate_inputs,
    read_excel_sheets,
    format_uc_input_data,
    linearize_fuel_cost_curve,
    build_benders_master,
    build_benders_subproblem,
    check_benders_convergence,
    save_uc_results,
    read_uc_results,
    save_power_balance_result,
    plot_unicode_profiles,
    readxlssheet,
    forminputdata,
    genscenario,
    save_details_scheduled_results,
    load_uc_data,
    config_from_env,
    load_runtime_config!,
    runtime_config_entries,
    uc_env_bool,
    uc_env_int,
    uc_env_float,
    uc_load_curtailment_penalty,
    uc_wind_curtailment_penalty,
    known_uc_calibration_keys,
    default_uc_optimizer,
    set_default_uc_optimizer!,
    with_uc_optimizer,
    SolverOptions,
    current_solver_options,
    with_solver_options,
    solver_options_from_env,
    apply_solver_options!,
    build_uc_model,
    device_net_injection,
    extract_uc_hd_parameters_by_area,
    add_multi_area_hd_frequency_constraints!,
    uc_has_feasible_solution,
    uc_require_feasible_solution!,
    UCConfig,
    ThermalUnits,
    TransmissionLines,
    Loads,
    StorageUnits,
    DataCenters,
    WindUnits,
    UCInputSpec,
    UCProblemData,
    AbstractUCAlgorithm,
    BenchmarkUCAlgorithm,
    BendersAlgorithm,
    CCGAlgorithm,
    PCMAlgorithm,
    PCMRunStats,
    UCSolveRequest,
    UCSolveResult,
    UCScheduleResult,
    BendersSetup,
    build_benders_setup,
    multiple_benders_decomposition_scuc,
    solve_ccg_unit_commitment,
    solve_benchmark_uc,
    solve_benchmark_uc_powersystems,
    process_memory_mb,
    print_uc_result,
    solve_uc,
    UCExampleOptions,
    parse_example_run_args,
    resolve_uc_example_options,
    print_example_run_usage,
    run_uc_example_workflow,
    uc_variable,
    has_uc_variable,
    LEGACY_NAMING_MIGRATION,
    ClusteredDisaggregation,
    ClusterSpec,
    InitialUnitState,
    PhysicalUnitData,
    NetworkData,
    ClusterSchedule,
    AnonymousUnitPath,
    TrajectoryCheckResult,
    DisaggregationFeedback,
    UnitDisaggregationResult,
    check_cluster_trajectory_feasibility,
    decompose_state_flow_to_paths,
    assign_paths_to_physical_units,
    solve_unit_disaggregation,
    run_cluster_disaggregation,
    validate_disaggregation,
    AbstractPCMFormulation,
    SingleUnitFormulation,
    ClusteredFormulation,
    AbstractPCMHorizonPolicy,
    FixedHorizonPolicy,
    AdaptiveOverlapPolicy,
    PCMConfig,
    PCM_MATRIX_METHODS,
    pcm_method_spec,
    apply_pcm_load_profile!,
    load_pcm_excel_data,
    run_pcm,
    run_pcm_benchmark,
    compare_pcm_methods,
    HDFrequencyParameters,
    HDFrequencyRegionResult,
    HDLinearCutSet,
    hd_rocof_min_inertia,
    hd_rocof_min_inertia_axis,
    hd_qss_min_damping,
    hd_nadir_threshold_pu,
    hd_sfr_damping_parameters,
    hd_sfr_underdamped_window,
    hd_sfr_nadir_time,
    hd_sfr_nadir_pu,
    hd_effective_nadir_pu,
    hd_fit_quadratic_boundary,
    assess_hd_frequency_region,
    hd_region_summary_dataframe,
    build_hd_linear_cuts,
    hd_cuts_dataframe,
    extract_uc_hd_parameters,
    add_hd_frequency_constraints!,
    evaluate_uc_hd_trajectory,
    plot_hd_time_varying_region,
    export_hd_frequency_analysis,
    frequency_model_mode

end
