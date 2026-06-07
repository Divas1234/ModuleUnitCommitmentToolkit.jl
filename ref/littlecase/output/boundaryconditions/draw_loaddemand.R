library(ggplot2)
library(tidyr)
library(dplyr)

# Read CSV
data <- read.csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\loads_curves.csv", header = TRUE)

df <- data.frame(data)

# Transpose
df_t <- as.data.frame(t(df))

# Add a proper time/index
df_t$Time <- 1:nrow(df_t)

# Pivot longer: so each row is (Time, Category, Value)
df_long <- pivot_longer(df_t, cols = -Time, names_to = "Category", values_to = "Value")

# Plot: each bar is a Time, stacked by Category
p <- ggplot(df_long, aes(x = as.numeric(Time), y = Value, fill = Category)) +
  geom_bar(stat = "identity") +
  labs(title = "Stacked Bar Plot by Time", x = "Time Period", y = "Value") +
  theme_bw(base_size = 16) + # Larger base font size
  labs(
    x = expression("t (h)"),
    y = expression(p[d](t) ~ "(p.u.)"),
  ) +
  scale_fill_grey(
    start = 0.8, end = 0.4,
    name = "Load type", # <-- Legend title
    labels = c("Load 1", "Load 2", "Load 3") # <-- Custom labels
  ) + # Adjust range for contrast
  coord_cartesian(ylim = c(0, 4.5)) + # <-- Set your y-axis range here
  scale_x_continuous(
    breaks = seq(0, 25, by = 5), # Sets breaks from 0 to 25 at intervals of 5
    labels = seq(0, 25, by = 5) # Labels at each of those breaks
  ) +
  theme(
    legend.position = "inside", # 启用内部图例位置
    legend.position.inside = c(0.75, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
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

print(p)

# Define base path and file name from the script's actual location
# base_path <- dirname(script_path)
# file_name <- basename(script_path)

# Construct the output filename to be in the same directory as the script
# output_filename <- file.path(base_path, paste0("loadcurves_", tools::file_path_sans_ext(file_name), ".pdf"))
output_filename <- "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\loadcurves.pdf"

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
