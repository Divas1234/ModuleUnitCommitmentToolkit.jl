library(ggplot2)
library(tidyr)

data_matrix1 <- read_csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_op_result_vector.csv")
data_matrix2 <- read_csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_su_result_vector.csv")
data_matrix3 <- read_csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\littlecase\\output\\fcr\\res\\data_sd_result_vector.csv")

result_matrix <- data_matrix1 + data_matrix2[,1:7] + data_matrix3[,1:7]
print(result_matrix)
result_matrix <- do.call(cbind, lapply(result_matrix, function(x) unlist(x)))
print(result_matrix)

df <- as.data.frame(result_matrix)
column_7 <- df[, "x7"]
column_7_df
column_7_df <- data.frame(Index = 1:length(column_7), Value = column_7)
ggplot(column_7_df, aes(x = Index, y = Value)) +
  geom_bar(stat = "identity", fill = "skyblue", color = "blue") +
  labs(title = "Bar Plot of x7 Column with Log Scale", x = "Index", y = "Value (log scale)") +
  theme_minimal()
