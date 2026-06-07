import numpy as np
from pyecharts.charts import Bar3D
from pyecharts import options as opts

# Read the data from the text file
with open(".data/reformed_result1.txt", "r") as file:
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

# Create a 3D bar chart
bar3d = (
    Bar3D()
    .add(
        "",
        data_list,
        xaxis3d_opts=opts.Axis3DOpts(type_="category", name=r"$t/s$"),
        yaxis3d_opts=opts.Axis3DOpts(type_="category", name=r"$\delta f(t)$"),
        zaxis3d_opts=opts.Axis3DOpts(type_="value", name=r"$P_{out}(t)$"),
    )
    .set_global_opts(
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array),
            min_=np.min(data_array),
            # range_color=["#808080", "#FF0000"]  # Grey to Red color scheme
            range_color=[
                "#FFFFFF",  # White
                "#FFFFB2",  # Light Yellow
                "#FFD700",  # Gold
                "#FF4500",  # Orange Red
                "#FF0000",  # Bright Red
            ],  # Brighter color gradient
        ),
        title_opts=opts.TitleOpts(title="Unit Commitment 3D Bar Chart"),
    )
)


# Render the chart to an HTML file
bar3d.render(
    "/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/RocofandNadir_distribution/unit_commitment_3d_bar_chart1.html"
)
