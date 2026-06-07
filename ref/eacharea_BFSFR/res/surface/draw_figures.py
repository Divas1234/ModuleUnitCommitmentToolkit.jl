import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np

# Define the number of rows and columns in your grid
rows = 1201  # Replace with the actual number of rows
cols = 2048  # Replace with the actual number of columns

# Read the CSV files
xdata = pd.read_csv('xdata.csv', header=None).values
ygrid = pd.read_csv('ygrid.csv', header=None).values
zdata = pd.read_csv('zdata_interpolated.csv', header=None).values


# Reshape the data
xdata = xdata.reshape(rows, 1)
ygrid = ygrid.reshape(cols, 1)
zdata = zdata.reshape(rows, cols)


# Create a 3D plot
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')

# Plot the surface
ax.plot_surface(xdata, ygrid, zdata, cmap='viridis')

# Set labels and title
ax.set_xlabel('X Label')
ax.set_ylabel('Y Label')
ax.set_zlabel('Z Label')
ax.set_title('3D Surface Plot')

# Show the plot
plt.show()