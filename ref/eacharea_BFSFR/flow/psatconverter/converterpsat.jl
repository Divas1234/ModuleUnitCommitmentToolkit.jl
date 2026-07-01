using DelimitedFiles

function parse_matpower_matrix(content::String, name::String)
    pattern = Regex("mpc\\." * name * "\\s*=\\s*\\[([\\s\\S]*?)\\];")
    m = match(pattern, content)
    if m === nothing
        error("Matrix $name not found in the file.")
    end

    matrix_str = m.captures[1]
    matrix_str = replace(matrix_str, r"%.*?\n" => "\n") # Remove comments
    matrix_str = strip(matrix_str)

    # Split into rows and then parse numbers
    rows = split(matrix_str, ';')
    matrix = []
    for row_str in rows
        row_str = strip(row_str)
        if !isempty(row_str)
            # Split by whitespace and parse to Float64
            numbers = [parse(Float64, s) for s in split(row_str)]
            push!(matrix, numbers')
        end
    end

    return vcat(matrix...)
end

function convert_matpower_to_psat(input_file::String, output_file::String)
    content = read(input_file, String)

    # --- System Base MVA ---
    mva_match = match(r"mpc\.baseMVA\s*=\s*(\d+);", content)
    base_mva = mva_match !== nothing ? parse(Float64, mva_match.captures[1]) : 100.0

    # --- Parse Data ---
    bus_data = parse_matpower_matrix(content, "bus")
    gen_data = parse_matpower_matrix(content, "gen")
    branch_data = parse_matpower_matrix(content, "branch")

    # --- Open output file for writing ---
    open(output_file, "w") do f
        write(f, "function data = case118_psat\n\n")
        write(f, "% PSAT data file for IEEE 118 bus system\n\n")
        write(f, "Settings.mva = $base_mva;\n")
        write(f, "Settings.freq = 60;\n\n")

        # --- Bus Data ---
        write(f, "Bus.con = [\n")
        # PSAT format: idx, V, ang, P, Q, G, B, type, Vmin, Vmax
        for i in 1:size(bus_data, 1)
            row = bus_data[i, :]
            psat_bus = [
                row[1],  # bus_i
                row[8],  # Vm
                row[9],  # Va
                row[3] / base_mva,  # Pd
                row[4] / base_mva,  # Qd
                row[5] / base_mva,  # Gs
                row[6] / base_mva,  # Bs
                row[2] == 3 ? 1 : row[2],  # type
                row[13], # Vmin
                row[12],  # Vmax
            ]
            writedlm(f, psat_bus', ' ')
        end
        write(f, "];\n\n")

        # --- Generator and Line Processing ---
        slack_bus_idx = bus_data[bus_data[:, 2] .== 3, 1][1]

        pv_gens = []
        slack_gen = []

        for i in 1:size(gen_data, 1)
            if gen_data[i, 8] == 1 # if generator is on
                bus_idx = gen_data[i, 1]
                if bus_idx == slack_bus_idx
                    # SW.con: bus, Vsp, ang, Qmax, Qmin, Pmax, Pmin
                    push!(
                        slack_gen,
                        [
                            bus_idx,
                            gen_data[i, 6],  # Vg
                            bus_data[bus_data[:, 1] .== bus_idx, 9][1], # Va from bus data
                            gen_data[i, 4] / base_mva,  # Qmax
                            gen_data[i, 5] / base_mva,  # Qmin
                            gen_data[i, 9] / base_mva,  # Pmax
                            gen_data[i, 10] / base_mva,  # Pmin
                        ],
                    )
                else
                    bus_type = bus_data[bus_data[:, 1] .== bus_idx, 2][1]
                    if bus_type == 2 # PV bus
                        # PV.con: bus, P, Vsp, Qmax, Qmin, Pmax, Pmin
                        push!(
                            pv_gens,
                            [
                                bus_idx,
                                gen_data[i, 2] / base_mva, # Pg
                                gen_data[i, 6],  # Vg
                                gen_data[i, 4] / base_mva,  # Qmax
                                gen_data[i, 5] / base_mva,  # Qmin
                                gen_data[i, 9] / base_mva,  # Pmax
                                gen_data[i, 10] / base_mva,  # Pmin
                            ],
                        )
                    end
                end
            end
        end

        if !isempty(slack_gen)
            write(f, "SW.con = [\n")
            for row in slack_gen
                writedlm(f, row', ' ')
            end
            write(f, "];\n\n")
        end

        if !isempty(pv_gens)
            write(f, "PV.con = [\n")
            for row in pv_gens
                writedlm(f, row', ' ')
            end
            write(f, "];\n\n")
        end

        # --- Line and Transformer Data ---
        lines = []
        transformers = []
        for i in 1:size(branch_data, 1)
            row = branch_data[i, :]
            if row[11] == 1 # branch is in service
                if row[9] == 0 || row[9] == 1 # It's a line
                    # Line.con: fbus, tbus, r, x, b
                    push!(lines, [row[1], row[2], row[3], row[4], row[5]])
                else # It's a transformer
                    # Trsf.con: fbus, tbus, r, x, ratio, angle
                    push!(transformers, [row[1], row[2], row[3], row[4], row[9], row[10]])
                end
            end
        end

        if !isempty(lines)
            write(f, "Line.con = [\n")
            for row in lines
                writedlm(f, row', ' ')
            end
            write(f, "];\n\n")
        end

        if !isempty(transformers)
            write(f, "Trsf.con = [\n")
            for row in transformers
                writedlm(f, row', ' ')
            end
            write(f, "];\n\n")
        end

        write(f, "data = Bus;\n")
        write(f, "data.SW = SW;\n")
        write(f, "data.PV = PV;\n")
        write(f, "data.Line = Line;\n")
        write(f, "if exist('Trsf', 'var'), data.Trsf = Trsf; end\n\n")

        return write(f, "end\n")
    end
    return println("Conversion complete. Output written to $output_file")
end

# To run the conversion:
convert_matpower_to_psat("case118.m", "case118_psat.m")
