base_path <- "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\check_additionapower_frequencydynamics\\"
file_name <- "frequencydynamic.csv"
input_filepath <- file.path(base_path, file_name)

# Load necessary libraries
library(ggplot2)
library(tidyr)
library(dplyr)
library(stringr)

# Read data (no header)
raw_data <- read.csv(input_filepath, header = TRUE)

# Add time axis (assuming 0.05s interval, e.g. 60s / 1200 = 0.05)
n <- nrow(raw_data)
timestep <- 0.05
xdata <- seq(0, by = timestep, length.out = n)

# Rename columns (three models)
colnames(raw_data) <- c("x1", "x2", "x3")

# Bind time column
data <- cbind(xdata = xdata, raw_data)

# 转换为长格式，便于 ggplot 绘图
data_long <- data %>%
  pivot_longer(
    cols = -xdata,
    names_to = "Model",
    values_to = "FrequencyDerivative"
  ) %>%
  mutate(Model = recode(Model,
    "x3" = "r-FCUC",
    "x2" = "FCUC",
    "x1" = "TUC"
  ))

# 使用 ggplot2 绘图
p <- ggplot(data_long, aes(x = xdata, y = FrequencyDerivative, color = Model)) +
  geom_line(linewidth = 0.75) +
  labs(
    x = expression("t (s)"),
    y = expression(paste(Delta, "f(t) (Hz)")),
    color = "Model group"
  ) +
  scale_x_continuous(breaks = seq(0, max(xdata), by = 10)) +
  coord_cartesian(ylim = c(-0.4, 0.05)) + # 根据你的数据调整范围
  scale_color_manual(values = c(
    "r-FCUC" = "#598ae1",
    "FCUC" = "#dba869",
    "TUC" = "#565b59"
  )) +
  theme_bw(base_size = 16) +
  theme(
    # legend.position.inside = TRUE,
    legend.position = "inside", # 启用内部图例位置
    legend.position.inside = c(0.75, 0.8),
       legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 10), # Use monospaced font for alignment
        axis.title = element_text(size = 12, face = "bold"), # Axis titles bigger
        axis.text = element_text(size = 8), # Axis labels bigger
        legend.background = element_rect(fill = "transparent", color = NA),
        plot.title = element_blank(), # Title size and bold
        panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
        plot.margin = margin(20, 5, 20, 20), # Add margin around the plot
        panel.grid.major.y = element_line(linewidth = 0.5),
        legend.margin = margin(10, 10, 5, 8),
        legend.key.size = unit(0.5, "lines"),
        legend.spacing.y = unit(0.5, "cm"),
        legend.box.spacing = unit(0, "pt")
  )

show(p)
# 保存为 PDF 图像
output_filename <- file.path(base_path, paste0("frequency_derivatives_plot_", tools::file_path_sans_ext(file_name), ".pdf"))
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)

# 控制台提示
print(paste("Plot saved as", output_filename))
