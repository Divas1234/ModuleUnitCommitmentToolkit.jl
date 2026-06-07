library(ggplot2)
library(tidyr)
library(dplyr)

# Read CSV
data <- read.csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\winds_curves.csv", header = TRUE)

df <- data.frame(data)

# Transpose
df_t <- as.data.frame(t(df))

# Add a time or x-axis column (e.g., Time from 1 to 24)
df_t$Time <- 1:nrow(df_t)

df_long <- pivot_longer(df_t, cols = -Time, names_to = "Variable", values_to = "Value")

# Order the Variable factor levels
df_long$Variable <- factor(df_long$Variable, levels = unique(df_long$Variable)) # Default order (alphabetical)

envelopes <- df_t %>%
  select(-Time) %>%
  summarise(across(everything(), list)) %>%
  as.data.frame()

df_t$Upper <- apply(df_t[, 1:30], 1, max)
df_t$Lower <- apply(df_t[, 1:30], 1, min)
df_long <- pivot_longer(df_t, cols = 1:30, names_to = "Variable", values_to = "Value")
df_long$Variable <- factor(df_long$Variable, levels = unique(df_long$Variable)) # Legend order

df_long$Variable <- factor(df_long$Variable,
                           levels = unique(df_long$Variable),
                           labels = paste0("scenario", seq_along(unique(df_long$Variable))))



p <- ggplot() +
  # 30 original lines
  geom_line(data = df_long, aes(x = Time, y = Value, color = Variable), alpha = 0.6) +

  # Upper envelope: dashed line + marker
  geom_line(data = df_t, aes(x = Time, y = Upper), color = "blue", linewidth = 0.75, linetype = "dashed") +
  geom_point(data = df_t, aes(x = Time, y = Upper), color = "blue", shape = 12, size = 2) + # shape 16 = filled circle

  # Lower envelope: dotted line + marker
  geom_line(data = df_t, aes(x = Time, y = Lower), color = "blue", linewidth = 0.75, linetype = "dashed") +
  geom_point(data = df_t, aes(x = Time, y = Lower), color = "blue", shape = 10, size = 2) + # shape 17 = filled triangle
  labs(
    title = "30 Lines with Envelopes",
    x = "Time",
    y = "Value",
    color = "Scenario"
  ) +
  theme_bw(base_size = 16) + # Larger base font size
  labs(
    x = expression("t (h)"),
    y = expression(p[w](t) ~ "(p.u.)"),
  ) +
  scale_fill_grey(
    start = 0.8, end = 0.4,
    name = "Load type", # <-- Legend title
    labels = c("Load 1", "Load 2", "Load 3") # <-- Custom labels
  ) + # Adjust range for contrast
  coord_cartesian(ylim = c(0.2, 0.7)) + # <-- Set your y-axis range here
  scale_x_continuous(
    breaks = seq(0, 25, by = 5), # Sets breaks from 0 to 25 at intervals of 5
    labels = seq(0, 25, by = 5) # Labels at each of those breaks
  ) +
  guides(color = guide_legend(override.aes = list(color = NA, linetype = 0))) +
  theme(
    # legend.position = "none",
    legend.text = element_blank(),                  # Hide labels
    legend.key = element_blank(),                   # Hide keys (symbols)
    legend.position = "inside", # 启用内部图例位置
    legend.position.inside = c(0.75, 0.85), # Place legend inside the plot (x, y coordinates from 0 to 1)
    legend.title = element_text(size = 10, face = "bold"),
    # legend.text = element_text(size = 8.5), # Use monospaced font for alignment
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

output_filename <- "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\boundaryconditions\\windscurves.pdf"

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
