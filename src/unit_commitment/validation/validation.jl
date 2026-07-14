include("validate_inputs.jl")
include("check_variable_exists.jl")
include("check_mip_problem.jl")
include("moi_constraint_ref_types.jl")

export validate_inputs, check_var_exists, is_mixed_integer_problem

println("\t\u2192 all boundary conditions validated.")
