# ============================================================================
# Graph Structure Analyzer for Plasmo OptiGraph
#
# Analyzes 3D tensor graph topology (Space x Time x Scenario) based on
# Cole et al. (2023) "Hierarchical Graph Modeling for Multi-Scale Optimization
# of Power Systems"
# ============================================================================

using Plasmo
using JuMP
using DataFrames

export analyze_optigraph, print_graph_analysis_summary

"""
    analyze_optigraph(graph, nodes, spatial_edges, temporal_edges, scenario_edges, NS, NT, NG, NB)

Analyzes the structural and topological characteristics of the Plasmo OptiGraph.
"""
function analyze_optigraph(
    graph::OptiGraph,
    nodes::Array{OptiNode, 2},
    spatial_edges::Int,
    temporal_edges::Int,
    scenario_edges::Int,
    NS::Int,
    NT::Int,
    NG::Int,
    NB::Int
)
    all_nodes_list = all_nodes(graph)
    num_nodes_cnt = length(all_nodes_list)
    
    # Extract node subproblem variable & constraint counts
    vars_per_node = [num_variables(n) for n in all_nodes_list]
    cons_per_node = [num_constraints(n, count_variable_in_set_constraints=false) for n in all_nodes_list]

    total_vars = sum(vars_per_node)
    total_node_cons = sum(cons_per_node)

    # Link constraints (edges)
    num_link_cons = num_link_constraints(graph)
    total_constraints = total_node_cons + num_link_cons

    # Calculate 3D hyperedge coupling density
    total_couplings = spatial_edges + temporal_edges + scenario_edges
    spatial_pct = round(100 * spatial_edges / max(1, total_couplings), digits=2)
    temporal_pct = round(100 * temporal_edges / max(1, total_couplings), digits=2)
    scenario_pct = round(100 * scenario_edges / max(1, total_couplings), digits=2)

    # Subproblem size metrics
    avg_vars = round(sum(vars_per_node) / max(1, num_nodes_cnt), digits=2)
    avg_cons = round(sum(cons_per_node) / max(1, num_nodes_cnt), digits=2)

    # Matrix sparsity estimation
    full_matrix_size = total_vars * total_constraints
    estimated_coupling_density = round((num_link_cons * 4) / max(1, full_matrix_size) * 100, digits=4)

    return Dict(
        :num_nodes => num_nodes_cnt,
        :num_link_constraints => num_link_cons,
        :total_vars => total_vars,
        :total_node_cons => total_node_cons,
        :total_constraints => total_constraints,
        :spatial_edges => spatial_edges,
        :temporal_edges => temporal_edges,
        :scenario_edges => scenario_edges,
        :spatial_pct => spatial_pct,
        :temporal_pct => temporal_pct,
        :scenario_pct => scenario_pct,
        :avg_vars => avg_vars,
        :avg_cons => avg_cons,
        :coupling_density_pct => estimated_coupling_density,
        :scenario_dim => NS,
        :temporal_dim => NT,
        :generators => NG,
        :buses => NB
    )
end

"""
    print_graph_analysis_summary(metrics)

Prints a formatted terminal summary of the 3D graph structural analysis.
"""
function print_graph_analysis_summary(metrics::Dict)
    println("\n" * "="^80)
    println("      Plasmo.jl 3D OptiGraph Model Analysis (Cole et al. 2023 Ref)")
    println("="^80)

    println("\n1. 3D Tensor Graph Dimensions (Space x Time x Scenario):")
    println("   - Spatial Dimension  (Buses / Generators): $(metrics[:buses]) Buses / $(metrics[:generators]) Thermal Units")
    println("   - Temporal Dimension (Time Horizon NT)   : $(metrics[:temporal_dim]) Hours")
    println("   - Stochastic Dimension (Scenarios NS)    : $(metrics[:scenario_dim]) Scenarios")

    println("\n2. Graph Node & Problem Size Statistics:")
    println("   - Total OptiNodes |V|                    : $(metrics[:num_nodes]) subproblem nodes")
    println("   - Total Decision Variables               : $(metrics[:total_vars]) variables")
    println("   - Local Intra-Node Constraints           : $(metrics[:total_node_cons]) constraints")
    println("   - Inter-Node Link Constraints (OptiEdges): $(metrics[:num_link_constraints]) coupling constraints")
    println("   - Total Problem Constraints              : $(metrics[:total_constraints]) constraints")
    println("   - Avg. Subproblem Size per OptiNode      : $(metrics[:avg_vars]) vars, $(metrics[:avg_cons]) cons")

    println("\n3. Three-Dimensional Coupling Breakdown (OptiEdges):")
    println("   - Spatial Couplings  (E_S - Balance/Flow): $(metrics[:spatial_edges]) ($(metrics[:spatial_pct])%)")
    println("   - Temporal Couplings (E_T - Ramp/Storage): $(metrics[:temporal_edges]) ($(metrics[:temporal_pct])%)")
    println("   - Scenario Couplings (E_Ω - Non-Anticip.): $(metrics[:scenario_edges]) ($(metrics[:scenario_pct])%)")
    println("   - Overall Inter-Node Coupling Sparsity   : $(metrics[:coupling_density_pct])%")

    println("\n4. Multi-Scale Algorithmic Decomposition Recommendations:")
    println("   - [Scenario Partitioning (Benders / Progressive Hedging)]:")
    println("     Coupling is concentrated in $(metrics[:scenario_edges]) Non-Anticipativity links.")
    println("     Decomposing across scenarios yields $(metrics[:scenario_dim]) independent $(metrics[:temporal_dim])-hour deterministic subproblems.")
    println("   - [Temporal Partitioning (Dynamic Programming / Dantzig-Wolfe)]:")
    println("     Coupling consists of $(metrics[:temporal_edges]) Ramping & Storage SOC constraints between adjacent hours t-1 -> t.")
    println("   - [Spatial Partitioning (ADMM / Network Tearing)]:")
    println("     Coupling consists of $(metrics[:spatial_edges]) Power balance & Transmission line capacity constraints.")
    println("="^80 * "\n")
end
