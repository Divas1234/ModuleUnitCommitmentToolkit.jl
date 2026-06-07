# 使用 CSV 和 DataFrames 包读取数据
using CSV
using DataFrames

# 读取 bench.csv 文件
df_bench = CSV.read("bench.csv", DataFrame)
df_proposed = CSV.read("proposed.csv", DataFrame)
df_enhanced = CSV.read("enhanced.csv", DataFrame)
# 按行求和，保存在 data_bench
data_bench = sum.(eachrow(Matrix(df_bench)))
data_proposed = sum.(eachrow(Matrix(df_proposed)))
data_enhanced = sum.(eachrow(Matrix(df_enhanced)))

data = hcat(data_bench, data_proposed, data_enhanced)
CSV.write("combined.csv", DataFrame(data,:auto), writeheader=false)