"""
    reorginze_constraints_sets(all_constraints_dict)

Reorganize constraints into separate dictionaries based on their type.

This function categorizes constraints from a dictionary into three groups:

  - Less-than-or-equal constraints (≤)
  - Greater-than-or-equal constraints (≥)
  - Equality constraints (=)

This organization is useful for Benders decomposition and dual extraction,
where different constraint types need to be handled differently.

# Arguments

  - `all_constraints_dict::Dict{Symbol, ConstraintRef}`: Dictionary of all constraints
    with symbolic names as keys

# Returns

  - `all_constr_lessthan_sets::Dict{Symbol, T1}`: Less-than-or-equal constraints
  - `all_constr_greaterthan_sets::Dict{Symbol, T2}`: Greater-than-or-equal constraints
  - `all_constr_equalto_sets::Dict{Symbol, T0}`: Equality constraints

# Types

  - `T0`: Type for equality constraints (MOI.EqualTo)
  - `T1`: Type for less-than constraints (MOI.LessThan)
  - `T2`: Type for greater-than constraints (MOI.GreaterThan)

# Example

```julia
leq_dict, geq_dict, eq_dict = reorginze_constraints_sets(all_constraints)
```

# Note

Constraints that don't match the standard MOI types will trigger a warning
but won't cause an error.
"""
function reorginze_constraints_sets(all_constraints_dict)
    # Initialize dictionaries for each constraint type
    all_constr_lessthan_sets = Dict{Symbol, T1}()
    all_constr_greaterthan_sets = Dict{Symbol, T2}()
    all_constr_equalto_sets = Dict{Symbol, T0}()

    # Categorize constraints based on their type
    for (key, constr) ∈ all_constraints_dict
        constr_type_str = string(typeof(constr))

        if occursin("EqualTo", constr_type_str)
            # Equality constraint: lhs = rhs
            all_constr_equalto_sets[key] = constr
        elseif occursin("LessThan", constr_type_str)
            # Less-than-or-equal constraint: lhs ≤ rhs
            all_constr_lessthan_sets[key] = constr
        elseif occursin("GreaterThan", constr_type_str)
            # Greater-than-or-equal constraint: lhs ≥ rhs
            all_constr_greaterthan_sets[key] = constr
        else
            # Unknown constraint type - log warning
            println("Check this constraint – not a regular MOI type: ", key)
            @info key typeof(constr)
        end
    end

    return all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets
end
