function check_var_exists(model::Model, name::String)
	return haskey(JuMP.object_dictionary(model), Symbol(name))
end
