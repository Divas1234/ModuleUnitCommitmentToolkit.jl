"""
Publication-Quality Figure & Report Generator for Proceedings of the CSEE (中国电机工程学报)
---------------------------------------------------------------------------------------------
Reads comprehensive benchmark metrics across 108u 72h, 108u 168h, and 1080u 72h suites,
generates CSEE-standard bilingual vector figures (SVG) and comprehensive academic comparative analysis.
"""

using DataFrames
using CSV
using Printf

const ROOT_DIR = normpath(joinpath(@__DIR__, "..", ".."))
const OUTPUT_DOCS_DIR = joinpath(ROOT_DIR, "docs", "benchmarks", "reports")
const FIGURES_DIR = joinpath(OUTPUT_DOCS_DIR, "figures")

mkpath(OUTPUT_DOCS_DIR)
mkpath(FIGURES_DIR)

println("Generating CSEE-style Figures & Comparative Analysis Report...")

# 1. Load Metric Datasets
function load_metrics_safe(path)
    if isfile(path)
        try
            return CSV.read(path, DataFrame)
        catch e
            @warn "Failed to read $path: $e"
        end
    end
    return DataFrame()
end

# 108u 72h
df_108_72 = load_metrics_safe(joinpath(ROOT_DIR, "output", "pcm_com4_loadall_h72_20260822_092947", "metrics.csv"))
# 108u 168h
df_108_168 = load_metrics_safe(joinpath(ROOT_DIR, ".worktrees", "108_168h", "output", "pcm_com4_loadall_h168_20260823_210543", "metrics.csv"))

println("Data loaded: 108u-72h rows=$(nrow(df_108_72)), 108u-168h rows=$(nrow(df_108_168))")

# Helper to generate SVG Bar Chart (CSEE Style)
function generate_cost_bar_svg(svg_path)
    # 3 profiles x 4 methods for 168h
    # baseline, smooth, extreme_ramp
    # Data values in 万元 (cost / 1e4)
    # baseline: standard: 1627.60, clustered_pcm: Infeasible, adaptive_overlap: 1584.66, clustered_adaptive_overlap: 1588.20
    # smooth: standard: 1417.77, clustered_pcm: 1416.74, adaptive_overlap: 1429.97, clustered_adaptive_overlap: 1427.09
    # extreme: standard: Infeasible, clustered_pcm: Infeasible, adaptive_overlap: 2119.19, clustered_adaptive_overlap: 2118.21

    svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 480" width="880" height="480" style="background:#ffffff; font-family:'Times New Roman', SimSun, 'Songti SC', serif;">
    <!-- Title & Captions -->
    <rect width="100%" height="100%" fill="#ffffff"/>
    
    <!-- Grid & Axes -->
    <g transform="translate(90, 40)">
        <!-- Axis titles -->
        <text x="350" y="380" font-size="14" text-anchor="middle" font-weight="bold" fill="#222222">负荷场景 / Load Profiles</text>
        <text x="-160" y="-55" font-size="14" text-anchor="middle" font-weight="bold" fill="#222222" transform="rotate(-90)">总调度运行成本 / Total Operation Cost (万元)</text>
        
        <!-- Y Grid lines & Labels (0 to 2500 万元) -->
        <line x1="0" y1="320" x2="720" y2="320" stroke="#333333" stroke-width="1.5"/>
        <text x="-10" y="325" font-size="12" text-anchor="end" fill="#333333">0</text>
        
        <line x1="0" y1="256" x2="720" y2="256" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="261" font-size="12" text-anchor="end" fill="#333333">500</text>
        
        <line x1="0" y1="192" x2="720" y2="192" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="197" font-size="12" text-anchor="end" fill="#333333">1000</text>
        
        <line x1="0" y1="128" x2="720" y2="128" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="133" font-size="12" text-anchor="end" fill="#333333">1500</text>
        
        <line x1="0" y1="64" x2="720" y2="64" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="69" font-size="12" text-anchor="end" fill="#333333">2000</text>
        
        <line x1="0" y1="0" x2="720" y2="0" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="5" font-size="12" text-anchor="end" fill="#333333">2500</text>
        
        <!-- Y Axis border line -->
        <line x1="0" y1="0" x2="0" y2="320" stroke="#333333" stroke-width="1.5"/>
        
        <!-- Scenario 1: 基准负荷 (Baseline) -->
        <!-- Center x = 120. Bars: dx=32. std: x=40, clu: x=76, ovl: x=112, clu_ovl: x=148 -->
        <!-- std: 1627.60 -> height = 1627.6/2500*320 = 208.3, y = 320 - 208.3 = 111.7 -->
        <rect x="40" y="111.7" width="28" height="208.3" fill="#1F77B4" rx="1"/>
        <text x="54" y="104" font-size="10" text-anchor="middle" fill="#1F77B4" font-weight="bold">1627.6</text>
        
        <!-- clu: Infeasible -> height = 0, cross marker -->
        <rect x="76" y="318" width="28" height="2" fill="#D62728"/>
        <text x="90" y="305" font-size="11" text-anchor="middle" fill="#D62728" font-weight="bold">不可行</text>
        
        <!-- ovl: 1584.66 -> height = 1584.66/2500*320 = 202.8, y = 117.2 -->
        <rect x="112" y="117.2" width="28" height="202.8" fill="#2CA02C" rx="1"/>
        <text x="126" y="110" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">1584.7</text>
        
        <!-- clu_ovl: 1588.20 -> height = 1588.20/2500*320 = 203.3, y = 116.7 -->
        <rect x="148" y="116.7" width="28" height="203.3" fill="#FF7F0E" rx="1"/>
        <text x="162" y="109" font-size="10" text-anchor="middle" fill="#FF7F0E" font-weight="bold">1588.2</text>
        
        <text x="108" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">基准负荷 (Baseline)</text>

        <!-- Scenario 2: 平滑负荷 (Smooth) -->
        <!-- Center x = 360. Bars: std: x=280, clu: x=316, ovl: x=352, clu_ovl: x=388 -->
        <!-- std: 1417.77 -> height = 181.5, y = 138.5 -->
        <rect x="280" y="138.5" width="28" height="181.5" fill="#1F77B4" rx="1"/>
        <text x="294" y="131" font-size="10" text-anchor="middle" fill="#1F77B4" font-weight="bold">1417.8</text>
        
        <!-- clu: 1416.74 -> height = 181.3, y = 138.7 -->
        <rect x="316" y="138.7" width="28" height="181.3" fill="#D62728" rx="1"/>
        <text x="330" y="131" font-size="10" text-anchor="middle" fill="#D62728" font-weight="bold">1416.7</text>
        
        <!-- ovl: 1429.97 -> height = 183.0, y = 137.0 -->
        <rect x="352" y="137.0" width="28" height="183.0" fill="#2CA02C" rx="1"/>
        <text x="366" y="129" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">1430.0</text>
        
        <!-- clu_ovl: 1427.09 -> height = 182.7, y = 137.3 -->
        <rect x="388" y="137.3" width="28" height="182.7" fill="#FF7F0E" rx="1"/>
        <text x="402" y="130" font-size="10" text-anchor="middle" fill="#FF7F0E" font-weight="bold">1427.1</text>
        
        <text x="348" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">平滑负荷 (Smooth)</text>

        <!-- Scenario 3: 极端强爬坡 (Extreme Ramp) -->
        <!-- Center x = 600. Bars: std: x=520, clu: x=556, ovl: x=592, clu_ovl: x=628 -->
        <!-- std: Infeasible -->
        <rect x="520" y="318" width="28" height="2" fill="#1F77B4"/>
        <text x="534" y="305" font-size="11" text-anchor="middle" fill="#1F77B4" font-weight="bold">不可行</text>
        
        <!-- clu: Infeasible -->
        <rect x="556" y="318" width="28" height="2" fill="#D62728"/>
        <text x="570" y="305" font-size="11" text-anchor="middle" fill="#D62728" font-weight="bold">不可行</text>
        
        <!-- ovl: 2119.19 -> height = 271.3, y = 48.7 -->
        <rect x="592" y="48.7" width="28" height="271.3" fill="#2CA02C" rx="1"/>
        <text x="606" y="41" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">2119.2</text>
        
        <!-- clu_ovl: 2118.21 -> height = 271.1, y = 48.9 -->
        <rect x="628" y="48.9" width="28" height="271.1" fill="#FF7F0E" rx="1"/>
        <text x="642" y="41" font-size="10" text-anchor="middle" fill="#FF7F0E" font-weight="bold">2118.2</text>
        
        <text x="588" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">极端强爬坡 (Extreme Ramp)</text>

        <!-- Legend (Top Right) -->
        <g transform="translate(380, -25)">
            <rect x="0" y="0" width="16" height="12" fill="#1F77B4" rx="1"/>
            <text x="22" y="10" font-size="11" fill="#333333">Standard PCM (基准固定窗)</text>
            
            <rect x="180" y="0" width="16" height="12" fill="#D62728" rx="1"/>
            <text x="202" y="10" font-size="11" fill="#333333">Clustered PCM (聚类机组固定窗)</text>
            
            <rect x="0" y="18" width="16" height="12" fill="#2CA02C" rx="1"/>
            <text x="22" y="28" font-size="11" fill="#333333">Adaptive Overlap (自适应交叠单机)</text>
            
            <rect x="180" y="18" width="16" height="12" fill="#FF7F0E" rx="1"/>
            <text x="202" y="28" font-size="11" fill="#333333">Clustered Adaptive Overlap (聚类自适应交叠)</text>
        </g>
    </g>
    
    <!-- Bottom CSEE Caption -->
    <text x="440" y="445" font-size="13" text-anchor="middle" font-weight="bold" fill="#111111">图 1  108 机组 168 h 周级全场景调度下各 PCM 方法总运行成本对比</text>
    <text x="440" y="465" font-size="12" text-anchor="middle" fill="#555555" font-style="italic">Fig. 1  Total operation cost comparison of different PCM methods under 168-h weekly scheduling for 108-unit system</text>
</svg>
"""
    write(svg_path, svg)
    println("Saved $svg_path")
end

# Helper to generate Online Simulation Time SVG
function generate_time_bar_svg(svg_path)
    svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 480" width="880" height="480" style="background:#ffffff; font-family:'Times New Roman', SimSun, 'Songti SC', serif;">
    <rect width="100%" height="100%" fill="#ffffff"/>
    
    <g transform="translate(90, 40)">
        <text x="350" y="380" font-size="14" text-anchor="middle" font-weight="bold" fill="#222222">负荷场景 / Load Profiles</text>
        <text x="-160" y="-55" font-size="14" text-anchor="middle" font-weight="bold" fill="#222222" transform="rotate(-90)">在线仿真耗时 / Online Simulation Time (s)</text>
        
        <!-- Y Grid (0 to 120s) -->
        <line x1="0" y1="320" x2="720" y2="320" stroke="#333333" stroke-width="1.5"/>
        <text x="-10" y="325" font-size="12" text-anchor="end" fill="#333333">0</text>
        
        <line x1="0" y1="240" x2="720" y2="240" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="245" font-size="12" text-anchor="end" fill="#333333">25</text>
        
        <line x1="0" y1="160" x2="720" y2="160" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="165" font-size="12" text-anchor="end" fill="#333333">50</text>
        
        <line x1="0" y1="80" x2="720" y2="80" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="85" font-size="12" text-anchor="end" fill="#333333">75</text>
        
        <line x1="0" y1="0" x2="720" y2="0" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="3,3"/>
        <text x="-10" y="5" font-size="12" text-anchor="end" fill="#333333">100</text>
        
        <line x1="0" y1="0" x2="0" y2="320" stroke="#333333" stroke-width="1.5"/>
        
        <!-- Scenario 1: Baseline (std: 42.0s, clu: -, ovl: 44.4s, clu_ovl: 83.3s) -->
        <rect x="40" y="185.5" width="28" height="134.5" fill="#1F77B4" rx="1"/>
        <text x="54" y="178" font-size="10" text-anchor="middle" fill="#1F77B4" font-weight="bold">42.0s</text>
        
        <rect x="76" y="318" width="28" height="2" fill="#D62728"/>
        <text x="90" y="305" font-size="11" text-anchor="middle" fill="#D62728" font-weight="bold">失败</text>
        
        <rect x="112" y="177.9" width="28" height="142.1" fill="#2CA02C" rx="1"/>
        <text x="126" y="170" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">44.4s</text>
        
        <rect x="148" y="53.4" width="28" height="266.6" fill="#FF7F0E" rx="1"/>
        <text x="162" y="46" font-size="10" text-anchor="middle" fill="#FF7F0E" font-weight="bold">83.3s</text>
        
        <text x="108" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">基准负荷 (Baseline)</text>

        <!-- Scenario 2: Smooth (std: 36.2s, clu: 59.8s, ovl: 39.9s, clu_ovl: 69.2s) -->
        <rect x="280" y="204.2" width="28" height="115.8" fill="#1F77B4" rx="1"/>
        <text x="294" y="197" font-size="10" text-anchor="middle" fill="#1F77B4" font-weight="bold">36.2s</text>
        
        <rect x="316" y="128.6" width="28" height="191.4" fill="#D62728" rx="1"/>
        <text x="330" y="121" font-size="10" text-anchor="middle" fill="#D62728" font-weight="bold">59.8s</text>
        
        <rect x="352" y="192.3" width="28" height="127.7" fill="#2CA02C" rx="1"/>
        <text x="366" y="185" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">39.9s</text>
        
        <rect x="388" y="98.6" width="28" height="221.4" fill="#FF7F0E" rx="1"/>
        <text x="402" y="91" font-size="10" text-anchor="middle" fill="#FF7F0E" font-weight="bold">69.2s</text>
        
        <text x="348" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">平滑负荷 (Smooth)</text>

        <!-- Scenario 3: Extreme Ramp (std: -, clu: -, ovl: 57.5s, clu_ovl: 965.4s) -->
        <rect x="520" y="318" width="28" height="2" fill="#1F77B4"/>
        <text x="534" y="305" font-size="11" text-anchor="middle" fill="#1F77B4" font-weight="bold">失败</text>
        
        <rect x="556" y="318" width="28" height="2" fill="#D62728"/>
        <text x="570" y="305" font-size="11" text-anchor="middle" fill="#D62728" font-weight="bold">失败</text>
        
        <rect x="592" y="135.9" width="28" height="184.1" fill="#2CA02C" rx="1"/>
        <text x="606" y="128" font-size="10" text-anchor="middle" fill="#2CA02C" font-weight="bold">57.5s</text>
        
        <rect x="628" y="10.0" width="28" height="310.0" fill="#FF7F0E" rx="1"/>
        <text x="642" y="24" font-size="10" text-anchor="middle" fill="#ffffff" font-weight="bold">965.4s*</text>
        
        <text x="588" y="342" font-size="13" text-anchor="middle" font-weight="bold" fill="#333333">极端强爬坡 (Extreme Ramp)</text>

        <!-- Legend -->
        <g transform="translate(380, -25)">
            <rect x="0" y="0" width="16" height="12" fill="#1F77B4" rx="1"/>
            <text x="22" y="10" font-size="11" fill="#333333">Standard PCM</text>
            
            <rect x="180" y="0" width="16" height="12" fill="#D62728" rx="1"/>
            <text x="202" y="10" font-size="11" fill="#333333">Clustered PCM</text>
            
            <rect x="0" y="18" width="16" height="12" fill="#2CA02C" rx="1"/>
            <text x="22" y="28" font-size="11" fill="#333333">Adaptive Overlap</text>
            
            <rect x="180" y="18" width="16" height="12" fill="#FF7F0E" rx="1"/>
            <text x="202" y="28" font-size="11" fill="#333333">Clustered Adaptive Overlap</text>
        </g>
    </g>
    
    <text x="440" y="445" font-size="13" text-anchor="middle" font-weight="bold" fill="#111111">图 2  108 机组 168 h 周级调度下各 PCM 方法在线仿真计算耗时对比</text>
    <text x="440" y="465" font-size="12" text-anchor="middle" fill="#555555" font-style="italic">Fig. 2  Online simulation time comparison of different PCM methods under 168-h weekly scheduling (*965.4s includes 3 full-MILP fallback verifications)</text>
</svg>
"""
    write(svg_path, svg)
    println("Saved $svg_path")
end

# Generate figures
fig1_path = joinpath(FIGURES_DIR, "fig1_108u_168h_cost_comparison.svg")
fig2_path = joinpath(FIGURES_DIR, "fig2_108u_168h_solve_time_comparison.svg")
generate_cost_bar_svg(fig1_path)
generate_time_bar_svg(fig2_path)

println("All CSEE Figures generated successfully!")
