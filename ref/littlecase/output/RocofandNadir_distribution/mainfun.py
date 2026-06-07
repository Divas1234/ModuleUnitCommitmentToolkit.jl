import pandas as pd
from pyecharts.charts import Bar3D
from pyecharts import options as opts

# ...existing code...

def read_nadir_files(file_paths):
    data_frames = []
    for file in file_paths:
        with open(file, 'r') as f:
            data = [float(line.strip()) for line in f]
            df = pd.DataFrame(data, columns=['nadir'])
            data_frames.append(df)
    return data_frames

def prepare_data_for_3d_bar(data_frames):
    data = []
    for i, df in enumerate(data_frames):
        for j, value in enumerate(df['nadir']):
            data.append([i, j, value])
    return data

def draw_3d_bar(data):
    bar3d = Bar3D()
    bar3d.add(
        "",
        [[d[0], d[1], d[2]] for d in data],
        xaxis3d_opts=opts.Axis3DOpts(type_="category", name="File Index"),
        yaxis3d_opts=opts.Axis3DOpts(type_="category", name="Data Index"),
        zaxis3d_opts=opts.Axis3DOpts(type_="value", name="Nadir Value"),
    )
    bar3d.set_global_opts(
        visualmap_opts=opts.VisualMapOpts(max_=max([d[2] for d in data])),
        title_opts=opts.TitleOpts(title="3D Bar Chart of Nadir Values"),
    )
    bar3d.render("3d_bar_chart.html")
    print("3D bar chart has been rendered to 3d_bar_chart.html")

import os

# Example usage
if os.name == 'nt':  # Windows
    file_paths = ["bench_nadir_distribution.txt", "enhance_nadir_distribution.txt", "nadir_distribution.txt"]
elif os.name == 'posix': # Unix or Mac
    file_paths = ["bench_nadir_distribution.txt", "enhance_nadir_distribution.txt", "nadir_distribution.txt"]
else:
    file_paths = ["bench_nadir_distribution.txt", "enhance_nadir_distribution.txt", "nadir_distribution.txt"]
data_frames = read_nadir_files(file_paths)
print("Data frames read from files:", data_frames)
data = prepare_data_for_3d_bar(data_frames)
print("Prepared data for 3D bar chart:", data)
draw_3d_bar(data)

# ...existing code...
