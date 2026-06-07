library(ggplot2)
library(reshape2)
library(dplyr)
library(tidyr)

file_list <- c(
    "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata3.csv",
    "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/sampledata4.csv"
)

data_list <- list()

for (i in seq_along(file_list)) {
    file <- file_list[i]
    data_list[[i]] <- read.csv(file)
}

max_rows <- list()

for (i in seq_along(data_list)) {
    df <- data_list[[i]]
    row_means <- rowMeans(df, na.rm = TRUE)
    max_index <- which.max(row_means)
    max_rows[[i]] <- df[max_index, ]
}

max_rows_df <- do.call(rbind, max_rows)

df_t <- as.data.frame(t(max_rows_df))
colnames(df_t) <- paste0("Row", 1:nrow(max_rows_df))

df_long <- df_t %>%
    pivot_longer(cols = everything(), names_to = "variable", values_to = "value")

# Create the violin plot with custom styling
p <- ggplot(df_long, aes(x = variable, y = value, fill = variable, color = variable)) +
    geom_violin(width = 0.5, alpha = 0.7, trim = FALSE) +  # Reduced width from 0.7 to 0.5
    geom_boxplot(width = 0.1, fill = "white", alpha = 0.5, outlier.shape = NA) +
    labs(
        x = "Nadir",
        y = expression(paste(Delta, "f(t) (Hz)")),
        fill = "Group",
        color = "Group"
    ) +
    scale_fill_manual(
        values = c("#1f77b4", "#ff7f0e"),
        labels = c("Gaussian(0, 1e-3)", "Gaussian(0, 1e-2)")
    ) +
    scale_color_manual(
        values = c("#393b3c", "#42403e"),
        labels = c("Gaussian(0, 1e-3)", "Gaussian(0, 1e-2)")
    ) +
    scale_x_discrete(
        breaks = c("Row1", "Row2"),
        labels = c("Mini residual", "High residual")
    ) +
    theme_bw(base_size = 16) +
    theme(
        legend.position = "inside",
        legend.position.inside = c(0.3, 0.80),
        legend.justification = c(0.5, 0.5),
        legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 10),
        axis.title = element_text(size = 10, face = "bold"),
        axis.text = element_text(size = 8),
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
ggsave("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/eacharea_BFSFR/res/Gaussian(baseline)/frequencynadir_violin_big_noise.pdf", plot = p, width = 3.5, height = 4, units = "in", dpi = 300)

print("Combined plot saved as frequencynadir_violin.pdf")
