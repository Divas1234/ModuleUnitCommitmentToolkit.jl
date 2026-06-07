# 设定 CRAN 镜像
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# 加载或安装必要包
<<<<<<< HEAD
for (pkg in c("ggplot2", "dplyr", "tidyr", "readr", "reshape2")) {
=======
for (pkg in c("ggplot2", "dplyr", "tidyr", "readr")) {
>>>>>>> df7532d1943c70d9c5274d592fa7fb2e363cffa2
  if (!require(pkg, character.only = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

<<<<<<< HEAD
# Read the CSV file and ensure it's a dataframe
nadir_data <- as.data.frame(read.csv("D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/nadir.csv", header = FALSE, fill = TRUE))
nadir_data <- abs(nadir_data)
# temp_row <- nadir_data[2, ]
# nadir_data[2, ] <- nadir_data[3, ]
# nadir_data[3, ] <- temp_row

# Reshape to long format using base R
nadir_long <- data.frame(
  Row = rep(seq_len(nrow(nadir_data)), times = ncol(nadir_data)),
  Time = rep(seq_len(ncol(nadir_data)), each = nrow(nadir_data)),
  Value = as.vector(as.matrix(nadir_data))
)
nadir_long$Time <- as.numeric(nadir_long$Time) # <-- 添加这行
nadir_long$Row <- as.factor(nadir_long$Row) # 确保 fill 的分组正确
# Grouped bar plot using ggplot2
p <- ggplot(nadir_long, aes(x = Time, y = Value, fill = factor(Row))) + # Remove factor() from Time
  geom_bar(stat = "identity", position = position_dodge(width = 0.95)) +
  geom_line(aes(group = Row, color = factor(Row)), linewidth = 0.75, position = position_dodge(width = 0.9), show.legend = FALSE) +
  geom_point(aes(group = Row, color = factor(Row)),
    shape = 21, fill = "white", size = 1.25, stroke = 1.2,
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
    y = expression(paste("Frequency nadir (Hz)")),
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
  ylim(0, 1.5) +
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
base_path <- "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output"
file_name <- basename(script_path)

# Construct the output filename
output_filename <- file.path(base_path, paste0("nadir_", tools::file_path_sans_ext(file_name), ".pdf"))

# Save the plot
ggsave(output_filename, plot = p, width = 3.5, height = 4.0, units = "in", dpi = 300)
=======
# ✅ 读取 CSV（确保是纯数值，无列名）
# 如果没有表头就加 header = FALSE
frequency_data <- read.csv(
  "/Users/yuanyiping/Documents/GitHub/RFCUC/RfcucCaseStudies/littlecase/output/nadir.csv",
  header = FALSE,  # 保守处理，先不认为它有列名
  stringsAsFactors = FALSE
)

str(frequency_data)
head(frequency_data)

# 强制转换为数值矩阵（防止数据带字符或 factor）
frequency_matrix <- as.matrix(frequency_data)
storage.mode(frequency_matrix) <- "numeric"

# 将矩阵转为 data.frame 并添加 ID
df <- as.data.frame(frequency_matrix)
df$ID <- paste0("Line_", seq_len(nrow(df)))

# 给前24列命名为 V1~V24
colnames(df)[1:24] <- paste0("V", 1:24)

# 转为长格式
df_long <- df %>%
  pivot_longer(cols = starts_with("V"), names_to = "Time", values_to = "Value") %>%
  mutate(Time = as.numeric(gsub("V", "", Time)))

# ✅ 绘图
ggplot(df_long, aes(x = Time, y = Value, color = ID)) +
  geom_line(size = 1.2) +
  geom_point(size = 1.5) +
  labs(title = "Frequency Data Plot", x = "Hour", y = "Frequency (Hz)") +
  theme_minimal()
>>>>>>> df7532d1943c70d9c5274d592fa7fb2e363cffa2
