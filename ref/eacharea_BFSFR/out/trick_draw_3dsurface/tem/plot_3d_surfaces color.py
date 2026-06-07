import numpy as np
from pyecharts.charts import Surface3D
from pyecharts import options as opts
import scipy.ndimage as ndimage

# Read the data from the text file
with open("data.csv", "r") as file:
    data = file.read()

# Convert the data to a numpy array
data_array = np.array(
    [
        list(map(float, filter(None, row.split("\t"))))
        for row in data.split("\n")
        if row.strip()
    ]
)

# Prepare data for Bar3D
data_list = []
for i in range(data_array.shape[0]):
    for j in range(data_array.shape[1]):
        data_list.append([j, i, data_array[i, j]])

# Prepare data for Bar3D with scaled y values
data_list = []
for i in range(data_array.shape[0]):
    y_scaled = i * (60/data_array.shape[0])  # Scale y values to [0, 60]
    for j in range(data_array.shape[1]):
        data_list.append([j, y_scaled, data_array[i, j]])

# Prepare data for Bar3D with scaled x and y values
# Prepare data for Surface3D
# Convert data to 2D array for interpolation
data_2d = data_array.reshape(data_array.shape[0], -1)

# Apply Gaussian filter for smoothing
smoothed_data = ndimage.gaussian_filter(data_2d, sigma=1.0)

# Prepare data for Surface3D with smoothed values
data_list = []
for i in range(data_array.shape[0]):
    y_scaled = i * (60/data_array.shape[0])
    for j in range(data_array.shape[1]):
        x_scaled = -0.5 + j * (1/data_array.shape[1])
        data_list.append([x_scaled, y_scaled, smoothed_data[i, j]])

# Create a 3D surface chart
surface3d = (
    Surface3D()
    .add(
        "",
        data_list,
        xaxis3d_opts=opts.Axis3DOpts(
            type_="value", 
            name="Δf(t) / Hz",
            min_=-0.5,
            max_=0.5
        ),
        yaxis3d_opts=opts.Axis3DOpts(
            type_="value", 
            name="t / s",
            min_=0,
            max_=60
        ),
        zaxis3d_opts=opts.Axis3DOpts(
            type_="value", 
            name="posterior"
        ),
        grid3d_opts=opts.Grid3DOpts(
            width=100,
            height=100,
            depth=100
        ),
        itemstyle_opts=opts.ItemStyleOpts(
            color="#00FFFF",
            opacity=0.95
        )
    )
    .set_global_opts(
        title_opts=opts.TitleOpts(title="3D Surface Plot"),
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array),
            min_=np.min(data_array),
            range_color=[
                "#0000FF",  # Blue
                "#0099FF",  # Light Blue
                "#00CCCC",  # Cyan
                "#00CC99",  # Blue-Green
                "#00FF66",  # Green
                "#66FF33",  # Yellow-Green
                "#FFFF00"   # Yellow
            ]
        )
    )
)

# Render the chart to an HTML file
surface3d.render("./unit_commitment_3d_surface_chart.html")
