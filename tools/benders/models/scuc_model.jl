using JuMP

"""
`SCUCModel_decision_variables`

A comprehensive container for all JuMP decision variables used in the Unit Commitment
optimization. This structure encapsulates both first-stage (commitment) and
second-stage (dispatch/recourse) variables.
"""
mutable struct SCUCModel_decision_variables{T <: VariableRef}
    # --- Commitment & Unit Status ---
    x::Matrix{T}                # Startup indicator binary variables (NG x NT)
    u::Matrix{T}                # Commitment status binary variables (NG x NT)
    v::Matrix{T}                # Shutdown indicator binary variables (NG x NT)
    su₀::Matrix{T}              # Startup cost linearization auxiliary variables
    sd₀::Matrix{T}              # Shutdown cost linearization auxiliary variables

    # --- Generation & Reserves ---
    pg₀::Matrix{T}              # Base active power generation (NG x NT)
    pgₖ::Array{T, 3}            # Piecewise linear generation segments (NG x Segments x NT)
    sr⁺::Matrix{T}              # Upward spinning reserve (NG x NT)
    sr⁻::Matrix{T}              # Downward spinning reserve (NG x NT)

    # --- Resource Adequacy & Curtailment ---
    Δpd::Matrix{T}              # Load shedding / demand curtailment variables
    Δpw::Matrix{T}              # Wind generation curtailment variables

    # --- Network Flow & Slack ---
    κ⁺::Matrix{T}               # Nodal power balance positive slack
    κ⁻::Matrix{T}               # Nodal power balance negative slack

    # --- Energy Storage Systems (BESS/PSS) ---
    pc⁺::Matrix{T}              # Storage charging power
    pc⁻::Matrix{T}              # Storage discharging power
    qc::Matrix{T}               # Storage energy state of charge (SoC)
    pss_sumchargeenergy::Matrix{T} # Cumulative energy charged over horizon

    # --- IT/Data Center Flexible Loads ---
    α::Matrix{T}                # Auxiliary binary flags for flexible resource logic
    β::Matrix{T}                # Auxiliary binary flags for flexible resource logic

    # --- Benders Interface ---
    θ::Any                      # Recourse cost approximation variable (theta)

    function SCUCModel_decision_variables(
        x::Matrix{T},
        u::Matrix{T},
        v::Matrix{T},
        su₀::Matrix{T},
        sd₀::Matrix{T},
        pg₀::Matrix{T},
        pgₖ::Array{T, 3},
        sr⁺::Matrix{T},
        sr⁻::Matrix{T},
        Δpd::Matrix{T},
        Δpw::Matrix{T},
        κ⁺::Matrix{T},
        κ⁻::Matrix{T},
        pc⁺::Matrix{T},
        pc⁻::Matrix{T},
        qc::Matrix{T},
        pss_sumchargeenergy::Matrix{T},
        α::Matrix{T},
        β::Matrix{T},
        θ::Any,
    ) where {T <: VariableRef}
        return new{T}(x, u, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β, θ)
    end
end

"""
`build_decision_variables(; kwargs...)`

Constructs an SCUCModel_decision_variables object with the provided variables.
Initializes empty matrices/arrays for any fields not explicitly provided.
"""
function build_decision_variables(; kwargs...)
    fields = fieldnames(SCUCModel_decision_variables)
    defaults = Dict{Symbol, Any}()

    # Initialize default empty containers for each field
    for f in fields
        if f == :pgₖ
            defaults[f] = Array{VariableRef, 3}(undef, 0, 0, 0)
        elseif f == :θ
            defaults[f] = nothing
        else
            defaults[f] = Matrix{VariableRef}(undef, 0, 0)
        end
    end

    # Override defaults with user-provided values
    for (k, v) in kwargs
        if haskey(defaults, k)
            defaults[k] = v
        else
            error("Invalid field name: $k. Valid fields are: $(join(string.(fields), ", "))")
        end
    end

    # Construct and return the struct
    return SCUCModel_decision_variables(
        defaults[:x],
        defaults[:u],
        defaults[:v],
        defaults[:su₀],
        defaults[:sd₀],
        defaults[:pg₀],
        defaults[:pgₖ],
        defaults[:sr⁺],
        defaults[:sr⁻],
        defaults[:Δpd],
        defaults[:Δpw],
        defaults[:κ⁺],
        defaults[:κ⁻],
        defaults[:pc⁺],
        defaults[:pc⁻],
        defaults[:qc],
        defaults[:pss_sumchargeenergy],
        defaults[:α],
        defaults[:β],
        defaults[:θ],
    )
end

"""
`SCUCModel_constraints`

Structure containing all constraints for the SCUC model, organized by constraint type.
Each field is a vector of JuMP ConstraintRef objects.
"""
mutable struct SCUCModel_constraints # Constraints for SCUC model
    units_minuptime_constr::Vector{ConstraintRef}                    # Minimum up time constraints
    units_mindowntime_constr::Vector{ConstraintRef}                  # Minimum down time constraints
    units_init_stateslogic_consist_constr::Vector{ConstraintRef}     # Initial state logic consistency
    units_states_consist_constr::Vector{ConstraintRef}               # State consistency constraints
    units_init_shutup_cost_constr::Vector{ConstraintRef}             # Initial startup cost constraints
    units_init_shutdown_cost_constr::Vector{ConstraintRef}           # Initial shutdown cost constraints
    units_shutup_cost_constr::Vector{ConstraintRef}                  # Startup cost constraints
    units_shutdown_cost_constr::Vector{ConstraintRef}                # Shutdown cost constraints
    winds_curt_constr::Vector{ConstraintRef}                         # Wind curtailment constraints
    loads_curt_constr::Vector{ConstraintRef}                         # Load curtailment constraints
    units_minpower_constr::Vector{ConstraintRef}                     # Minimum power output constraints
    units_maxpower_constr::Vector{ConstraintRef}                     # Maximum power output constraints
    sys_upreserve_constr::Vector{ConstraintRef}                      # System upward reserve constraints
    sys_down_reserve_constr::Vector{ConstraintRef}                   # System downward reserve constraints
    units_upramp_constr::Vector{ConstraintRef}                       # Upward ramping constraints
    units_downramp_constr::Vector{ConstraintRef}                     # Downward ramping constraints
    units_pwlpower_sum_constr::Vector{ConstraintRef}                 # Piecewise linear power sum constraints
    units_pwlblock_upbound_constr::Vector{ConstraintRef}             # Upper bounds for piecewise blocks
    units_pwlblock_dwbound_constr::Vector{ConstraintRef}             # Lower bounds for piecewise blocks
    balance_constr::Vector{ConstraintRef}                            # Power balance constraints
    transmissionline_powerflow_upbound_constr::Vector{ConstraintRef} # Transmission line upper limits
    transmissionline_powerflow_downbound_constr::Vector{ConstraintRef} # Transmission line lower limits
end

"""
`build_constraints(; kwargs...)`

Constructs an SCUCModel_constraints object with the provided constraint vectors.
Initializes empty vectors for any constraint types not explicitly provided.
"""
function build_constraints(; kwargs...)
    fields = fieldnames(SCUCModel_constraints)
    defaults = Dict{Symbol, Vector{ConstraintRef}}()

    # Initialize empty constraint vectors for each field
    for f in fields
        defaults[f] = ConstraintRef[]
    end

    # Override defaults with user-provided values
    for (k, v) in kwargs
        if haskey(defaults, k)
            defaults[k] = v
        else
            error("Invalid field name: $k. Valid fields are: $(join(string.(fields), ", "))")
        end
    end

    # Construct and return the struct
    return SCUCModel_constraints(
        defaults[:units_minuptime_constr],
        defaults[:units_mindowntime_constr],
        defaults[:units_init_stateslogic_consist_constr],
        defaults[:units_states_consist_constr],
        defaults[:units_init_shutup_cost_constr],
        defaults[:units_init_shutdown_cost_constr],
        defaults[:units_shutup_cost_constr],
        defaults[:units_shutdown_cost_constr],
        defaults[:winds_curt_constr],
        defaults[:loads_curt_constr],
        defaults[:units_minpower_constr],
        defaults[:units_maxpower_constr],
        defaults[:sys_upreserve_constr],
        defaults[:sys_down_reserve_constr],
        defaults[:units_upramp_constr],
        defaults[:units_downramp_constr],
        defaults[:units_pwlpower_sum_constr],
        defaults[:units_pwlblock_upbound_constr],
        defaults[:units_pwlblock_dwbound_constr],
        defaults[:balance_constr],
        defaults[:transmissionline_powerflow_upbound_constr],
        defaults[:transmissionline_powerflow_downbound_constr],
    )
end

"""
`SCUCModel_reformat_constraints`

Structure for organizing constraints by their mathematical form (equality, inequality).
"""
mutable struct SCUCModel_reformat_constraints
    _equal_to::Dict{Symbol, Any}          # Equality constraints (a = b)
    _greater_than::Dict{Symbol, Any}      # Greater-than constraints (a ≥ b)
    _smaller_than::Dict{Symbol, Any}      # Less-than constraints (a ≤ b)
end

"""
`SCUCModel_objective_function`

Structure containing the objective function for the SCUC model.
"""
mutable struct SCUCModel_objective_function
    objective_function::Union{Missing, AffExpr}  # Objective function expression
end

"""
`SCUC_Model`

Root structure for the Unit Commitment optimization. It houses the underlying JuMP
model and provides structured access to variables, objective, and constraints.
"""
mutable struct SCUC_Model
    model::Union{Missing, JuMP.Model}                       # Reference to the JuMP optimization model
    decision_variables::SCUCModel_decision_variables        # Structured container for variables
    objective_function::SCUCModel_objective_function        # Reference to objective expression
    constraints::SCUCModel_constraints                      # Grouped constraints by physical meaning
    reformated_constraints::SCUCModel_reformat_constraints  # Grouped constraints by mathematical form
end

"""
`dual_subprob_expr_coefficient`

Data structure for storing sensitivity analysis coefficients (duals and multipliers)
derived from subproblem constraints. These are used to synthesize Benders feasibility
and optimality cuts.
"""
mutable struct dual_subprob_expr_coefficient
    rhs::Vector{Float64}                     # Right-hand side values of the subproblem constraints
    x::Union{Vector{Float64}, Nothing}        # Dual coefficients associated with commitment (x)
    u::Union{Vector{Float64}, Nothing}        # Dual coefficients associated with startup (u)
    v::Union{Vector{Float64}, Nothing}        # Dual coefficients associated with shutdown (v)
    x_sort_order::Union{Int64, Nothing}       # Index mapping for x variable alignment
    u_sort_order::Union{Int64, Nothing}       # Index mapping for u variable alignment
    v_sort_order::Union{Int64, Nothing}       # Index mapping for v variable alignment
    x_alignment_flag::Union{Int64, Nothing}    # Dimensionality check flag for x
    u_alignment_flag::Union{Int64, Nothing}    # Dimensionality check flag for u
    v_alignment_flag::Union{Int64, Nothing}    # Dimensionality check flag for v
    dual_coeffVector::Vector{Float64}         # Aggregated dual vector (pi/lambda)
    operator_associativity::Vector{Float64}   # Sign mapping (+1 for >=, -1 for <=)
end

"""
`build_dual_cuts_expr_coefficient(; kwargs...)`

Constructs a dual_subprob_expr_coefficient object with provided values and defaults.
"""
function build_dual_cuts_expr_coefficient(; kwargs...)
    fields = fieldnames(dual_subprob_expr_coefficient)

    defaults = Dict{Symbol, Any}(
        :rhs => Float64[],
        :x => nothing,
        :u => nothing,
        :v => nothing,
        :x_sort_order => nothing,
        :u_sort_order => nothing,
        :v_sort_order => nothing,
        :x_alignment_flag => nothing,
        :u_alignment_flag => nothing,
        :v_alignment_flag => nothing,
        :dual_coeffVector => Float64[],
        :operator_associativity => Float64[],
    )

    for (k, v) in kwargs
        if haskey(defaults, k)
            defaults[k] = v
        else
            error("Invalid field name: $k. Valid fields are: $(join(string.(fields), ", "))")
        end
    end

    return dual_subprob_expr_coefficient(
        defaults[:rhs],
        defaults[:x],
        defaults[:u],
        defaults[:v],
        defaults[:x_sort_order],
        defaults[:u_sort_order],
        defaults[:v_sort_order],
        defaults[:x_alignment_flag],
        defaults[:u_alignment_flag],
        defaults[:v_alignment_flag],
        defaults[:dual_coeffVector],
        defaults[:operator_associativity],
    )
end
