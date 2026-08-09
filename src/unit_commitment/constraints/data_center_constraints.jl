"""
    add_datacentra_constraints!(scuc, NT, NS, config_param, ND2, DataCentras)

Add data-center flexible-load constraints. The detailed response model lives in
`unit_commitment/data_centers`; this file is kept as the stable constraint entry
point used by benchmark UC, Benders, and CCG.
"""
function add_datacentra_constraints!(scuc::Model, NT, NS, config_param, ND2 = nothing, DataCentras = nothing)
    if isnothing(ND2) || ND2 <= 0 || DataCentras === nothing
        println("\t constraints: 12) data centra constraints skipped (ND2=0 or data missing)")
        return nothing
    end
    if config_param.is_ConsiderDataCentra != 1
        println("\t constraints: 12) data centra constraints skipped (is_ConsiderDataCentra != 1)")
        return nothing
    end
    return add_data_center_response_constraints!(scuc, DataCentras, config_param, Int(NS), Int(NT), Int(ND2))
end
