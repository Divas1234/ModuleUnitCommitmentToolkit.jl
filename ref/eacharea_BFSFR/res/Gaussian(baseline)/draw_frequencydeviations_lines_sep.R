# R script to read a CSV file

# Read the CSV file
data <- read.csv("sampledata1.csv")

# Calculate the mean of each row
row_means <- apply(-data, 1, mean)

# Calculate the max of each row
row_maxs <- apply(-data, 1, max)

# Calculate the min of each row
row_mins <- apply(-data, 1, min)

# Calculate the standard deviation of each row
row_sds <- apply(-data, 1, sd)

# Combine means, maxs, mins, and sds into a single matrix
# Each column will represent one statistic (mean, max, min, sd)
combined_matrix <- cbind(Mean = row_means, Max = row_maxs, Min = row_mins, Std = row_sds)

# Convert the matrix to a data frame for ggplot2
plot_data <- as.data.frame(combined_matrix)
# Add a row index for the x-axis
plot_data$Index <- 1:nrow(plot_data)

# Ensure columns are numeric
plot_data$Mean <- as.numeric(as.character(plot_data$Mean))
plot_data$Min <- as.numeric(as.character(plot_data$Min))
plot_data$Max <- as.numeric(as.character(plot_data$Max))
plot_data$Std <- as.numeric(as.character(plot_data$Std))

# Load ggplot2 library
if (!require(ggplot2, quietly = TRUE)) {
  install.packages("ggplot2", repos = "http://cran.us.r-project.org")
}
library(ggplot2)

# Calculate envelope bounds
plot_data$Envelope_Min <- plot_data$Mean - 50 * plot_data$Std
plot_data$Envelope_Max <- plot_data$Mean + 50 * plot_data$Std

# Create the plot
p <- ggplot(plot_data, aes(x = Index)) +
  geom_ribbon(aes(ymin = Envelope_Min, ymax = Envelope_Max, fill = "Calculated Envelope"), alpha = 0.5) + # New Envelope
  geom_line(aes(y = Mean, color = "Mean")) + # Mean line
  # 手动创建一个虚拟的线条图层用于图例
  geom_line(aes(y = Inf, color = "Calculated Envelope"), alpha = 0) + # 不可见的线条用于图例
  scale_color_manual(
    name = "BF-SFR model",
    values = c("Mean" = "#585863", "Calculated Envelope" = "#89898e"), # 使用更深的颜色
    labels = c("Average frequency derivations", "Band-enveloped interval \nformed by sampling samples (filters)")
  ) +
  scale_fill_manual(
    values = c("Calculated Envelope" = "#7e7e8f"), # 使用更深的蓝色
    guide = "none" # 隐藏fill图例
  ) +
  # 自定义图例 - 所有条目都显示为线条
  guides(
    color = guide_legend(
      override.aes = list(
        linetype = c("solid", "solid"), # 所有都为实线
        alpha = c(1, 0), # 所有都不透明
        linewidth = c(0.75, 0) # 统一线宽
      )
    )
  ) +
  labs(
    title = "Row Statistics with Calculated Envelope (Mean +/- 10*Std)",
    x = expression("t (s)"),
    y = expression(paste(Delta, "f(t) (Hz)")),
  ) +
  scale_x_continuous(
    breaks = seq(0, 1200, by = 200), # 原始数据的断点 (每120个点一个刻度)
    labels = seq(0, 60, by = 10) # 显示的标签 (对应0-60，每6个单位一个刻度)
  ) +
  theme_bw(base_size = 16) + # Larger base font size
  theme(
    legend.position = "inside", # 启用内部图例位置
    legend.position.inside = c(0.6, 0.85), # 图例在图形内部的位置 (x, y 坐标范围 0-1)
    legend.title = element_text(size = 8, face = "bold"),
    legend.text = element_text(size = 8), # Larger legend text
    axis.title = element_text(size = 10, face = "bold"), # Axis titles bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    axis.text = element_text(size = 8), # Axis labels bigger
    # legend.background = element_rect(fill = "white", color = "black", linewidth = 0.3), # 添加白色背景和边框
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    plot.margin = margin(20, 5, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 0.5),
    legend.margin = margin(10, 10, 5, 8),
    legend.key.size = unit(0.5, "lines"),
    legend.spacing.y = unit(0.5, "cm"),
    legend.box.spacing = unit(0, "pt")
  )

# Print the plot
# print(p)

# Save the plot to a PDF file
ggsave("frequency_derivations.pdf", plot = p, width = 3.5, height = 3.5, dpi = 300)
cat("Plot saved to row_statistics_plot.pdf\n")

# Save the plot_data to a CSV file
write.csv(plot_data, "plot_data_statistics.csv", row.names = FALSE)
cat("Plot data saved to plot_data_statistics.csv\n")
