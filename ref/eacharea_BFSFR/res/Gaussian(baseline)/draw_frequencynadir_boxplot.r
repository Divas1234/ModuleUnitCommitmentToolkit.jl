library(ggplot2)
library(reshape2)
library(dplyr)
library(tidyr)

file_list <- c(
    "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata1.csv",
    "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata2.csv"
)

# "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata3.csv",
# "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata4.csv"


data_list <- list()

for (i in seq_along(file_list)) {
    file <- file_list[i]
    data_list[[i]] <- read.csv(file)
}

# head(data_list[[2]])

max_rows <- list()

for (i in seq_along(data_list)) {
    df <- data_list[[i]]
    row_means <- rowMeans(df, na.rm = TRUE)
    max_index <- which.max(row_means)
    max_rows[[i]] <- df[max_index, ]
}

# print(max_rows[[1]])
max_rows_df <- do.call(rbind, max_rows)
# dim(max_rows_df)

df_t <- as.data.frame(t(max_rows_df))
colnames(df_t) <- paste0("Row", 1:nrow(max_rows_df))

df_long <- df_t %>%
    pivot_longer(cols = everything(), names_to = "variable", values_to = "value")

# Create the boxplot
# Create the boxplot with custom x-axis labels, y-axis title, and updated legend
p <- ggplot(df_long, aes(x = variable, y = value, fill = variable, color = variable)) +
    geom_boxplot(width = 0.45) +
    labs(
        x = "nadir", # Custom x-axis title
        y = expression(paste(Delta, "f(t) (Hz)")), # Custom y-axis title with delta symbol
        fill = "Group", # Set the legend title to "Group"
        color = "Group" # Set the legend title to "Group" for color as well
    ) +
    scale_fill_manual(
        values = c("#1f77b4", "#ff7f0e"),
        # values = rep("#dde3e1", length(unique(df_long$variable))),
        labels = c("Gaussian(0, 1e-3)", "Gaussian(0, 1e-2)") # Custom legend labels
    ) +
    scale_color_manual(
        values = c("#393b3c", "#42403e"), # Matching the color for box borders
        # values = rep("#797676", length(unique(df_long$variable))),
        labels = c("Gaussian(0, 1e-3)", "Gaussian(0, 1e-2)") # Custom legend labels
    ) +
    # scale_y_continuous(limits = c(0, 100)) + # Set the y-axis limits between 0 and 100
    scale_x_discrete(
        breaks = c("Row1", "Row2"), # Original x-axis labels (row1, row2, etc.)
        labels = c("Mini residual", "High residual") # New x-axis labels (case1, case2, etc.)
    ) +
    theme_classic() +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 14)) +
    theme_bw(base_size = 16) +
    theme(
        legend.position = "inside", # 启用内部图例位置
        legend.position.inside = c(0.3, 0.80), # 图例在图形内部的位置 (x, y 坐标范围 0-1)
        legend.justification = c(0.5, 0.5), # Center the legend at the given position
        legend.title = element_text(size = 10, face = "bold"), # Legend title styling
        legend.text = element_text(size = 10), # Larger legend text
        axis.title = element_text(size = 12, face = "bold"), # Axis titles bigger
        axis.text = element_text(size = 8), # Axis labels bigger
        plot.title = element_blank(),
        panel.grid.major = element_line(linewidth = 0.5, color = "gray90"),
        plot.margin = margin(20, 5, 20, 20),
        panel.grid.major.y = element_line(linewidth = 0.5),
        legend.key.size = unit(0.5, "lines"),
        legend.spacing.y = unit(1, "lines"),
        legend.key.height = unit(0.5, "lines"),
        legend.margin = margin(0, 0, 10, 0),
        legend.box.spacing = unit(0.5, "pt")
    )

# Save the combined plot
ggsave("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/frequencynadir_boxplot.pdf", plot = p, width = 3.5, height = 4, units = "in", dpi = 300)
print("Combined plot saved as frequencynadir_boxplot.pdf")
