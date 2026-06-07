import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

# 读取CSV文件
file1 = 'data.csv'
file2 = 'data1.csv'

data1 = pd.read_csv(file1, sep='\t')
data2 = pd.read_csv(file2, sep='\t')

# Create meshgrid for X and Y
x = np.arange(data1.shape[1])  # Columns as X
y = np.arange(data1.shape[0])  # Rows as Y
X, Y = np.meshgrid(x, y)

# Convert DataFrame to NumPy array for Z
Z = data1.values

def plot_surface_with_customization(X, Y, Z, data1, ax):
    """
    Plots a 3D surface with customized settings for transparency, ticks, and labels.
    """
    # Plot the surface
    surf = ax.plot_surface(X, Y, Z, cmap='viridis', edgecolor='none')

    # Set transparency for the background and grid
    ax.xaxis.set_pane_color((1.0, 1.0, 1.0, 0.25))
    ax.yaxis.set_pane_color((1.0, 1.0, 1.0, 0.25))
    ax.zaxis.set_pane_color((1.0, 1.0, 1.0, 0.25))
    ax.grid(True, alpha=0.1)

    # Set custom ticks for X, Y, and Z axes
    ax.set_xticks(np.linspace(0, data1.shape[1] - 1, 7))
    ax.set_xticklabels(np.linspace(0, 60, 7, dtype=int), fontdict={'family': 'Helvetica', 'size': 12})

    ax.set_yticks(np.linspace(0, data1.shape[0] - 1, 7))
    ax.set_yticklabels(np.linspace(0, 60, 7, dtype=int), fontdict={'family': 'Helvetica', 'size': 12})

    # ax.set_zticks(np.linspace(Z.min(), Z.max(), 5))
    ax.set_zticklabels([f"{tick:.2f}" for tick in np.linspace(Z.min(), Z.max(), 5)],
                       fontdict={'family': 'Helvetica', 'size': 12})

    # Adjust Z-label position and set font family
    ax.set_zlabel('Values', labelpad=10, fontdict={'family': 'Helvetica', 'size': 15})
    ax.zaxis.label.set_position((-0.1, 0.5))  # Move Z-label to the left

    # Set font family for other labels
    ax.set_xlabel('Columns', labelpad=10, fontdict={'family': 'Helvetica', 'size': 15})
    ax.set_ylabel('Rows', labelpad=10, fontdict={'family': 'Helvetica', 'size': 15})


    # Set title and labels (optional, can be omitted for cleaner figures)
    # ax.set_title('Surface Plot', pad=20)
    ax.set_xlabel('frequency derivation', labelpad=10)
    ax.set_ylabel('T / s', labelpad=10)
    ax.set_zlabel('Posterior', labelpad=10)

# Create a figure with two subplots
fig = plt.figure(figsize=(8, 4), dpi=100)  # This will create an 800x400 pixel figure

# Create first subplot
ax1 = fig.add_subplot(121, projection='3d')
p1 = plot_surface_with_customization(X, Y, Z, data1, ax1)

# Create second subplot
ax2 = fig.add_subplot(122, projection='3d')
p2 = plot_surface_with_customization(X, Y, data2.values, data2, ax2)

# Adjust layout to prevent overlap
plt.tight_layout()

# Show the figure
plt.show()