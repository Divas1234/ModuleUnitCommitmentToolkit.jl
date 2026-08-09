using XLSX

"""
    readxlssheet()

Read input data from Excel file.

This function reads all required input data from the Excel file located in the
`data/` directory. It handles different operating systems and constructs the
appropriate file path.

# Returns

A tuple containing:

  - `unitsfreqparam`: Generator frequency parameters
  - `windsfreqparam`: Wind frequency parameters
  - `strogesystemdata`: Energy storage system data
  - `gendata`: Generator unit data
  - `gencost`: Generator cost data
  - `linedata`: Transmission line data
  - `loadcurve`: Load curve data
  - `loaddata`: Load data
  - `data_centra_data`: Data center data
  - `hydropower_data`: Hydroelectric power data
  - `hydropower_curve`: Hydroelectric seasonal curve data

# Throws

  - `SystemError` if the Excel file cannot be found or read
"""
function readxlssheet()
    println("Step-1: Loading packages and functions...")

    # Construct data file path relative to project root.
    # MODULE_UC_DATA_FILE remains the explicit override; otherwise default to the
    # 118-bus case used by the PCM scripts in this repository.
    project_root = dirname(dirname(@__DIR__))  # Go up from src/read_inputdata_modules/
    data_file = if haskey(ENV, "PCM_INPUT_XLSX")
        ENV["PCM_INPUT_XLSX"]
    elseif haskey(ENV, "MODULE_UC_DATA_FILE")
        ENV["MODULE_UC_DATA_FILE"]
    else
        candidates = [joinpath(project_root, "data", "data_118.xlsx"), joinpath(project_root, "data", "data.xlsx"),
            joinpath(pwd(), "data", "data_118.xlsx"), joinpath(pwd(), "data", "data.xlsx")]
        found_idx = findfirst(isfile, candidates)
        found_idx === nothing ? candidates[1] : candidates[found_idx]
    end

    # Check if file exists
    if !isfile(data_file)
        error("Cannot find data file at: $data_file\nPlease ensure the data file exists.")
    end

    println("  Reading data from: $data_file")
    df = XLSX.readxlsx(data_file)

    # ========================================================================
    # Part 1: Read frequency parameter data
    # ========================================================================
    println("  Reading frequency parameters...")
    unitsfreqparam = df["units_frequencyparam"]
    windsfreqparam = df["winds_frequencyparam"]

    # Extract data ranges (skip header row)
    unitsfreqparam_range = "A2:G$(size(unitsfreqparam[:], 1))"
    windsfreqparam_range = "A2:F$(size(windsfreqparam[:], 1))"

    unitsfreqparam = convert(Array{Float64, 2}, unitsfreqparam[unitsfreqparam_range])
    windsfreqparam = convert(Array{Float64, 2}, windsfreqparam[windsfreqparam_range])

    # ========================================================================
    # Part 2: Read energy storage system data
    # ========================================================================
    println("  Reading energy storage system data...")
    strogesystemdata = df["strogesystem_data"]
    strogesystemdata_range = "A2:L$(size(strogesystemdata[:], 1))"
    strogesystemdata = convert(Array{Float64, 2}, strogesystemdata[strogesystemdata_range])

    # ========================================================================
    # Part 3: Read conventional generator, network, and load data
    # ========================================================================
    println("  Reading generator, network, and load data...")

    # Generator unit data
    gendata = df["units_data"]
    num_cols = size(gendata[:], 2)
    if num_cols >= 14
        gendata_range = "A2:N$(size(gendata[:], 1))"
        gendata = convert(Array{Float64, 2}, gendata[gendata_range])
    else
        col_char = num_cols == 13 ? "M" : (num_cols == 12 ? "L" : "K")
        gendata_range = "A2:$(col_char)$(size(gendata[:], 1))"
        raw_data = convert(Array{Float64, 2}, gendata[gendata_range])
        padding = zeros(size(raw_data, 1), 14 - num_cols)
        gendata = hcat(raw_data, padding)
    end

    # Generator cost data
    gencost = df["units_cost"]
    gencost_range = "A2:H$(size(gencost[:], 1))"
    gencost = convert(Array{Float64, 2}, gencost[gencost_range])

    # Transmission line data
    linedata = df["branch_data"]
    linedata_range = "A2:E$(size(linedata[:], 1))"
    linedata = convert(Array{Float64, 2}, linedata[linedata_range])

    # Load curve data
    loadcurve = df["load_curve"]
    loadcurve_range = "A2:B$(size(loadcurve[:], 1))"
    loadcurve = convert(Array{Float64, 2}, loadcurve[loadcurve_range])

    # Load data
    loaddata = df["load_data"]
    loaddata_range = "A2:C$(size(loaddata[:], 1))"
    loaddata = convert(Array{Float64, 2}, loaddata[loaddata_range])

    # ========================================================================
    # Part 4: Read data center data
    # ========================================================================
    println("  Reading data center data...")
    data_centra_data = df["data_centra"]
    data_centra_range = "A2:I$(size(data_centra_data[:], 1))"
    data_centra_data = convert(Array{Float64, 2}, data_centra_data[data_centra_range])

    # ========================================================================
    # Part 5: Read hydroelectric power data
    # ========================================================================
    println("  Reading hydroelectric power data...")
    hydropower_data = df["hydro_data"]
    hydropower_data_range = "A2:F$(size(hydropower_data[:], 1))"
    hydropower_data = convert(Array{Float64, 2}, hydropower_data[hydropower_data_range])

    hydropower_curve = df["hydro_seasoncurve"]
    hydropower_curve_range = "A2:B$(size(hydropower_curve[:], 1))"
    hydropower_curve = convert(Array{Float64, 2}, hydropower_curve[hydropower_curve_range])

    println("  ✓ All data successfully loaded from Excel file.")

    return (unitsfreqparam, windsfreqparam, strogesystemdata, gendata, gencost, linedata,
        loadcurve, loaddata, data_centra_data, hydropower_data, hydropower_curve)
end
