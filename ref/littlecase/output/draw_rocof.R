# 设定 CRAN 镜像
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# 加载或安装必要包
for (pkg in c("ggplot2", "dplyr", "tidyr", "readr", "reshape2")) {
  if (!require(pkg, character.only = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

# Read the CSV file and ensure it's a dataframe
rocof_data <- as.data.frame(read.csv("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/rocof.csv", header = FALSE, fill = TRUE))
rocof_data <- abs(rocof_data)

# Reshape to long format using base R
rocof_long <- data.frame(
  Row = rep(seq_len(nrow(rocof_data)), times = ncol(rocof_data)),
  Time = rep(seq_len(ncol(rocof_data)), each = nrow(rocof_data)),
  Value = as.vector(as.matrix(rocof_data))
)
rocof_long$Time <- as.numeric(rocof_long$Time) # <-- 添加这行
rocof_long$Row <- as.factor(rocof_long$Row) # 确保 fill 的分组正确
# Grouped bar plot using ggplot2
p <- ggplot(rocof_long, aes(x = Time, y = Value, fill = factor(Row))) + # Remove factor() from Time
  geom_bar(stat = "identity", position = position_dodge(width = 0.95)) +
  geom_line(aes(group = Row, color = factor(Row)), linewidth = 0.75, position = position_dodge(width = 0.9), show.legend = FALSE) +
  geom_point(aes(group = Row, color = factor(Row)),
    shape = 21, fill = "white", size = 0.75, stroke = 1.2,
    position = position_dodge(width = 0.9), show.legend = FALSE
  ) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  ) +
  labs(
    x = expression("t (h)"),
    y = expression(paste("RoCoF (Hz/s)")),
    fill = "Models"
  ) +
    scale_fill_manual(
    values = c("#E6B89C","#8E8D8A", "#4D648D"),
    labels = c("r-FCUC", "FCUC", "TUC")
  ) +
  scale_color_manual(
    values = c("#E6B89C", "#8E8D8A", "#4D648D"),
    labels = c("r-FCUC", "FCUC", "TUC")
  ) +
  theme_bw(base_size = 16) +
  # ylim(0, 2) +
  coord_cartesian(ylim = c(0.80, 1.5))+
  scale_x_continuous(limits = c(0, 25), breaks = seq(0, 25, by = 5)) +
  theme(
    # legend.position = c(0.8, 0.85),
    legend.position = "inside", # 启用内部图例位置
    legend.position.inside = c(0.8, 0.85), # Place legend inside the plot (x, y coordinates
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 10),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "gray90"),
    plot.margin = margin(20, 5, 20, 20),
    panel.grid.major.y = element_line(linewidth = 0.5),
    legend.margin = margin(10, 10, 5, 8),
    legend.key.size = unit(0.5, "lines"),
    legend.spacing.y = unit(0.5, "cm"),
    legend.box.spacing = unit(0, "pt")
  )

print(p)
# Get the path of the currently running script
args <- commandArgs(trailingOnly = FALSE)
file.arg <- grep("--file=", args, value = TRUE)
if (length(file.arg) == 0) {
  script_path <- "interactive.R"
} else {
  script_path <- sub("--file=", "", file.arg)
}

# Define base path and file name from the script's actual location
base_path <- "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/"
file_name <- basename(script_path)

# Construct the output filename
output_filename <- file.path(base_path, paste0("rocof_", tools::file_path_sans_ext(file_name), ".pdf"))

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
