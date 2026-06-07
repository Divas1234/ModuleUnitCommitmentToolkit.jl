import Pkg

println("正在安装必需的 Julia 包...")

# 定义需要安装的包列表
packages = ["PowerModels", "DifferentialEquations", "Plots"]

# 循环安装所有包
for pkg in packages
    println("正在安装: ", pkg)
    Pkg.add(pkg)
end

println("所有包都已成功安装。")