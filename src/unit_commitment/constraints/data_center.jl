"""
	add_data_center_constraints!(scuc, NT, NS, config_param, ND2, data_centers)

Add data-center flexible-load constraints. The detailed response model lives in
`unit_commitment/data_centers`; this file is kept as the stable constraint entry
point used by benchmark UC, Benders, and CCG.
"""
function add_data_center_constraints!(scuc::Model, NT, NS, config_param, ND2 = nothing, data_centers = nothing)
    if isnothing(ND2) || ND2 <= 0 || data_centers === nothing
        println("\t constraints: 12) data center constraints skipped (ND2=0 or data missing)")
        return nothing
    end
    if config_param.consider_data_center != 1
        println("\t constraints: 12) data center constraints skipped (consider_data_center != 1)")
        return nothing
    end
    return add_data_center_response_constraints!(scuc, data_centers, config_param, Int(NS), Int(NT), Int(ND2))
end

# Backward-compatible alias for legacy callers
const add_datacentra_constraints! = add_data_center_constraints!
