# 加载必要的包
using CSV, DataFrames  # 用于读取和处理 CSV 数据
using Plots            # 用于绘图
gr()                   # 设置 GR 作为绘图后端

# 读取 CSV 文件
file_path = "zdata_interpolated.csv"  # 请替换为你的实际文件路径

df = CSV.read(file_path, DataFrame)
println("成功读取数据，数据维度: $(size(df))")

# 将 DataFrame 转换为矩阵
data_matrix = Matrix(df)

# 检查数据是否适合绘制表面图
rows, cols = size(data_matrix)

if rows < 2 || cols < 2
    error("数据维度太小，无法绘制表面图")
end

# 创建坐标网格
x = 1:rows
y = 1:cols
X = repeat(x, 1, cols)
Y = repeat(y', rows, 1)

# 绘制表面图
surface(x, y, data_matrix, title = "数据表面图", xlabel = "X 轴", ylabel = "Y 轴", zlabel = "值", color = :viridis, alpha = 0.8, legend = false)

# 保存图形（可选）
savefig("surface_plot.png")
println("表面图已保存为 surface_plot.png")
