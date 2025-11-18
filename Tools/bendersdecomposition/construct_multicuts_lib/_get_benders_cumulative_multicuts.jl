"""
	get_benders_cumulative_multicuts_expression(scuc_masterproblem, final_dual_subproblem_coefficient_results, NG, NT, NW, ND, NL)

Construct cumulative Benders multicuts expression by aggregating dual coefficients from subproblems.

# Arguments

  - `scuc_masterproblem::JuMP.Model`: The master problem model
  - `final_dual_subproblem_coefficient_results::Dict{Symbol, dual_subprob_expr_coefficient}`: Dictionary mapping variable names to their dual coefficients
  - `NG::Int64`: Number of generators
  - `NT::Int64`: Number of time periods
  - `NW::Int64`: Number of wind units
  - `ND::Int64`: Number of demand nodes
  - `NL::Int64`: Number of transmission lines

# Returns

  - `scuc_masterproblem::JuMP.Model`: Updated master problem model
  - `benders_cut::AffExpr`: The cumulative Benders cut expression
"""
function get_benders_cumulative_multicuts_expression(
		scuc_masterproblem::JuMP.Model,
		final_dual_subproblem_coefficient_results::Dict{Symbol, dual_subprob_expr_coefficient},
		NG::Int64,
		NT::Int64,
		NW::Int64,
		ND::Int64,
		NL::Int64
)
	benders_cut = AffExpr(0)

	for (keys_name, coeff) in final_dual_subproblem_coefficient_results
		# println(keys_name)
		scuc_masterproblem, dual_expression_cut = get_benders_multicuts_expression(
			scuc_masterproblem, coeff, keys_name, NG, NT, NW, ND, NL
		)
		benders_cut += dual_expression_cut
	end
	return scuc_masterproblem, benders_cut
end
