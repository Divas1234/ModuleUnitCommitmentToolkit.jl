# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Install and load necessary libraries
if (!require("ggplot2")) {
    install.packages("ggplot2")
    library(ggplot2)
}
if (!require("reshape2")) {
    install.packages("reshape2")
    library(reshape2)
}
if (!require("RColorBrewer")) {
    install.packages("RColorBrewer")
    library(RColorBrewer)
}

# Read the CSV file into a data frame
frequency_data <- read.csv("d:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian_frequencyderivations_data.csv")

# Get the absolute values and then multiply by -1
frequency_data <- abs(frequency_data) * -1

# Select the desired columns
selected_data <- frequency_data[, c("folder_Gaussian.0.001.", "folder_Gaussian.0.0015.", "folder_Gaussian.0.002.", "folder_Gaussian.0.0025.", "folder_Gaussian.0.003.", "folder_Gaussian.0.0035.", "folder_Gaussian.0.004.")]

# Add a time/index column for plotting
selected_data$time <- 1:nrow(selected_data)

# Reshape the data from wide to long format for ggplot2
melted_data <- melt(selected_data, id.vars = "time", variable.name = "Case", value.name = "Frequency_Deviation")

# --- Set custom linewidths ---
# Define the linewidths based on the case
linewidths <- ifelse(
    grepl("0.001\\.$|0.004\\.$", melted_data$Case),
    0.50,
    0.25
)
melted_data$linewidth <- as.factor(linewidths) # Add linewidths to the data

# --- Reorder data to draw widest lines on top ---
melted_data <- melted_data[order(melted_data$linewidth), ]

# --- Create custom labels for the legend ---
# Extract the numeric part from the original column names
original_labels <- levels(melted_data$Case)
numeric_parts <- as.numeric(gsub("folder_Gaussian\\.(.*)\\.", "\\1", original_labels))
# Multiply by 10
numeric_parts <- numeric_parts * 10
# --- Align labels by padding with spaces ---
# Find the maximum width of the numeric parts
max_width <- max(nchar(numeric_parts))
# Format the numeric parts to have the same width (right-aligned)
aligned_numeric_parts <- format(numeric_parts, width = max_width, justify = "right")
# Create the new labels
new_labels <- paste0(aligned_numeric_parts, " * Gaussian(0,1)")


# Get a color palette for the manual scale
num_colors <- length(original_labels)
colors <- brewer.pal(num_colors, "Set1")

# Create the plot
# Create the plot
p <- ggplot(melted_data, aes(x = time, y = Frequency_Deviation, color = Case, linewidth = linewidth)) +
    geom_line() +
    ggtitle("Frequency Deviation for Selected Cases") +
    labs(
        x = expression("t (s)"),
        y = expression(paste(Delta, "f(t) (Hz)")),
        # title = paste("Frequency Derivatives from", file_name),
        color = "Frequency derivation \nunder uncertain-variability cases"
    ) +
    scale_color_manual(values = colors, labels = new_labels) +
    scale_linewidth_manual(values = c("0.25" = 0.25, "0.5" = 0.5)) +
    scale_x_continuous(
        breaks = seq(0, 1200, by = 200), # 原始数据的断点 (每120个点一个刻度)
        labels = seq(0, 60, by = 10) # 显示的标签 (对应0-60，每6个单位一个刻度)
    ) +
    ylim(-0.25, 0.1) +
    theme_bw(base_size = 16) + # Larger base font size
    theme(
        legend.position = "inside", # 启用内部图例位置
        legend.position.inside = c(0.56, 0.750), # Place legend inside the plot (x, y coordinates from 0 to 1)
        legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 10, family = "sans"), # Use monospaced font for alignment
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

# --- Dynamic output filename generation ---

# Get the path of the currently running script
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

# Construct the output filename to be in the same directory as the script
output_filename <- file.path(base_path, paste0("differentcases_", tools::file_path_sans_ext(file_name), ".pdf"))

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
