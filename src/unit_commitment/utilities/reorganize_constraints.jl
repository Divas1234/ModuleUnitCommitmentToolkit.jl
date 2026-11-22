
function reorginze_constraints_sets(all_constraints_dict)
    all_constr_lessthan_sets = Dict{Symbol, T1}()
    all_constr_greaterthan_sets = Dict{Symbol, T2}()
    all_constr_equalto_sets = Dict{Symbol, T0}()

    for (key, constr) in all_constraints_dict
        if constr isa T0
            all_constr_equalto_sets[key] = constr
        elseif constr isa T1
            all_constr_lessthan_sets[key] = constr
        elseif constr isa T2
            all_constr_greaterthan_sets[key] = constr
        else
            println("Check this constraint – not a regular MOI type: ", key)
            @info key typeof(constr)
        end
    end

    return all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets
end
