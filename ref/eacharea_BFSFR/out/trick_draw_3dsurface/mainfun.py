import numpy as np
from pyecharts.charts import Bar3D, Grid
from pyecharts import options as opts
from pyecharts.globals import CurrentConfig

# Add MathJax to the HTML template
CurrentConfig.ONLINE_HOST = "https://cdn.jsdelivr.net/npm/echarts@latest/dist/"

# Function to read data and prepare it for Bar3D
def prepare_data(file_path):
    with open(file_path, 'r') as file:
        data = file.read()
    data_array = np.array([list(map(float, filter(None, row.split('\t')))) for row in data.split('\n') if row.strip()])
    data_list = []
    for i in range(data_array.shape[0]):
        for j in range(data_array.shape[1]):
            data_list.append([j, i, data_array[i, j]])
    return data_list, data_array

# Prepare data for the first 3D bar chart

data_list1, data_array1 = prepare_data('/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/RocofandNadir_distribution/.data/reformed_result.txt')
data_list2, data_array2 = prepare_data('/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/RocofandNadir_distribution/.data/reformed_result1.txt')

# Create the first 3D bar chart
bar3d_1 = (
    Bar3D()
    .add(
        "",
        data_list1,
        xaxis3d_opts=opts.Axis3DOpts(type_="category", name=r"$t/s$"),
        yaxis3d_opts=opts.Axis3DOpts(type_="category", name=r"$\delta f(t)$"),
        zaxis3d_opts=opts.Axis3DOpts(type_="value", name=r"$P_{out}(t)$"),
    )
    .set_global_opts(
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array1),
            min_=np.min(data_array1),
            range_color=["#0000FF", "#FFFF00"]  # Blue to Yellow color scheme
        ),
        title_opts=opts.TitleOpts(title="Unit Commitment 3D Bar Chart 1"),
    )
)

# Prepare data for the second 3D bar chart
data_list2, data_array2 = prepare_data('/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/RocofandNadir_distribution/.data/reformed_result1.txt')

# Create the second 3D bar chart
bar3d_2 = (
    Bar3D()
    .add(
        "",
        data_list2,
        xaxis3d_opts=opts.Axis3DOpts(
            type_="category",
            name=r"$t/s$",  # LaTeX-like label
            name_textstyle_opts=opts.TextStyleOpts(font_size=14, color="#333"),
        ),
        yaxis3d_opts=opts.Axis3DOpts(
            type_="category",
            name=r"$\delta f(t)$",  # LaTeX-like label
            name_textstyle_opts=opts.TextStyleOpts(font_size=14, color="#333"),
        ),
        zaxis3d_opts=opts.Axis3DOpts(
            type_="value",
            name=r"$P_{out}(t)$",  # LaTeX-like label
            name_textstyle_opts=opts.TextStyleOpts(font_size=14, color="#333"),
        ),
    )
    .set_global_opts(
        visualmap_opts=opts.VisualMapOpts(
            max_=np.max(data_array2),
            min_=np.min(data_array2),
            range_color=["#0000FF", "#FFFF00"]  # Blue to Yellow color scheme
        ),
        title_opts=opts.TitleOpts(title="Unit Commitment 3D Bar Chart 2"),
    )
)


# Layout the two charts side by side
grid = (
    Grid()
    .add(bar3d_1, grid_opts=opts.GridOpts(pos_left="5%", pos_right="55%"))
    .add(bar3d_2, grid_opts=opts.GridOpts(pos_left="55%", pos_right="5%"))
)

# Render the combined chart to an HTML file
html_file_path = "/Users/yuanyiping/Documents/GitHub/RfcucCaseStudies/RocofandNadir_distribution/unit_commitment_3d_bar_charts.html"
grid.render(html_file_path)

# Add MathJax to the rendered HTML file
with open(html_file_path, 'r') as file:
    html_content = file.read()

mathjax_script = """
<script type="text/javascript" id="MathJax-script" async
  src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js">
</script>
"""

# Insert MathJax script before the closing </body> tag
html_content = html_content.replace("</body>", mathjax_script + "</body>")

with open(html_file_path, 'w') as file:
    file.write(html_content)
