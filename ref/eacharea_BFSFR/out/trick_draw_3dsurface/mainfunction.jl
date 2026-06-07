using Pkg
Pkg.activate("./.pkg/")
Pkg.instantiate()
using CairoMakie, ColorSchemes
using LinearAlgebra  # Import LinearAlgebra for matrix operations
using CSV
using DataFrames

function read_floats_as_matrix(filename::String)
    # Read the CSV file into a DataFrame
    df = CSV.read(filename, DataFrame)
    # Convert the DataFrame to a matrix of Float64 values
    matrix = convert(Matrix{Float64}, Matrix(df))
    return matrix  # Return the matrix of Float64 values
end
# Example usage
data0 = read_floats_as_matrix("data1.csv")
data1 = read_floats_as_matrix("data1.csv")
