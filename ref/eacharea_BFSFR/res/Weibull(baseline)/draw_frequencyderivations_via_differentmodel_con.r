# Load necessary libraries
library(ggplot2)
library(reshape2) # For melting data
library(tidyr)
library(dplyr)
library(stringr)
library(cowplot)

# List of files to process
file_list <- c(
  "converter_not_big_noise.csv",
  "converter_yes_big_noise.csv",
  "converter_yes_little_noise.csv",
  "converter_not_little_noise.csv"
)

# Create a list to store the plots
plot_list <- list()

# Loop through each file
for (file_name in file_list) {
  # Read the data from the CSV file
  data <- read.csv(file_name)

  # Melt the data into a long format for ggplot2
  data_long <- melt(data, id.vars = "xdata", variable.name = "Model", value.name = "FrequencyDerivative")

  # Rename the models for the legend
  data_long <- data_long %>%
    mutate(Model = recode(Model,
      "sfr_data" = "SFR (baseline method)",
      "bfsfr_data" = "BF-SFR (the proposed method)",
      "real_data" = "Simulator (reference frequency trajactories)"
    ))

  # Create the plot using ggplot2
  p <- ggplot(data_long, aes(x = xdata, y = FrequencyDerivative, color = Model)) +
    geom_line(linewidth = 0.75) +
    labs(
      x = expression("t (s)"),
      y = expression(paste(Delta, "f(t) (Hz)")),
      title = paste("Frequency Derivatives from", file_name),
      color = str_wrap("Frequency dynamic methods", width = 50)
    ) +
    scale_x_continuous(breaks = seq(0, 60, by = 10)) +
    coord_cartesian(ylim = c(-0.4, 0.05)) +
    theme_bw(base_size = 16) + # Larger base font size
    theme(
      legend.position = "none", # Remove legend from individual plots
      axis.title = element_text(size = 8, face = "bold"), # Axis titles bigger
      axis.text = element_text(size = 8), # Axis labels bigger
      plot.title = element_text(size = 10, face = "bold", hjust = 0.5), # Center plot title
      panel.grid.major = element_line(linewidth = 0.5, color = "gray90"), # Lighter grid lines
      plot.margin = margin(20, 5, 20, 20), # Add margin around the plot
      panel.grid.major.y = element_line(linewidth = 0.5)
    )
  
  # Add the plot to the list
  plot_list[[length(plot_list) + 1]] <- p
}

# Combine the plots into a 2x2 grid
combined_plot <- plot_grid(plotlist = plot_list, nrow = 2, ncol = 2)

# Save the combined plot
ggsave("combined_frequency_derivatives_plot.pdf", plot = combined_plot, width = 8, height = 6, units = "in", dpi = 300)

# Print a message to confirm the plot has been saved
print("Combined plot saved as combined_frequency_derivatives_plot.pdf")
