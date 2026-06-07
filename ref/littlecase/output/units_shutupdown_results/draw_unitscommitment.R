# 加载必要库
library(ggplot2)
library(reshape2)
library(gridExtra)

# 读取数据函数
read_matrix <- function(file) {
	mat <- as.matrix(read.table(file, header = FALSE, sep = '\t'))
	return(mat)
}

# 读取三个txt文件
bench <- read_matrix('D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Bench_calculation_result.txt')
pros <- read_matrix('D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Pros_calculation_result.txt')
pros_fcr <- read_matrix('D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Pros_enhance_with_FCR_calculation_result.txt')

# 转换为长数据格式

# 行标签为G1,G2,G3
mat_to_df <- function(mat, name) {
	df <- melt(mat)
	colnames(df) <- c('Row', 'Col', 'Value')
	df$Type <- name
	df$Row <- factor(df$Row, levels = 1:3, labels = c('G1', 'G2', 'G3'))
	df$Col <- as.numeric(df$Col) # 确保Col为数值型
	return(df)
}
df1 <- mat_to_df(bench, 'Bench')
df2 <- mat_to_df(pros, 'Pros')
df3 <- mat_to_df(pros_fcr, 'Pros+FCR')

# 绘制热力图

# 只保留最后一个热力图的横坐标，其余去除x轴文本和标题，不显示颜色bar，灰色配色，突出grid
gray_palette <- c("#ffffff", "#9a9191", "#635e5e")


p1 <- ggplot(df1, aes(x = Col, y = Row, fill = Value)) +
	geom_tile(color = "#c0b4b4", linewidth = 0.6) +
	scale_fill_gradientn(colours = gray_palette, guide = 'none') +
	scale_x_continuous(
		limits = c(0, 25),
		breaks = seq(0, 25, 5),
		expand = c(0, 0)
	) +
	ylab('TUC') +
	theme_minimal(base_size = 14) +
	theme(
		axis.title.x = element_blank(),
		axis.text.x = element_blank(),
		axis.ticks.x = element_blank(),
		axis.title.y = element_text(size = 12, face = "bold"),
		axis.text = element_text(size = 8),
		legend.background = element_rect(fill = "transparent", color = NA),
		plot.title = element_blank(),
		panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
		plot.margin = margin(2, 5, 2, 20),
		panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
		panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
	)


p2 <- ggplot(df2, aes(x = Col, y = Row, fill = Value)) +
	geom_tile(color = "#d1c7c7", linewidth = 0.6) +
	scale_fill_gradientn(colours = gray_palette, guide = 'none') +
	scale_x_continuous(
		limits = c(0, 25),
		breaks = seq(0, 25, 5),
		expand = c(0, 0)
	) +
	ylab('FCUC') +
	theme_minimal(base_size = 14) +
	theme(
		axis.title.x = element_blank(),
		axis.text.x = element_blank(),
		axis.ticks.x = element_blank(),
		axis.title.y = element_text(size = 12, face = "bold"),
		axis.text = element_text(size = 8),
		legend.background = element_rect(fill = "transparent", color = NA),
		plot.title = element_blank(),
		panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
		plot.margin = margin(2, 5, 2, 20),
		panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
		panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
	)


# Pros+FCR显示横坐标
p3 <- ggplot(df3, aes(x = Col, y = Row, fill = Value)) +
	geom_tile(color = "#c9bebe", linewidth = 0.6) +
	scale_fill_gradientn(colours = gray_palette, guide = 'none') +
	scale_x_continuous(
		limits = c(0, 25),
		breaks = seq(0, 25, 5),
		expand = c(0, 0)
	) +
	ylab('r-FCUC') +
	labs(
		x = expression("t (s)")
	) +
	theme_minimal(base_size = 14) +
	theme(
		axis.title.x = element_text(size = 12, face = "bold"),
		axis.text.x = element_text(size = 8),
		axis.ticks.x = element_line(),
		axis.title.y = element_text(size = 12, face = "bold"),
		axis.text = element_text(size = 8),
		legend.background = element_rect(fill = "transparent", color = NA),
		plot.title = element_blank(),
		panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
		plot.margin = margin(2, 5, 2, 20),
		panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
		panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
	)

# 3*1排版输出，减少间距
library(grid)
p <- grid.arrange(
	p1,
	p2,
	p3,
	ncol = 1,
	heights = c(1, 1, 1.2),
	top = NULL,
	bottom = NULL,
	left = NULL,
	right = NULL,
	padding = unit(0.1, "line")
)
print(p)
# Get the path of the currently running script
args <- commandArgs(trailingOnly = FALSE)
file.arg <- grep("--file=", args, value = TRUE)
if (length(file.arg) == 0) {
	script_path <- "interactive.R"
} else {
	script_path <- sub("--file=", "", file.arg)
}

# Define base path and file name from the script's actual location
base_path <- "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/"
file_name <- basename(script_path)

# Construct the output filename
output_filename <- file.path(
	base_path,
	paste0("rocof_", tools::file_path_sans_ext(file_name), ".pdf")
)

# Save the plot
ggsave(
	output_filename,
	plot = p,
	width = 4.0,
	height = 3.5,
	units = "in",
	dpi = 300
)
