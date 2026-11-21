# Central include point for frequency-security modeling modules.
# - legacy/:       Original 3-feature commitment-sampling affine nadir fitting & reserve constraints.
# - hd_estimation/: Inertia–Damping (H–D) Frequency Security Region (FRSR) physics,
#                   minimum inertia/damping assessment, and pure-MILP linear cut generation.

include("legacy/frequency_config.jl")
include("legacy/frequency_support.jl")
include("legacy/frequency_nadir_response.jl")
include("legacy/frequency_fitting.jl")
include("legacy/frequency_reserve_constraints.jl")

include("hd_estimation/hd_physics.jl")
include("hd_estimation/hd_region_assessment.jl")
include("hd_estimation/hd_linear_cuts.jl")
include("hd_estimation/hd_uc_adapter.jl")
