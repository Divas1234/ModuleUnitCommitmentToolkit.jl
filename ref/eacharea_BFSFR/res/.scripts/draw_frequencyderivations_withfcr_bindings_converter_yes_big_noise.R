library(ggplot2)
library(tidyr)
library(readr)
library(dplyr)

# Read the data
# Read the data with error handling
data <- read.csv("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/fcr_bindings_frequencyderivations_converter_yes_big_noise.csv")

# Check if data was read successfully
if (is.null(data) || nrow(data) == 0) {
    stop("Error: No data found in the CSV file!")
}

# Display basic info about the data
cat("Data dimensions:", dim(data), "\n")
cat("Column names:", names(data), "\n")

# Reshape the data from wide to long format
data_long <- data %>%
    mutate(time = row_number()) %>%
    pivot_longer(cols = -time, names_to = "folder", values_to = "value") %>%
    filter(!is.na(value)) %>% # Remove NA values
    mutate(folder = gsub("folder_fcr_binding\\.(\\d+)", "FCR = \\1", folder))

# Create an enhanced plot
p <- ggplot(data_long, aes(x = time, y = value, color = folder)) +
    geom_line(linewidth = 0.5, alpha = 0.8) +
    # geom_point(size = 0.5, alpha = 0.6) +
    labs(
        title = "FCR Bindings Frequency Derivations",
        # subtitle = paste("Data from", ncol(data) - 1, "folders over", nrow(data), "time steps"),
        x = "Time Step",
        y = "Frequency Value",
        color = "Data Source"
    ) +
    theme_minimal() +
    theme(
        plot.title = element_text(size = 14, face = "bold"),
        plot.subtitle = element_text(size = 12),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
    ) +
    labs(
        x = expression("t (s)"),
        y = expression(paste(Delta, "f(t) (Hz)")),
        # title = paste("Frequency Derivatives from", file_name),
        color = "Frequency derivation \nunder various FCR cases"
    ) +
    scale_linewidth_manual(values = c("0.25" = 0.25, "0.5" = 0.5)) +
    scale_x_continuous(
        breaks = seq(0, 1200, by = 200), # 原始数据的断点 (每120个点一个刻度)
        labels = seq(0, 60, by = 10) # 显示的标签 (对应0-60，每6个单位一个刻度)
    ) +
    scale_y_continuous(breaks = scales::pretty_breaks(n = 8)) +
    theme_bw(base_size = 16) + # Larger base font size
    theme(
        legend.position = "inside", # 启用内部图例位置
        legend.position.inside = c(0.65, 0.805), # Place legend inside the plot (x, y coordinates from 0 to 1)
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
    ) +
    guides(linewidth = "none") # Hide the linewidth legend

# Display the plot
print(p)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("--file=", args, value = TRUE)
if (length(file_arg) == 0) {
    # Provide a fallback for interactive mode
    script_path <- "interactive.R"
} else {
    script_path <- sub("--file=", "", file_arg)
}

# Define base path and file name from the script's actual location
base_path <- dirname(script_path)
file_name <- basename(script_path)

base_path <- "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/"

# Construct the output filename to be in the same directory as the script
output_filename <- file.path(base_path, paste0("differentcases_", tools::file_path_sans_ext(file_name), ".pdf"))

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
