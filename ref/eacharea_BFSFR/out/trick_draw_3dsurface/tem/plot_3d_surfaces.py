import numpy as np
from pyecharts.charts import Surface3D, Page
from pyecharts import options as opts

# Read the first data file
with open("data.csv", "r") as file:
    data = file.read()

# Read the second data file
with open("data1.csv", "r") as file:
    data1 = file.read()

# Convert both datasets to numpy arrays
data_array = np.array([list(map(float, filter(None, row.split("\t")))) 
                      for row in data.split("\n") if row.strip()])
data_array1 = np.array([list(map(float, filter(None, row.split("\t")))) 
                       for row in data1.split("\n") if row.strip()])

# Prepare data for both surfaces
def prepare_surface_data(data_array):
    data_list = []
    for i in range(data_array.shape[0]):
        y_scaled = i * (60/data_array.shape[0])
        for j in range(data_array.shape[1]):
            x_scaled = -0.5 + j * (1/data_array.shape[1])
            data_list.append([x_scaled, y_scaled, data_array[i, j]])
    return data_list

data_list1 = prepare_surface_data(data_array)
data_list2 = prepare_surface_data(data_array1)

# Create first surface
surface1 = (
    Surface3D(init_opts=opts.InitOpts(width="800px", height="600px"))
    .add(
        "",
        data_list1,
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
            name="posterior",
            min_=0,
            max_=80
        ),
        grid3d_opts=opts.Grid3DOpts(
            width=100,
            height=100,
            depth=100,
            pos_left='0%',
            pos_right='50%'
        ),
        itemstyle_opts=opts.ItemStyleOpts(
            color="#00FFFF",
            opacity=0.5
        )
    )
    .set_global_opts(
        title_opts=opts.TitleOpts(title="Surface Plot 1"),
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array),
            min_=np.min(data_array),
            range_color=[
                "#FFFFFF",
                "#FFFFF0", 
                "#00FFFF",  # Bright Cyan
                # "#FF69B4",  # Hot Pink
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

# Create second surface
surface2 = (
    Surface3D(init_opts=opts.InitOpts(width="800px", height="600px"))
    .add(
        "",
        data_list2,
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
            name="posterior",
            min_=0,
            max_=80
        ),
        grid3d_opts=opts.Grid3DOpts(
            width=100,
            height=100,
            depth=100,
            pos_left='0%',  # Adjusted position
            pos_right='5%'   # Adjusted position
        ),
        itemstyle_opts=opts.ItemStyleOpts(
            color="#00FFFF",
            opacity=0.5
        )
    )
    .set_global_opts(
        title_opts=opts.TitleOpts(title="Surface Plot 2"),
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array),
            min_=np.min(data_array),
            range_color=[
                "#FFFFFF",
                "#FFFFF0",                 
                "#00FFFF",  # Bright Cyan
                # "#FF69B4",  # Hot Pink
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

# Save surfaces separately
surface1.render("./surface1.html")
surface2.render("./surface2.html")

# Create a page to contain both surfaces
page = Page(layout=Page.SimplePageLayout)
page.add(surface1, surface2)

# Render the combined charts
page.render("./combined_3d_surface_chart.html")
