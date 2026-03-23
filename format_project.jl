using Pkg
Pkg.add("JuliaFormatter")
using JuliaFormatter

# Format the entire project directory
println("Formatting the project...")
format("."; verbose = true)
println("Formatting complete!")
