# Define the absolute path to the data directory
# You can change this to your own path
base_path <- "d:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res"

# Load necessary libraries
library(ggplot2)
library(reshape2) # For melting data
library(tidyr)
library(dplyr)
library(stringr)

# List of files to process
file_list <- c(
  "converter_not_big_noise.csv",
  "converter_yes_big_noise.csv",
  "converter_yes_little_noise.csv",
  "converter_not_little_noise.csv"
)

# Loop through each file
for (file_name in file_list) {
  # Construct the full path for the input file
  input_filepath <- file.path(base_path, file_name)

  # Read the data from the CSV file
  data <- read.csv(input_filepath)

  # Melt the data into a long format for ggplot2
  data_long <- melt(data, id.vars = "xdata", variable.name = "Model", value.name = "FrequencyDerivative")

  # Rename the models for the legend
  data_long <- data_long %>%
    mutate(Model = recode(Model,
      "sfr_data" = "SFR (baseline method)",
      "bfsfr_data" = "BF-SFR (the proposed method)",
      "real_data" = "Simulator (reference trajactories)"
    ))

  # Create the plot using ggplot2
  p <- ggplot(data_long, aes(x = xdata, y = FrequencyDerivative, color = Model)) +
    geom_line(linewidth = 0.75) +
    labs(
      x = expression("t (s)"),
      y = expression(paste(Delta, "f(t) (Hz)")),
      title = paste("Frequency Derivatives from", file_name),
      color = "Model group"
    ) +
    scale_x_continuous(breaks = seq(0, 60, by = 10)) +
    scale_color_manual(values = c(
      "SFR (baseline method)" = "#598ae1", # Muted Blue
      "BF-SFR (the proposed method)" = "#dba869", # Safety Orange
      "Simulator (reference trajactories)" = "#565b59" # Cooked Asparagus Green
    )) +
    # coord_cartesian(ylim = c(-0.4, 0.05)) +
    theme_bw(base_size = 16) + # Larger base font size
    theme(
      legend.position = c(0.53, 0.8), # Place legend inside the plot (x, y coordinates from 0 to 1)
      legend.title = element_text(size = 10, face = "bold"),
      legend.text = element_text(size = 10), # Larger legend text
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

  # Save the plot with a unique name
  output_filename <- file.path(base_path, paste0("frequency_derivatives_plot_", tools::file_path_sans_ext(file_name), ".pdf"))
  ggsave(output_filename, plot = p, width = 3.5, height = 4, units = "in", dpi = 300)

  # Print a message to confirm the plot has been saved
  print(paste("Plot saved as", output_filename))
}
