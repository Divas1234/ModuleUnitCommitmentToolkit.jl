# Central include point for frequency-security modeling modules.
# - affine_fitting/: 3-feature commitment-sampling affine nadir fitting & QSS/FCR reserve constraints.
# - hd_estimation/:  Inertia–Damping (H–D) Frequency Security Region (FRSR) physics,
#                    minimum inertia/damping assessment, and pure-MILP linear cut generation.

include("affine_fitting/sfr_config.jl")
include("affine_fitting/inertia_droop_support.jl")
include("affine_fitting/nadir_sampling.jl")
include("affine_fitting/piecewise_affine_fit.jl")
include("affine_fitting/qss_fcr_constraints.jl")

include("hd_estimation/hd_physics.jl")
include("hd_estimation/hd_region_assessment.jl")
include("hd_estimation/hd_linear_cuts.jl")
include("hd_estimation/hd_uc_adapter.jl")
