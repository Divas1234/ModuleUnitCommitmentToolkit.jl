# Load required libraries
library(ggplot2)
library(rayshader)
library(reshape2)

# Step 1: Load your CSV data
data <- read.csv("D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\Guassion\\sampledata1.csv", header = TRUE)
data_matrix <- as.matrix(data)

# Optional: Inspect dimensions
print(dim(data_matrix)) # Should be 1201 x 100

# Step 2: Convert matrix to data.frame for ggplot2
# Add row and column indices

# Step 2: Melt matrix to long format for ggplot2
data_long <- melt(data_matrix)
colnames(data_long) <- c("Row", "Col", "Value")

# Step 3: Plot the heatmap
p <- ggplot(data_long, aes(x = Col, y = Row, fill = Value)) +
    geom_tile() +
    scale_fill_viridis_c() +
    labs(x = "Column Index", y = "Row Index", fill = "Value") +
    theme_minimal() +
    theme(
        axis.text = element_blank(),
        axis.ticks = element_blank()
    )

print(p)