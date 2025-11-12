"""
    convert_constraints_type_to_vector(x)

Convert constraint reference to a proper vector type if needed.

This utility function ensures that constraint references are in the correct
vector format for further processing. It handles the case where constraints
might be stored as Vector{Any} and converts them to a proper vector type.

# Arguments
- `x`: Input that may be a vector or other type

# Returns
- Vector of constraints in proper format

# Example
```julia
constraints = convert_constraints_type_to_vector(constraint_refs)
```
"""
function convert_constraints_type_to_vector(x)
    if typeof(x) <: AbstractVector
        if isa(x, Vector{Any})
            x = vec(x)  # Convert to proper vector type
        end
    end
    return x
end

"""
    check_constrainsref_type(x)

Check if constraint reference is in the correct type format.

This function validates that constraint references are in Vector{Any} format,
which may need to be converted to Vector{ConstraintRef} for proper handling.

# Arguments
- `x`: Constraint reference to check

# Example
```julia
check_constrainsref_type(constraint_refs)
```
"""
function check_constrainsref_type(x)
    if !(typeof(x) <: AbstractVector && isa(x, Vector{Any}))
        println(
            "This is a Vector{Any} of constraints and needs to be converted to Vector{ConstraintRef}",
        )
    end
end
