include("formatted_data.jl")
include("excel_reader.jl")
include("boundary_checks.jl")

export readxlssheet, forminputdata, boundrycondition, boundarycondition, boundary_condition, maybe_print_boundarycondition

println("\t\u2192 inputdata was written and reformatted for UC modeling.")
