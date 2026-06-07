library(ggplot2)
library(reshape2) # For melting data
library(tidyr)
library(dplyr)
library(stringr)
# library(showtext) # for custom fonts

# # Add and activate Roboto font
# font_add_google(name = "Cormorant Garamond", family = "GCormorant Garamondaramond")
# showtext_auto()


# Read both CSV files
data1 <- read.csv("sampledata3.csv")
data2 <- read.csv("sampledata4.csv")

# Function to calculate statistics for a dataset
calculate_stats <- function(data) {
  row_means <- apply(-data, 1, mean)
  row_maxs <- apply(-data, 1, max)
  row_mins <- apply(-data, 1, min)
  row_sds <- apply(-data, 1, sd)

  combined_matrix <- cbind(Mean = row_means, Max = row_maxs, Min = row_mins, Std = row_sds)
  plot_data <- as.data.frame(combined_matrix)
  plot_data$Index <- 1:nrow(plot_data)

  # Ensure columns are numeric
  plot_data$Mean <- as.numeric(as.character(plot_data$Mean))
  plot_data$Min <- as.numeric(as.character(plot_data$Min))
  plot_data$Max <- as.numeric(as.character(plot_data$Max))
  plot_data$Std <- as.numeric(as.character(plot_data$Std))

  return(plot_data)
}

# Calculate statistics for both datasets
plot_data1 <- calculate_stats(data1)
plot_data2 <- calculate_stats(data2)

# Add dataset identifier
plot_data1$Dataset <- "Dataset 1"
plot_data2$Dataset <- "Dataset 2"

plot_data1$GroupLabel <- "Little noise"
plot_data2$GroupLabel <- "High noise"

# Combine the datasets
plot_data_combined <- rbind(plot_data1, plot_data2)

# Calculate envelope bounds for the combined dataset
plot_data_combined$Envelope_Min <- plot_data_combined$Mean - 50 * plot_data_combined$Std
plot_data_combined$Envelope_Max <- plot_data_combined$Mean + 50 * plot_data_combined$Std

# Create a unified legend
p <- ggplot(plot_data_combined, aes(x = Index)) +
  geom_ribbon(aes(ymin = Envelope_Min, ymax = Envelope_Max, fill = GroupLabel), alpha = 0.75) +
  geom_line(aes(y = Mean, color = GroupLabel)) +
  scale_color_manual(
    name = "Average frequency derivation",
    values = c("Little noise" = "#2d39c0", "High noise" = "#383634"),
    labels = c("Little noise" = "BF-SFR in little noise case", "High noise" = "BF-SFR in high noise case")
  ) +
  scale_fill_manual(
    name = "Envelope interval",
    values = c("Little noise" = "#299658", "High noise" = "#aaa79f"),
    labels = c("Little noise" = "BF-SFR in little noise case", "High noise" = "BF-SFR in high noise case")
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
    legend.position.inside = c(0.6, 0.25), # 图例在图形内部的位置 (x, y 坐标范围 0-1)
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 10), # Larger legend text
    axis.title = element_text(size = 12, face = "bold"), # Axis titles bigger
    legend.background = element_rect(fill = "transparent", color = NA),
    axis.text = element_text(size = 8), # Axis labels bigger
    # legend.background = element_rect(fill = "white", color = "black", linewidth = 0.3), # 添加白色背景和边框
    plot.title = element_blank(), # Title size and bold
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
    plot.margin = margin(20, 5, 20, 20), # Add margin around the plot
    panel.grid.major.y = element_line(linewidth = 0.5),
    legend.key.size = unit(0.5, "lines"),
    legend.spacing.y = unit(0.5, "pt"), # Reduce vertical spacing
    legend.key.height = unit(0.5, "lines"), # Shrink height of legend items
    legend.margin = margin(0, 0, 10, 0), # Remove extra margin
    legend.box.spacing = unit(0.5, "pt") # Tighten spacing between boxes
  )

# Print the plot
# print(p)

# Save the plot to a PDF file
ggsave("frequency_derivations_converter_yes_both_noise.pdf", plot = p, width = 3.5, height = 4, dpi = 300)
cat("Plot saved to frequency_derivations_converter_yes_both_noise.pdf\n")

# Save the plot_data to a CSV file
write.csv(plot_data_combined, "plot_data_statistics_converter_yes_both_noise.csv", row.names = FALSE)
cat("Plot data saved to plot_data_statistics_converter_yes_both_noise.csv\n")
