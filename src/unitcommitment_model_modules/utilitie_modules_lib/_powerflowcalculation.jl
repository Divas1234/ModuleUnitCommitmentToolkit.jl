"""
    linearpowerflow(units, lines, loads, NG, NB, ND, NL)

Calculate linearized DC power flow matrices for transmission network analysis.

This function computes the generation shift distribution factors (GSDF) and
bus-to-generator/load mapping matrices using DC power flow approximation.
The DC approximation assumes:

  - Line resistances are negligible (only reactance considered)
  - Voltage magnitudes are constant
  - Small angle approximation (sin(θ) ≈ θ)

# Arguments

  - `units::unit`: Generator unit data with `locatebus` field
  - `lines::transmissionline`: Transmission line data with:
      + `from`: From bus indices
      + `to`: To bus indices
      + `x`: Line reactance (p.u.)
  - `loads::load`: Load data with `locatebus` field
  - `NG::Int`: Number of generators
  - `NB::Int`: Number of buses
  - `ND::Int`: Number of loads
  - `NL::Int`: Number of transmission lines

# Returns

  - `G2B::Matrix{Float64}`: Generator-to-bus incidence matrix (NB × NG)
  - `D2B::Matrix{Float64}`: Load-to-bus incidence matrix (NB × ND)
  - `Gsdf::Matrix{Float64}`: Generation shift distribution factors (NL × NB)
      + Gsdf[l, b] represents the power flow on line l when 1 MW is injected at bus b

# Algorithm

 1. Build bus admittance matrix B from line reactances
 2. Build branch-to-bus incidence matrix M
 3. Remove slack bus (bus 1) to make B invertible
 4. Calculate Gsdf using: Gsdf = M' * inv(B) / x
"""
function linearpowerflow(units::unit, lines::transmissionline, loads::load, NG::Int64, NB::Int64, ND::Int64, NL::Int64)
    # ========================================================================
    # Step 1: Build bus admittance matrix B
    # ========================================================================
    B = zeros(NB, NB)
    M = zeros(NB, NL)

    # Build branch-to-bus incidence matrix M and admittance matrix B
    for k ∈ 1:NL
        n1 = lines.from[k, 1]  # From bus
        n2 = lines.to[k, 1]     # To bus

        # Incidence matrix: +1 for from bus, -1 for to bus
        M[n1, k] = 1
        M[n2, k] = -1

        # Line admittance (inverse of reactance)
        n5 = 1.0 / lines.x[k, 1]

        # Update admittance matrix (Y-bus formation)
        B[n1, n1] = B[n1, n1] + n5  # Self-admittance
        B[n2, n2] = B[n2, n2] + n5
        B[n1, n2] = B[n1, n2] - n5  # Mutual admittance
        B[n2, n1] = B[n2, n1] - n5
    end

    # ========================================================================
    # Step 2: Build generator-to-bus and load-to-bus mapping matrices
    # ========================================================================
    G2B = zeros(NB, NG)  # Generator-to-bus: 1 if generator g is at bus b
    D2B = zeros(NB, ND)  # Load-to-bus: 1 if load d is at bus b

    for i ∈ 1:NG
        G2B[units.locatebus[i, 1], i] = 1
    end
    for i ∈ 1:ND
        D2B[loads.locatebus[i, 1], i] = 1
    end

    # ========================================================================
    # Step 3: Remove slack bus to make B matrix invertible
    # ========================================================================
    Note_slack = 1  # Slack bus index (typically bus 1)

    # Build reduced admittance matrix (excluding slack bus)
    B1 = zeros(NB - 1, NB - 1)
    if Note_slack == 1
        # Remove first row and column (slack bus)
        B1[1:(NB - 1), :] = B[2:NB, 2:NB]
    else
        # General case: remove slack bus at arbitrary position
        B1[1:(Note_slack - 1), 1:(Note_slack - 1)] = B[1:(Note_slack - 1), 1:(Note_slack - 1)]
        B1[Note_slack:(NB - 1), 1:(Note_slack - 1)] = B[Note_slack:NB, 1:(Note_slack - 1)]
        B1[1:(Note_slack - 1), (Note_slack - 1):(NB - 1)] = B[1:(Note_slack - 1), Note_slack:NB]
        B1[(Note_slack - 1):(NB - 1), (Note_slack - 1):(NB - 1)] = B[Note_slack:NB, Note_slack:NB]
    end

    # ========================================================================
    # Step 4: Calculate generation shift distribution factors (GSDF)
    # ========================================================================
    # GSDF formula: Gsdf = M' * inv(B) / x
    # This gives power flow on each line per unit injection at each bus

    Z = inv(B1)  # Inverse of reduced admittance matrix

    # Remove slack bus row from incidence matrix
    M1 = M[1:NB .!= Note_slack, :]

    # Calculate T1 = M' * inv(B1) / x
    T1 = M1' / B1
    for k ∈ 1:(NB - 1)
        T1[:, k] = T1[:, k] ./ lines.x
    end

    # ========================================================================
    # Step 5: Map GSDF back to full bus set (including slack bus)
    # ========================================================================
    Gsdf = zeros(NL, NB)
    if Note_slack == 1
        # Slack bus is first bus, so shift columns
        Gsdf[:, (Note_slack + 1):NB] = T1[:, Note_slack:(NB - 1)]
    else
        # General case: insert slack bus column
        Gsdf[:, 1:(Note_slack - 1)] = T1[:, 1:(Note_slack - 1)]
        Gsdf[:, (Note_slack + 1):NB] = T1[:, Note_slack:(NB - 1)]
    end

    return G2B, D2B, Gsdf
end
