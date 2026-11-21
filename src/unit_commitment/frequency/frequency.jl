# Central include point for frequency-security modeling modules.
# - affine_fitting/: 3-feature commitment-sampling affine nadir fitting & reserve constraints.
# - hd_estimation/:  Inertia–Damping (H–D) Frequency Security Region (FRSR) physics,
#                    minimum inertia/damping assessment, and pure-MILP linear cut generation.

include("affine_fitting/frequency_config.jl")
include("affine_fitting/frequency_support.jl")
include("affine_fitting/frequency_nadir_response.jl")
include("affine_fitting/frequency_fitting.jl")
include("affine_fitting/frequency_reserve_constraints.jl")

include("hd_estimation/hd_physics.jl")
include("hd_estimation/hd_region_assessment.jl")
include("hd_estimation/hd_linear_cuts.jl")
include("hd_estimation/hd_uc_adapter.jl")
