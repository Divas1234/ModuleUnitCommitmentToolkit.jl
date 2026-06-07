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

head(data_list[[2]])

max_rows <- list()

for (i in seq_along(data_list)) {
  df <- data_list[[i]]
  row_means <- rowMeans(df, na.rm = TRUE)
  max_index <- which.max(row_means)
  max_rows[[i]] <- df[max_index, ]
}

print(max_rows[[1]])
max_rows_df <- do.call(rbind, max_rows)
dim(max_rows_df)

df_t <- as.data.frame(t(max_rows_df))
colnames(df_t) <- paste0("Row", 1:nrow(max_rows_df))

df_long <- df_t %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "value")

# Create the boxplot
p <- ggplot(df_long, aes(x = variable, y = value)) +
  geom_boxplot() +
  labs(x = "Variable", y = "Value") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) # Rotate x-axis labels for clarity

p
