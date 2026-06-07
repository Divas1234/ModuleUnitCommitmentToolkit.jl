# 加载必要库
library(ggplot2)
library(reshape2)
library(gridExtra)

# 读取数据函数
read_matrix <- function(file) {
  mat <- as.matrix(read.table(file, header = FALSE, sep = "\t"))
  return(mat)
}

# 读取三个txt文件
bench <- read_matrix(
  "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Bench_calculation_result.txt"
)
pros <- read_matrix(
  "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Pros_calculation_result.txt"
)
pros_fcr <- read_matrix(
  "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/Pros_enhance_with_FCR_calculation_result.txt"
)

# 转换为长数据格式

# 设置机组编号为1-54
mat_to_df <- function(mat, name) {
  df <- melt(mat)
  colnames(df) <- c("Row", "Col", "Value")
  df$Type <- name
  # 强制G1-G3
  df$Row <- factor(df$Row, levels = 1:3, labels = paste0("G", 1:3))
  df$Col <- as.numeric(df$Col) # 确保Col为数值型
  return(df)
}
df1 <- mat_to_df(bench, "Bench")
df2 <- mat_to_df(pros, "Pros")
df3 <- mat_to_df(pros_fcr, "Pros+FCR")

# x轴范围固定为0-25
col_min <- 0
col_max <- 25

# 清理数据，去除NA和超出范围的行
clean_df <- function(df, col_min, col_max) {
  df <- df[!is.na(df$Col) & !is.na(df$Row) & !is.na(df$Value), ]
  df <- df[df$Col >= col_min & df$Col <= col_max, ]
  return(df)
}
df1 <- clean_df(df1, col_min, col_max)
df2 <- clean_df(df2, col_min, col_max)
df3 <- clean_df(df3, col_min, col_max)

# 只用两种颜色，0为灰色，1为蓝色
state_palette <- c("0" = "#cccccc", "1" = "#0072B2")

# 绘制热力图

# 只保留最后一个热力图的横坐标，其余去除x轴文本和标题，不显示颜色bar，灰色配色，突出grid
gray_palette <- c("#ffffff", "#9a9191", "#635e5e")

p1 <- ggplot(df1, aes(x = Col, y = Row, fill = as.factor(Value))) +
  geom_tile(color = "#c0b4b4", linewidth = 0.6) +
  theme(
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 1)
  ) +
  scale_fill_manual(values = state_palette, guide = "none") +
  scale_x_continuous(
    limits = c(col_min, col_max),
    breaks = seq(col_min, col_max, by = 5),
    expand = c(0, 0)
  ) +
  ylab("TUC") +
  theme_minimal(base_size = 14) +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
    plot.margin = margin(2, 5, 2, 20),
    panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
    panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
  )


p2 <- ggplot(df2, aes(x = Col, y = Row, fill = as.factor(Value))) +
  geom_tile(color = "#d1c7c7", linewidth = 0.6) +
  theme(
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 1)
  ) +
  scale_fill_manual(values = state_palette, guide = "none") +
  scale_x_continuous(
    limits = c(col_min, col_max),
    breaks = seq(col_min, col_max, by = 5),
    expand = c(0, 0)
  ) +
  ylab("FCUC") +
  theme_minimal(base_size = 14) +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
    plot.margin = margin(2, 5, 2, 20),
    panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
    panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
  )

# Pros+FCR显示横坐标
p3 <- ggplot(df3, aes(x = Col, y = Row, fill = as.factor(Value))) +
  geom_tile(color = "#c9bebe", linewidth = 0.6) +
  theme(
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 1)
  ) +
  scale_fill_manual(values = state_palette, guide = "none") +
  scale_x_continuous(
    limits = c(col_min, col_max),
    breaks = seq(col_min, col_max, by = 5),
    expand = c(0, 0)
  ) +
  ylab("r-FCUC") +
  labs(
    x = expression("t (s)")
  ) +
  scale_y_discrete(breaks = paste0("G", 1:3)) +
  theme_minimal(base_size = 14) +
  theme(
    axis.title.x = element_text(size = 12, face = "bold"),
    axis.text.x = element_text(size = 8),
    axis.ticks.x = element_line(),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
    plot.margin = margin(2, 5, 2, 20),
    panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
    panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
  )


# 3*1排版输出，减少间距
library(grid)
p <- grid.arrange(
  p1,
  p2,
  p3,
  ncol = 1,
  heights = c(1, 1, 1.2),
  top = NULL,
  bottom = NULL,
  left = NULL,
  right = NULL,
  padding = unit(0.1, "line")
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
base_path <- "D:/GithubClonefiles/RFCUC/RfcucCaseStudies/littlecase/output/units_shutupdown_results/"
file_name <- basename(script_path)

# Construct the output filename
output_filename <- file.path(
  base_path,
  paste0("rocof_", tools::file_path_sans_ext(file_name), ".pdf")
)

# Save the plot，增大图片尺寸
ggsave(
  output_filename,
  plot = p,
  width = 3.5, # 增大宽度
  height = 15.0, # 增大高度
  units = "in",
  dpi = 300
)

# 合并三种方案，突出不同
combined_df <- df1
combined_df$Pros <- df2$Value
combined_df$ProsFCR <- df3$Value

# 定义状态类型
combined_df$State <- with(
  combined_df,
  ifelse(
    Value == 0 & Pros == 0 & ProsFCR == 0,
    "All0",
    ifelse(
      Value == 1 & Pros == 1 & ProsFCR == 1,
      "All1",
      ifelse(
        Pros != Value & ProsFCR == Value,
        "ProsDiff",
        ifelse(
          ProsFCR != Value & Pros == Value,
          "FCRDiff",
          ifelse(
            Pros != Value & ProsFCR != Value & Pros != ProsFCR,
            "AllDiff",
            "Other"
          )
        )
      )
    )
  )
)

# 颜色方案（灰配色）
combined_palette <- c(
  "All0" = "#f5f5f5", # 全部0 浅灰
  "All1" = "#636363", # 全部1 深灰
  "ProsDiff" = "#bdbdbd", # Pros与Bench不同 中灰
  "FCRDiff" = "#969696", # Pros+FCR与Bench不同 灰
  "AllDiff" = "#252525", # 三者均不同 黑灰
  "Other" = "#cccccc" # 其他情况 灰
)

# 合并图（marker标识差异）
# 定义底色（全部0/1/其他）
combined_df$Base <- with(
  combined_df,
  ifelse(
    Value == 0 & Pros == 0 & ProsFCR == 0,
    "All0",
    ifelse(Value == 1 & Pros == 1 & ProsFCR == 1, "All1", "Other")
  )
)
base_palette <- c("All0" = "#f5f5f5", "All1" = "#636363", "Other" = "#cccccc")

# 定义marker类型
combined_df$Marker <- with(
  combined_df,
  ifelse(
    State == "ProsDiff",
    "Pros",
    ifelse(State == "FCRDiff", "FCR", ifelse(State == "AllDiff", "All", NA))
  )
)

# marker_shape <- c("Pros" = 3, "FCR" = 4, "All" = 8) # |, x, *
marker_shape <- c(
  "Bench" = 1, # 圆圈 ○
  "Pros" = 1, # 斜十字 ✕
  "Pros+FCR" = 1 # 矩形 □
)

marker_color <- c("Pros" = "#bdbdbd", "FCR" = "#969696", "All" = "#252525")

p_combined <- ggplot(combined_df, aes(x = Col, y = Row)) +
  geom_tile(aes(fill = Base), color = "#c0b4b4", linewidth = 0.4) +
  scale_fill_manual(values = base_palette, guide = "none") +
  geom_point(
    data = subset(combined_df, !is.na(Marker)),
    aes(shape = Marker, color = Marker),
    size = 1.8,
    stroke = 1.1
  ) +
  scale_shape_manual(values = marker_shape, guide = "none") +
  scale_color_manual(values = marker_color, guide = "none") +
  scale_x_continuous(
    limits = c(col_min, col_max),
    breaks = seq(col_min, col_max, by = 5),
    expand = c(0, 0)
  ) +
  scale_y_discrete(
    breaks = paste0("G", seq(1, nrow(bench), by = 10))
  ) +
  ylab("Unit ID") +
  labs(x = expression("t (s)")) +
  theme_minimal(base_size = 14) +
  theme(
    axis.title.x = element_text(size = 12, face = "bold"),
    axis.text.x = element_text(size = 8),
    axis.ticks.x = element_line(),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
    plot.margin = margin(2, 5, 2, 20),
    panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
    panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
  )

# 输出合并图
print(p_combined)

ggsave(
  file.path(
    base_path,
    paste0("rocof_", tools::file_path_sans_ext(file_name), "_combined.pdf")
  ),
  plot = p_combined,
  width = 4.0,
  height = 7.5,
  units = "in",
  dpi = 300
)

# 只用marker标识不同模型的开机状态
bench_marker <- df1[df1$Value == 1, c("Col", "Row")]
bench_marker$Model <- "Bench"
pros_marker <- df2[df2$Value == 1, c("Col", "Row")]
pros_marker$Model <- "Pros"
fcr_marker <- df3[df3$Value == 1, c("Col", "Row")]
fcr_marker$Model <- "Pros+FCR"

marker_df <- rbind(bench_marker, pros_marker, fcr_marker)
marker_df$Model <- factor(
  marker_df$Model,
  levels = c("Bench", "Pros", "Pros+FCR")
)

# marker线条更细，线条用不同颜色
# marker_shape <- c("Bench" = 1, "Pros" = 2, "Pros+FCR" = 0) # ○ △ □
marker_shape <- c(
  "Bench" = 1, # 圆圈 ○
  "Pros" = 23, # 斜十字 ✕
  "Pros+FCR" = 3 # 矩形 □
)
marker_color <- c(
  "Bench" = "#e41a1c",
  "Pros" = "#377eb8",
  "Pros+FCR" = "#4daf4a"
) # 红、蓝、绿

p_marker <- ggplot(
  marker_df,
  aes(x = Col, y = Row, shape = Model, color = Model)
) +
  geom_point(
    data = subset(marker_df, Model == "Bench"),
    aes(shape = Model, color = Model), size = 6, stroke = 1.2
  ) +
  geom_point(
    data = subset(marker_df, Model == "Pros"),
    aes(shape = Model, color = Model), size = 4, stroke = 1.2
  ) +
  geom_point(
    data = subset(marker_df, Model == "Pros+FCR"),
    aes(shape = Model, color = Model), size = 2, stroke = 1.2
  ) +
  scale_shape_manual(values = marker_shape) +
  scale_color_manual(values = marker_color) +
  scale_x_continuous(
    limits = c(col_min, col_max),
    breaks = seq(col_min, col_max, by = 5),
    expand = c(0, 0)
  ) +
  scale_y_discrete(
    breaks = paste0("G", seq(1, nrow(bench), by = 10))
  ) +
  ylab("Unit ID") +
  labs(x = expression("t (s)")) +
  theme_minimal(base_size = 14) +
  theme(
    axis.title.x = element_text(size = 12, face = "bold"),
    axis.text.x = element_text(size = 8),
    axis.ticks.x = element_line(),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 8),
    legend.position = "top",
    legend.title = element_blank(),
    legend.background = element_rect(fill = "transparent", color = NA),
    plot.title = element_blank(),
    panel.grid.major = element_line(linewidth = 0.5, color = "#e0e0e0"),
    plot.margin = margin(2, 5, 2, 20),
    panel.grid.major.y = element_line(linewidth = 0.5, color = "#e0e0e0"),
    panel.grid.minor = element_line(color = "#f5f5f5", linewidth = 0.3)
  )

# 输出marker合并图
print(p_marker)

ggsave(
  file.path(
    base_path,
    paste0(
      "rocof_",
      tools::file_path_sans_ext(file_name),
      "_markeronly.pdf"
    )
  ),
  plot = p_marker,
  width = 4.0,
  height = 7.5,
  units = "in",
  dpi = 300
)
