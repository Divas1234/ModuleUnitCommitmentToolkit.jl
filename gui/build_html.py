#!/usr/bin/env python3
"""Generate a self-contained HTML dashboard from output data files."""
import csv
import json
import os
import re
import base64
import tomllib
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent.parent / 'output'
CONFIG = Path(__file__).resolve().parent.parent / 'config' / 'runtime_config.toml'
GUI = Path(__file__).resolve().parent

def parse_config():
    text = CONFIG.read_text()
    lines = text.split('\n')
    parsed = tomllib.loads(text)
    key_lines = {}
    current_section = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('#') or not stripped:
            continue
        m = re.match(r'^\[([^\]]+)\]', stripped)
        if m:
            current_section = m.group(1)
            continue
        m = re.match(r'^(\w+)\s*=\s*(.+)$', stripped)
        if m:
            key = m.group(1)
            key_lines[key] = {'line': i, 'section': current_section, 'raw_value': m.group(2).strip()}
    sections = []
    for sec_name in parsed:
        sec_data = parsed[sec_name]
        if not isinstance(sec_data, dict):
            continue
        fields = []
        for k, v in sec_data.items():
            if isinstance(v, dict):
                continue
            t = 'bool' if isinstance(v, bool) else 'number' if isinstance(v, (int, float)) else 'string'
            fields.append({'key': k, 'value': v, 'type': t,
                           'section': sec_name,
                           'line': key_lines.get(k, {}).get('line', -1),
                           'raw_value': key_lines.get(k, {}).get('raw_value', str(v))})
        sections.append({'name': sec_name, 'fields': fields})
    for sec_name in parsed:
        sec_data = parsed[sec_name]
        if not isinstance(sec_data, dict):
            continue
        for k, v in sec_data.items():
            if isinstance(v, dict):
                sections.append({'name': f'{sec_name}.{k}', 'fields': [
                    {'key': fk, 'value': fv,
                     'type': 'bool' if isinstance(fv, bool) else 'number' if isinstance(fv, (int, float)) else 'string',
                     'section': f'{sec_name}.{k}',
                     'line': key_lines.get(fk, {}).get('line', -1),
                     'raw_value': key_lines.get(fk, {}).get('raw_value', str(fv))}
                    for fk, fv in v.items()
                ]})
    return {'sections': sections}

def read_csv(path):
    with open(path) as f:
        reader = csv.reader(f)
        rows = list(reader)
    return rows

def read_txt(path):
    with open(path) as f:
        return f.read()

def main():
    data = {}

    # --- TXT files ---
    data['schedule_txt'] = read_txt(OUTPUT / 'schedule_commitment_result.txt')
    data['bess_txt'] = read_txt(OUTPUT / 'bess_scheduling_result.txt')

    # --- Detail CSVs ---
    details = {}
    for name in ['res_thermalunits', 'res_windunits', 'res_bess_charging', 'res_bess_discharging', 'res_forcedloadcurtailment']:
        p = OUTPUT / 'details_schedule_results' / f'{name}.csv'
        if p.exists():
            details[name] = [float(x[0]) for x in read_csv(p)]
    data['details'] = details

    # --- Comparison summaries ---
    comp_dir = OUTPUT / 'comparison'
    summaries = {}
    iterations = {}
    qualities = {}
    for run_dir in sorted(comp_dir.iterdir()):
        if not run_dir.is_dir():
            continue
        name = run_dir.name
        s = run_dir / 'summary.csv'
        i = run_dir / 'iteration_history.csv'
        q = run_dir / 'power_balance_quality.csv'
        if s.exists():
            summaries[name] = read_csv(s)
        if i.exists():
            iterations[name] = read_csv(i)
        if q.exists():
            qualities[name] = read_csv(q)
    data['summaries'] = summaries
    data['iterations'] = iterations
    data['qualities'] = qualities

    # --- Power balance data (only three_way experiments for manageability) ---
    pb_data = {}
    for algo in ['benchmark_uc', 'benders', 'ccg']:
        algo_dir = OUTPUT / algo
        if not algo_dir.exists():
            continue
        pb_data[algo] = {}
        for run_dir in sorted(algo_dir.iterdir()):
            if not run_dir.is_dir():
                continue
            pb_sub = run_dir / 'power_balance'
            if not pb_sub.exists():
                continue
            run_name = run_dir.name
            pb_data[algo][run_name] = {}
            for csv_file in sorted(pb_sub.glob('*.csv')):
                key = csv_file.stem
                rows = read_csv(csv_file)
                pb_data[algo][run_name][key] = rows
    data['power_balance'] = pb_data

    # --- Config ---
    data['config'] = parse_config()

    # --- SVGs from comparison runs ---
    svgs = {}
    for run_dir in sorted(comp_dir.iterdir()):
        if not run_dir.is_dir():
            continue
        name = run_dir.name
        svgs[name] = {}
        for svg_file in sorted(run_dir.glob('*.svg')):
            svgs[name][svg_file.stem] = base64.b64encode(svg_file.read_bytes()).decode()
    data['svgs'] = svgs

    # --- Generate HTML ---
    html = f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Unit Commitment Results Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
:root {{
  --bg:#f0f2f5;--card-bg:#fff;--text:#1e293b;--text2:#64748b;--text3:#94a3b8;--border:#e2e8f0;--border2:#f1f5f9;
  --header-from:#0f172a;--header-to:#1e3a5f;--accent:#2563eb;--accent-bg:#eff6ff;--hover-bg:#f8fafc;
  --pre-bg:#1e293b;--pre-fg:#e2e8f0;--th-bg:#f8fafc;--section-bg:#f8fafc;--section-hdr:#e2e8f0;--section-text:#334155;
}}
[data-theme="dark"] {{
  --bg:#111827;--card-bg:#1f2937;--text:#e5e7eb;--text2:#9ca3af;--text3:#6b7280;--border:#374151;--border2:#1f2937;
  --header-from:#030712;--header-to:#111827;--accent:#3b82f6;--accent-bg:#1e3a5f;--hover-bg:#283548;
  --pre-bg:#030712;--pre-fg:#d1d5db;--th-bg:#1f2937;--section-bg:#1f2937;--section-hdr:#374151;--section-text:#d1d5db;
}}
[data-theme="forest"] {{
  --bg:#ecfdf5;--card-bg:#fff;--text:#064e3b;--text2:#64748b;--text3:#94a3b8;--border:#d1fae5;--border2:#ecfdf5;
  --header-from:#064e3b;--header-to:#059669;--accent:#059669;--accent-bg:#d1fae5;--hover-bg:#f0fdf4;
  --pre-bg:#064e3b;--pre-fg:#d1fae5;--th-bg:#f0fdf4;--section-bg:#f0fdf4;--section-hdr:#d1fae5;--section-text:#065f46;
}}
[data-theme="sunset"] {{
  --bg:#fff7ed;--card-bg:#fff;--text:#431407;--text2:#9a3412;--text3:#c2410c;--border:#fed7aa;--border2:#fff7ed;
  --header-from:#7c2d12;--header-to:#c2410c;--accent:#ea580c;--accent-bg:#ffedd5;--hover-bg:#fff7ed;
  --pre-bg:#431407;--pre-fg:#fed7aa;--th-bg:#fffbeb;--section-bg:#fffbeb;--section-hdr:#fed7aa;--section-text:#9a3412;
}}
[data-theme="ocean"] {{
  --bg:#f0f9ff;--card-bg:#fff;--text:#0c4a6e;--text2:#64748b;--text3:#94a3b8;--border:#e0f2fe;--border2:#f0f9ff;
  --header-from:#0c4a6e;--header-to:#0284c7;--accent:#0284c7;--accent-bg:#e0f2fe;--hover-bg:#f0f9ff;
  --pre-bg:#0c4a6e;--pre-fg:#bae6fd;--th-bg:#f0f9ff;--section-bg:#f0f9ff;--section-hdr:#bae6fd;--section-text:#0369a1;
}}

* {{ margin:0;padding:0;box-sizing:border-box; }}
body {{ font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text); }}
.header {{ background:linear-gradient(135deg,var(--header-from),var(--header-to));color:#fff;padding:20px 32px;display:flex;justify-content:space-between;align-items:center; }}
.header h1 {{ font-size:20px;font-weight:600; }}
.header span {{ opacity:.6;font-size:13px; }}
.header-left {{ display:flex;flex-direction:column; }}
.theme-switcher {{ display:flex;gap:4px; }}
.theme-dot {{ width:22px;height:22px;border-radius:50%;border:2px solid rgba(255,255,255,.3);cursor:pointer;transition:all .15s; }}
.theme-dot:hover {{ border-color:#fff;transform:scale(1.15); }}
.theme-dot.active {{ border-color:#fff;box-shadow:0 0 0 2px rgba(255,255,255,.5); }}
.nav {{ background:var(--card-bg);border-bottom:1px solid var(--border);padding:0 24px;display:flex;gap:0;overflow-x:auto;position:sticky;top:0;z-index:10; }}
.nav-btn {{ padding:12px 18px;border:none;background:none;cursor:pointer;font-size:13px;color:var(--text2);border-bottom:2px solid transparent;white-space:nowrap;transition:all .15s; }}
.nav-btn:hover {{ color:var(--accent); }}
.nav-btn.active {{ color:var(--accent);border-bottom-color:var(--accent);font-weight:600; }}
.nav-drop {{ position:relative;display:inline-flex; }}
.nav-drop .drop-menu {{ display:none;position:absolute;top:100%;left:0;background:var(--card-bg);border:1px solid var(--border);border-radius:0 0 8px 8px;box-shadow:0 4px 12px rgba(0,0,0,.1);min-width:160px;z-index:50; }}
.nav-drop.open .drop-menu {{ display:block; }}
.drop-item {{ display:block;width:100%;padding:10px 16px;border:none;border-bottom:1px solid var(--border2);background:none;font-size:12px;color:var(--text2);cursor:pointer;text-align:left; }}
.drop-item:hover {{ background:var(--hover-bg);color:var(--accent); }}
.drop-item:last-child {{ border-bottom:none;border-radius:0 0 8px 8px; }}
.drop-item.active {{ background:var(--accent-bg);color:var(--accent);font-weight:600; }}
.sub-nav {{ display:flex;gap:4px;padding:4px 0; }}
.sub-nav-btn {{ padding:5px 14px;border:1px solid var(--border);border-radius:6px;background:var(--card-bg);font-size:12px;color:var(--text2);cursor:pointer;transition:all .15s; }}
.sub-nav-btn:hover {{ border-color:var(--accent);color:var(--accent); }}
.sub-nav-btn.active {{ background:var(--accent);color:#fff;border-color:var(--accent); }}
.main {{ padding:20px 28px;max-width:1440px;margin:0 auto; }}
.tab {{ display:none; }}
.tab.active {{ display:block; }}
.sub-tab {{ display:none; }}
.sub-tab.active {{ display:block; }}
.card {{ background:var(--card-bg);border-radius:10px;box-shadow:0 1px 2px rgba(0,0,0,.06);padding:20px;margin-bottom:18px; }}
.card h2 {{ font-size:15px;margin-bottom:14px;color:var(--text);display:flex;align-items:center;gap:8px; }}
.card h2::before {{ content:'';width:4px;height:16px;background:var(--accent);border-radius:2px;flex-shrink:0; }}
.metrics {{ display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:14px;margin-bottom:18px; }}
.metric {{ background:var(--card-bg);border-radius:10px;padding:16px 18px;box-shadow:0 1px 2px rgba(0,0,0,.06); }}
.metric .label {{ font-size:11px;color:var(--text3);text-transform:uppercase;letter-spacing:.5px; }}
.metric .value {{ font-size:26px;font-weight:700;color:var(--text);margin-top:2px; }}
table {{ width:100%;border-collapse:collapse;font-size:12px; }}
th,td {{ padding:8px 10px;text-align:left;border-bottom:1px solid var(--border2); }}
th {{ background:var(--th-bg);color:var(--text2);font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.3px; }}
tr:hover td {{ background:var(--hover-bg); }}
.badge {{ display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600; }}
.badge-ok {{ background:#dcfce7;color:#16a34a; }}
.badge-warn {{ background:#fef3c7;color:#d97706; }}
.badge-err {{ background:#fee2e2;color:#dc2626; }}
.badge-info {{ background:#dbeafe;color:#2563eb; }}
.gap-good {{ color:#16a34a;font-weight:600; }}
.gap-bad {{ color:#dc2626;font-weight:600; }}
.ctrl {{ display:flex;gap:10px;align-items:center;margin-bottom:14px;flex-wrap:wrap; }}
.ctrl label {{ font-size:12px;color:var(--text2); }}
.ctrl select {{ padding:5px 10px;border:1px solid var(--border);border-radius:6px;font-size:12px;background:var(--card-bg);color:var(--text); }}
.ctrl select:focus {{ outline:none;border-color:var(--accent); }}
.chart-box {{ position:relative;height:280px;margin:10px 0 6px; }}
.chart-box.small {{ height:200px; }}
.chart-table {{ max-height:220px;overflow-y:auto;margin-top:4px; }}
pre {{ font-family:'SF Mono',Monaco,monospace;font-size:11px;line-height:1.5;overflow-x:auto;white-space:pre;max-height:520px;overflow-y:auto;background:var(--pre-bg);color:var(--pre-fg);padding:14px;border-radius:8px; }}
.settings-grid {{ display:grid;grid-template-columns:repeat(auto-fill,minmax(380px,1fr));gap:16px; }}
.settings-section {{ background:var(--section-bg);border:1px solid var(--border);border-radius:8px;overflow:hidden; }}
.settings-section h3 {{ font-size:13px;padding:10px 14px;background:var(--section-hdr);color:var(--section-text);font-weight:600; }}
.settings-section .fields {{ padding:10px 14px; }}
.field {{ display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border2);gap:10px; }}
.field:last-child {{ border-bottom:none; }}
.field label {{ font-size:12px;color:var(--text);flex:1;cursor:pointer; }}
.field input[type="text"],.field input[type="number"] {{ width:160px;padding:4px 8px;border:1px solid var(--border);border-radius:4px;font-size:12px;font-family:'SF Mono',Monaco,monospace;text-align:right;background:var(--card-bg);color:var(--text); }}
.field input:focus {{ outline:none;border-color:var(--accent); }}
.field input[type="checkbox"] {{ width:16px;height:16px;accent-color:var(--accent); }}
.toggle {{ position:relative;display:inline-block;width:40px;height:22px;cursor:pointer;flex-shrink:0;vertical-align:middle; }}
.toggle input {{ display:none; }}
.toggle .slider {{ position:absolute;top:0;left:0;right:0;bottom:0;background:#cbd5e1;border-radius:11px;transition:background .2s; }}
.toggle .slider::before {{ content:'';position:absolute;width:16px;height:16px;left:3px;top:3px;background:#fff;border-radius:50%;transition:transform .2s; }}
.toggle input:checked+.slider {{ background:var(--accent); }}
.toggle input:checked+.slider::before {{ transform:translateX(18px); }}
.save-bar {{ display:flex;align-items:center;gap:12px;margin-bottom:16px; }}
.save-bar button {{ padding:8px 20px;background:var(--accent);color:#fff;border:none;border-radius:6px;font-size:13px;cursor:pointer;font-weight:600; }}
.save-bar button:hover {{ opacity:.85; }}
.save-bar button:disabled {{ opacity:.5;cursor:not-allowed; }}
.save-bar .msg {{ font-size:12px; }}
.save-bar .msg.ok {{ color:#16a34a; }}
.save-bar .msg.err {{ color:#dc2626; }}
.report-grid {{ display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px; }}
.report-grid .report-item {{ background:var(--card-bg);border:1px solid var(--border);border-radius:8px;overflow:hidden; }}
.report-grid .report-item h3 {{ font-size:12px;padding:8px 12px;background:var(--th-bg);color:var(--text2);font-weight:600;border-bottom:1px solid var(--border); }}
.report-grid .report-item img {{ width:100%;display:block; }}
.report-tabs,.view-tabs {{ display:flex;gap:6px;margin-bottom:10px;flex-wrap:wrap; }}
.report-tab,.view-tab {{ padding:5px 12px;border:1px solid var(--border);border-radius:6px;background:var(--card-bg);font-size:12px;color:var(--text2);cursor:pointer;transition:all .15s; }}
.report-tab:hover,.view-tab:hover {{ border-color:var(--accent);color:var(--accent); }}
.report-tab.active,.view-tab.active {{ background:var(--accent);color:#fff;border-color:var(--accent); }}
.report-display,.view-display {{ background:var(--card-bg);border:1px solid var(--border);border-radius:8px;overflow:hidden; }}
.report-display img,.view-display img {{ width:100%;height:280px;display:block;object-fit:contain;background:var(--hover-bg); }}
.export-btn {{ padding:3px 10px;border:1px solid var(--border);border-radius:4px;background:var(--card-bg);font-size:11px;color:var(--text2);cursor:pointer;margin-left:auto; }}
.export-btn:hover {{ border-color:var(--accent);color:var(--accent); }}
.card-hdr {{ display:flex;align-items:center;gap:8px;margin-bottom:14px; }}
.card-hdr h2 {{ margin-bottom:0; }}
.toggle-table {{ padding:3px 8px;border:1px solid var(--border);border-radius:4px;background:var(--card-bg);font-size:10px;color:var(--text2);cursor:pointer;margin-left:auto;transition:all .15s; }}
.toggle-table:hover {{ border-color:var(--accent);color:var(--accent); }}
.table-wrap.collapsed {{ display:none; }}
.view-chart-box {{ height:200px; }}
</style>
</head>
<body>

<div class="header">
  <div class="header-left">
    <h1>Unit Commitment Results</h1>
    <span>Benchmark UC · Benders Decomposition · CCG — Performance &amp; Solution Quality</span>
  </div>
  <div class="theme-switcher" id="theme-switcher"></div>
</div>

<div class="nav" id="nav"></div>

<div class="main">
<div id="tab-overview" class="tab active">
  <div class="metrics" id="overview-metrics"></div>
  <div class="card"><h2>Algorithm Comparison Summary</h2><div style="overflow-x:auto"><table id="summary-table"></table></div></div>
</div>

<div id="tab-power" class="tab">
  <div class="card"><div class="card-hdr"><h2>Power Balance Detail</h2><button class="export-btn" onclick="exportChart(this)">Export PNG</button></div>
    <div class="ctrl"><label>Run</label><select id="pb-run"></select><label>Algorithm</label><select id="pb-algo"></select><label>Scenarios</label><select id="pb-scen"></select><label>View Scenario</label><select id="pb-single"></select></div>
    <div class="chart-box"><canvas id="pb-chart"></canvas></div>
    <div style="overflow-x:auto"><table id="pb-table"></table></div>
  </div>
</div>

<div id="tab-quality" class="tab">
  <div class="card"><div class="card-hdr"><h2>Results & Reports</h2><button class="export-btn" onclick="exportChart(this)">Export PNG</button></div>
    <div class="ctrl"><label>Run</label><select id="ql-run"></select><label>Algorithm</label><select id="ql-algo"><option value="">All</option></select><label>Scenarios</label><select id="ql-scen"><option value="">All</option></select></div>
    <div class="view-tabs" id="ql-view-tabs"></div>
    <div class="view-display" id="ql-view-display"><div class="chart-box"><canvas id="ql-chart"></canvas></div></div>
  </div>
  <div class="card"><h2>Power Balance Quality</h2><div style="overflow-x:auto"><table id="ql-quality-table"></table></div></div>
  <div class="card"><h2>Algorithm Comparison Summary</h2><div style="overflow-x:auto"><table id="ql-summary-table"></table></div></div>
  <div class="card"><h2>Iteration History</h2><div style="overflow-x:auto"><table id="ql-iter-table"></table></div></div>
</div>

<div id="tab-details" class="tab">
  <div id="sub-details-chart" class="sub-tab active">
    <div class="card"><div class="card-hdr"><h2>Detailed Schedule — Time Series</h2><button class="export-btn" onclick="exportChart(this)">Export PNG</button></div><div class="chart-box"><canvas id="det-chart"></canvas></div><div style="overflow-x:auto"><table id="det-table"></table></div></div>
  </div>
  <div id="sub-details-uc" class="sub-tab">
    <div class="card"><h2>Schedule Commitment Result</h2><pre id="uc-pre"></pre></div>
  </div>
  <div id="sub-details-bess" class="sub-tab">
    <div class="card"><h2>BESS Scheduling Result</h2><pre id="bess-pre"></pre></div>
  </div>
</div>

<div id="tab-settings" class="tab">
  <div class="card"><h2>Runtime Configuration</h2>
    <div class="save-bar">
      <button id="save-config-btn" onclick="saveConfig()">Save Changes</button>
      <span class="msg" id="save-msg"></span>
    </div>
    <div class="settings-grid" id="settings-grid"></div>
  </div>
</div>
</div>

<script>
const DATA = {json.dumps(data, ensure_ascii=False)};

Chart.defaults.font.family = '-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,sans-serif';
Chart.defaults.font.size = 12;
Chart.defaults.color = '#6b7280';
Chart.defaults.borderColor = '#e5e7eb';
Chart.defaults.plugins.tooltip.backgroundColor = 'rgba(0,0,0,.8)';
Chart.defaults.plugins.tooltip.titleFont = {{size:12,weight:'600'}};
Chart.defaults.plugins.tooltip.bodyFont = {{size:12}};
Chart.defaults.plugins.tooltip.padding = 8;
Chart.defaults.plugins.tooltip.cornerRadius = 4;
Chart.defaults.plugins.tooltip.displayColors = true;
Chart.defaults.plugins.tooltip.boxPadding = 2;
Chart.defaults.plugins.tooltip.caretSize = 0;

const CHART_GRID = {{color:'rgba(0,0,0,.08)',lineWidth:.5,drawBorder:false}};
const CHART_TICKS = {{font:{{size:11}},color:'#9ca3af',padding:6}};
const CHART_TICKS_X = {{font:{{size:10}},color:'#9ca3af',padding:2,autoSkip:false}};
const CHART_TITLE = {{font:{{size:11,weight:'500'}},color:'#6b7280',padding:{{top:2,bottom:2}}}};
const CHART_PLUGINS = {{legend:{{position:'bottom',labels:{{boxWidth:8,font:{{size:11}},padding:12,usePointStyle:true,pointStyleWidth:8,color:'#6b7280'}}}}}};
Chart.defaults.scales.linear.grid = CHART_GRID;
Chart.defaults.scales.linear.ticks = CHART_TICKS;
Chart.defaults.scales.logarithmic.grid = CHART_GRID;
Chart.defaults.scales.logarithmic.ticks = CHART_TICKS;
Chart.defaults.plugins.tooltip.callbacks = {{
  label: function(ctx) {{
    let label = ctx.dataset.label || '';
    if (label) label += ': ';
    const v = ctx.parsed.y;
    if (v === null || v === undefined) return label + '—';
    if (Math.abs(v) >= 1e6) label += v.toExponential(3);
    else if (Math.abs(v) >= 1000) label += v.toLocaleString('en-US', {{maximumFractionDigits:1}});
    else if (Math.abs(v) < 0.01 && v !== 0) label += v.toExponential(2);
    else label += v.toLocaleString('en-US', {{maximumFractionDigits:4}});
    return label;
  }}
}};

const TABS = [
  {{id:'overview',label:'Overview'}},
  {{id:'power',label:'Power Balance'}},
  {{id:'quality',label:'Quality Metrics'}},
  {{id:'details',label:'Detailed Results'}},
  {{id:'settings',label:'Settings'}},
];

let activeDetailTab = 'details-chart';

function $(id) {{ return document.getElementById(id); }}

function exportChart(btn) {{
  const card = btn.closest('.card');
  const canvas = card.querySelector('canvas');
  const svgImg = card.querySelector('.view-display img');
  if (canvas) {{
    const a = document.createElement('a');
    a.download = 'chart_'+Date.now()+'.png';
    a.href = canvas.toDataURL('image/png');
    a.click();
  }} else if (svgImg) {{
    const a = document.createElement('a');
    a.download = 'chart_'+Date.now()+'.svg';
    a.href = svgImg.src;
    a.click();
  }}
}}

function init() {{
  const saved = (() => {{ try {{ return localStorage.getItem('uc-theme'); }} catch(e) {{ return null; }} }})();
  if (saved) document.documentElement.dataset.theme = saved;
  buildThemeSwitcher();
  buildNav();
  renderOverview();
  renderPowerBalance();
  renderQuality();
  renderDetails();
  renderSettings();
  setupTableToggles();
}}

function setupTableToggles() {{
  document.querySelectorAll('.card').forEach(card => {{
    const table = card.querySelector('table');
    const pre = card.querySelector('pre');
    if (!table && !pre) return;
    const wrap = table ? table.parentElement : pre.parentElement;
    if (!wrap || wrap.classList.contains('table-wrap')) return;
    wrap.classList.add('table-wrap');
    const hdr = card.querySelector('.card-hdr');
    const btn = document.createElement('button');
    btn.className = 'toggle-table';
    btn.textContent = '▼';
    btn.title = 'Collapse';
    btn.onclick = function() {{
      wrap.classList.toggle('collapsed');
      btn.textContent = wrap.classList.contains('collapsed') ? '▶' : '▼';
    }};
    if (hdr) {{
      hdr.insertBefore(btn, hdr.querySelector('.export-btn'));
    }} else {{
      const h2 = card.querySelector('h2');
      if (h2) {{
        const div = document.createElement('div');
        div.className = 'card-hdr';
        h2.parentNode.insertBefore(div, h2);
        div.appendChild(h2);
        div.appendChild(btn);
      }}
    }}
  }});
}}

const THEMES = [
  {{id:'',label:'Default',color:'#2563eb'}},
  {{id:'dark',label:'Dark',color:'#1f2937'}},
  {{id:'forest',label:'Forest',color:'#059669'}},
  {{id:'sunset',label:'Sunset',color:'#ea580c'}},
  {{id:'ocean',label:'Ocean',color:'#0284c7'}},
];

function buildThemeSwitcher() {{
  const cur = document.documentElement.dataset.theme || '';
  $('theme-switcher').innerHTML = THEMES.map(t =>
    `<div class="theme-dot${{t.id===cur?' active':''}}" data-theme="${{t.id}}" title="${{t.label}}" style="background:${{t.color}}"></div>`).join('');
  $('theme-switcher').onclick = e => {{
    const dot = e.target.closest('.theme-dot');
    if (!dot) return;
    const theme = dot.dataset.theme;
    document.documentElement.dataset.theme = theme;
    document.querySelectorAll('.theme-dot').forEach(d => d.classList.remove('active'));
    dot.classList.add('active');
    try {{ localStorage.setItem('uc-theme', theme); }} catch(e) {{}}
  }};
}}

function buildNav() {{
  const detailItems = [
    {{id:'details-chart',label:'Time Series'}},
    {{id:'details-uc',label:'Unit Commitment'}},
    {{id:'details-bess',label:'BESS Schedule'}},
  ];
  let html = TABS.map((t,i) => {{
    if (t.id === 'details') {{
      return `<div class="nav-drop" id="nav-drop-details">
        <button class="nav-btn" data-tab="details">${{t.label}} ▾</button>
        <div class="drop-menu">${{detailItems.map(d =>
          `<button class="drop-item${{d.id===activeDetailTab?' active':''}}" data-detail="${{d.id}}" data-tab="details">${{d.label}}</button>`).join('')}}</div>
      </div>`;
    }}
    return `<button class="nav-btn${{i===0?' active':''}}" data-tab="${{t.id}}">${{t.label}}</button>`;
  }}).join('');
  $('nav').innerHTML = html;

  $('nav').onclick = e => {{
    const btn = e.target.closest('button');
    if (!btn) return;
    const tabId = btn.dataset.tab;
    const detailId = btn.dataset.detail;
    const drop = btn.closest('.nav-drop');

    if (drop && !detailId) {{
      drop.classList.toggle('open');
      return;
    }}

    if (detailId) {{
      activeDetailTab = detailId;
      drop.classList.remove('open');
      drop.querySelectorAll('.drop-item').forEach(d => d.classList.remove('active'));
      btn.classList.add('active');
      document.querySelectorAll('#tab-details .sub-tab').forEach(s => s.classList.remove('active'));
      document.getElementById('sub-' + detailId).classList.add('active');
    }}

    if (tabId) {{
      document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
      if (detailId) {{
        drop.querySelector('.nav-btn').classList.add('active');
      }} else {{
        btn.classList.add('active');
      }}
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.getElementById('tab-' + tabId).classList.add('active');
      if (tabId === 'power') renderPowerBalance();
      if (tabId === 'quality') renderQuality();
    }}
  }};

  document.addEventListener('click', e => {{
    if (!e.target.closest('.nav-drop')) {{
      document.querySelectorAll('.nav-drop').forEach(d => d.classList.remove('open'));
    }}
  }});
}}

// ---- overview ----
function renderOverview() {{
  const runs = Object.keys(DATA.summaries).sort();

  let total=0, ok=0, conv=0, err=0;
  for (const [k,v] of Object.entries(DATA.summaries)) {{
    if (!v || v.length<2) continue;
    for (let i=1;i<v.length;i++) {{
      total++;
      const st = (v[i][2]||'').toLowerCase();
      if (st==='optimal') ok++;
      else if (st==='converged') conv++;
      else if (st.includes('inconsistency')||st.includes('error')) err++;
    }}
  }}
  $('overview-metrics').innerHTML = `
    <div class="metric"><div class="label">Experiment Runs</div><div class="value">${{runs.length}}</div></div>
    <div class="metric"><div class="label">Optimal</div><div class="value" style="color:#16a34a">${{ok}}</div></div>
    <div class="metric"><div class="label">Converged</div><div class="value" style="color:#2563eb">${{conv}}</div></div>
    <div class="metric"><div class="label">Failed</div><div class="value" style="color:#dc2626">${{err}}</div></div>
  `;

  let html = '<thead><tr><th>Run</th><th>Algorithm</th><th>Scen</th><th>Status</th><th>Iter</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Time(s)</th><th>RAM(MB)</th></tr></thead><tbody>';
  for (const [run, rows] of Object.entries(DATA.summaries).sort()) {{
    for (let i=1;i<rows.length;i++) {{
      const r = rows[i];
      const gap = parseFloat(r[6]);
      const gapCls = gap<0.01?'gap-good':gap>0.5?'gap-bad':'';
      let badge='';
      const st=(r[2]||'').toLowerCase();
      if (st==='optimal') badge='badge-ok';
      else if (st==='converged') badge='badge-info';
      else if (st.includes('inconsistency')||st.includes('error')) badge='badge-err';
      else badge='badge-warn';
      html += `<tr><td>${{run}}</td><td>${{r[0]}}</td><td>${{r[1]}}</td>
        <td><span class="badge ${{badge}}">${{r[2]}}</span></td><td>${{r[3]}}</td>
        <td>${{Number(r[4]).toFixed(1)}}</td><td>${{Number(r[5]).toFixed(1)}}</td>
        <td class="${{gapCls}}">${{gap.toFixed(5)}}</td><td>${{Number(r[7]).toFixed(1)}}</td><td>${{Number(r[8]).toFixed(0)}}</td></tr>`;
    }}
  }}
  html += '</tbody>';
  $('summary-table').innerHTML = html;
}}

// ---- power balance ----
function renderPowerBalance() {{
  const runs = [...new Set([].concat(...Object.values(DATA.power_balance).map(a=>Object.keys(a))))].sort();
  $('pb-run').innerHTML = runs.map(r => `<option>${{r}}</option>`).join('');
  $('pb-run').onchange = updatePbAlgo;
  $('pb-algo').onchange = updatePbScen;
  $('pb-scen').onchange = updatePbSingle;
  $('pb-single').onchange = drawPbChart;
  if (runs.length) updatePbAlgo();
}}

function updatePbAlgo() {{
  const run = $('pb-run').value;
  const algos = Object.keys(DATA.power_balance).filter(a => DATA.power_balance[a][run]);
  $('pb-algo').innerHTML = algos.map(a => `<option>${{a}}</option>`).join('');
  updatePbScen();
}}

function updatePbScen() {{
  const run = $('pb-run').value;
  const algo = $('pb-algo').value;
  const pb = DATA.power_balance[algo]?.[run] || {{}};
  const scens = [...new Set(Object.keys(pb).map(k => {{const m=k.match(/(\\d+)_scenarios/);return m?m[1]:null;}}).filter(Boolean))].sort((a,b)=>a-b);
  $('pb-scen').innerHTML = scens.map(s => `<option>${{s}}</option>`).join('');
  updatePbSingle();
}}

function updatePbSingle() {{
  const n = parseInt($('pb-scen').value)||2;
  $('pb-single').innerHTML = Array.from({{length:n}},(_,i)=>`<option>${{i+1}}</option>`).join('');
  drawPbChart();
}}

let pbChart = null;
function drawPbChart() {{
  const run = $('pb-run').value;
  const algo = $('pb-algo').value;
  const scenN = $('pb-scen').value;
  const single = parseInt($('pb-single').value);
  const pb = DATA.power_balance[algo]?.[run] || {{}};
  const key = Object.keys(pb).find(k => k.includes(scenN+'_scenarios'));
  if (!key) {{ $('pb-table').innerHTML='';return; }}
  const rows = pb[key];
  if (rows.length<2) return;
  const hdr = rows[0];
  const dataRows = rows.slice(1).filter(r => parseInt(r[0])===single);
  let html = '<thead><tr>'+hdr.map(h=>`<th>${{h}}</th>`).join('')+'</tr></thead><tbody>';
  dataRows.forEach(r => html += '<tr>'+r.map(v=>`<td>${{isNaN(v)?v:Number(v).toFixed(4)}}</td>`).join('')+'</tr>');
  html += '</tbody>';
  $('pb-table').innerHTML = html;
  const ctx = $('pb-chart').getContext('2d');
  if (pbChart) pbChart.destroy();
  pbChart = new Chart(ctx, {{type:'line',data:{{labels:dataRows.map(r=>r[1]),
    datasets:[
      {{label:'Load Demand',data:dataRows.map(r=>Number(r[2])),borderColor:'#94a3b8',borderDash:[5,5],tension:.3,pointRadius:0,borderWidth:1.5}},
      {{label:'Served Load',data:dataRows.map(r=>Number(r[3])),borderColor:'#2563eb',tension:.3,pointRadius:0,borderWidth:1.5}},
      {{label:'Thermal Gen',data:dataRows.map(r=>Number(r[4])),borderColor:'#dc2626',tension:.3,pointRadius:0,borderWidth:1.5}},
      {{label:'Wind Avail',data:dataRows.map(r=>Number(r[5])),borderColor:'#86efac',borderDash:[3,3],tension:.3,pointRadius:0,borderWidth:1}},
      {{label:'Wind Used',data:dataRows.map(r=>Number(r[6])),borderColor:'#16a34a',tension:.3,pointRadius:0,borderWidth:1.5}},
    ]}},
    options:{{responsive:true,maintainAspectRatio:false,
      plugins:CHART_PLUGINS,
          scales:{{x:{{ticks:{{font:{{size:11}},padding:0,maxRotation:0,minRotation:0}},title:{{...CHART_TITLE,text:'Time (h)',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Power (MW)',display:true}}}}}}
    }}
  }});
}}

// ---- quality ----
function renderQuality() {{
  const runs = Object.keys(DATA.qualities).sort();
  $('ql-run').innerHTML = runs.map(r => `<option>${{r}}</option>`).join('');
  $('ql-run').onchange = () => {{ updateQualFilters(); switchQlView(); renderQualTables(); }};
  $('ql-algo').onchange = () => {{ switchQlView(); renderQualTables(); }};
  $('ql-scen').onchange = () => {{ switchQlView(); renderQualTables(); }};
  updateQualFilters();
  renderQualTables();
  buildQlViewTabs();
}}

let qlActiveView = 'curtailment';
let qlCharts = {{}};
const QL_COLORS = ['#2563eb','#dc2626','#16a34a','#d97706','#9333ea','#0891b2','#64748b','#f59e0b','#ec4899','#14b8a6'];

function buildQlViewTabs() {{
  const views = [
    {{id:'curtailment',label:'Curtailment'}},
    {{id:'gap_convergence',label:'Gap Convergence'}},
    {{id:'power_balance_sample',label:'Power Balance'}},
    {{id:'ram_mb',label:'RAM (MB)'}},
    {{id:'runtime_seconds',label:'Runtime'}},
    {{id:'convergence',label:'Convergence'}},
    {{id:'bounds',label:'Bounds'}},
  ];
  $('ql-view-tabs').innerHTML = views.map(v =>
    `<button class="view-tab${{v.id===qlActiveView?' active':''}}" data-view="${{v.id}}">${{v.label}}</button>`).join('');
  $('ql-view-tabs').onclick = e => {{
    const btn = e.target.closest('.view-tab');
    if (!btn) return;
    qlActiveView = btn.dataset.view;
    document.querySelectorAll('.view-tab').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    switchQlView();
  }};
  switchQlView();
}}

function qlCanvas(id) {{
  $('ql-view-display').innerHTML = `<div class="chart-box"><canvas id="${{id}}"></canvas></div>`;
  return document.getElementById(id).getContext('2d');
}}

function switchQlView() {{
  const run = $('ql-run')?.value;
  const algo = $('ql-algo')?.value;
  const scen = $('ql-scen')?.value;
  Object.values(qlCharts).forEach(c => c.destroy());
  qlCharts = {{}};

  if (qlActiveView==='curtailment') {{
    drawQualChart(qlCanvas('ql-c1'));
  }} else if (qlActiveView==='gap_convergence') {{
    let sRows = (DATA.summaries[run]||[]).slice(1);
    if (algo) sRows = sRows.filter(r => r[0]===algo);
    if (scen) sRows = sRows.filter(r => r[1]===scen);
    if (!sRows.length) {{ $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No data.</p>'; return; }}
    const ctx = qlCanvas('ql-c2');
    const labels = sRows.map(r => r[0]+'-'+r[1]+'s');
    const gaps = sRows.map(r => +r[6]);
    const bg = gaps.map(g => g<0.01?'#16a34a99':g<0.2?'#d9770699':'#dc262699');
    qlCharts.gap = new Chart(ctx, {{type:'bar',data:{{labels,datasets:[
      {{label:'Gap',data:gaps,backgroundColor:bg,borderColor:gaps.map(g=>g<0.01?'#16a34a':g<0.2?'#d97706':'#dc2626'),borderWidth:1,borderRadius:2}}
    ]}},options:{{responsive:true,maintainAspectRatio:false,
      plugins:{{legend:{{display:false}}}},
      scales:{{x:{{grid:{{display:false}},ticks:CHART_TICKS_X,title:{{...CHART_TITLE,text:'',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Optimality Gap',display:true}},type:'logarithmic',min:1e-5}}}}
    }}}});
  }} else if (qlActiveView==='power_balance_sample') {{
    let found = false;
    for (const app of ['benchmark_uc','benders','ccg']) {{
      if (algo && app!==algo) continue;
      const pb = DATA.power_balance[app]?.[run];
      if (!pb) continue;
      const key = Object.keys(pb).find(k => k.includes('_scenarios'));
      if (!key) continue;
      found = true;
      const hdr = pb[key][0];
      const rows = pb[key].slice(1).filter(r => !scen||r[0]===scen);
      if (!rows.length) continue;
      const ctx = qlCanvas('ql-c2');
      qlCharts.pb = new Chart(ctx, {{type:'line',data:{{labels:rows.map(r=>r[1]),
        datasets:[
          {{label:'Load Demand ('+app+')',data:rows.map(r=>+r[2]),borderColor:'#94a3b8',borderDash:[5,5],tension:.3,pointRadius:0,borderWidth:1.5}},
          {{label:'Served Load',data:rows.map(r=>+r[3]),borderColor:'#2563eb',tension:.3,pointRadius:0,borderWidth:1.5}},
          {{label:'Thermal Gen',data:rows.map(r=>+r[4]),borderColor:'#dc2626',tension:.3,pointRadius:0,borderWidth:1.5}},
          {{label:'Wind Used',data:rows.map(r=>+r[6]),borderColor:'#16a34a',tension:.3,pointRadius:0,borderWidth:1.5}},
        ]}},
        options:{{responsive:true,maintainAspectRatio:false,
          plugins:CHART_PLUGINS,
      scales:{{x:{{ticks:{{font:{{size:11}},padding:0,maxRotation:0,minRotation:0}},title:{{...CHART_TITLE,text:'Time (h)',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Power (MW)',display:true}}}}}}
        }}
      }});
      break;
    }}
    if (!found) $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No power balance data for this run.</p>';
  }} else if (qlActiveView==='ram_mb') {{
    let sRows = (DATA.summaries[run]||[]).slice(1);
    if (algo) sRows = sRows.filter(r => r[0]===algo);
    if (scen) sRows = sRows.filter(r => r[1]===scen);
    if (!sRows.length) {{ $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No data.</p>'; return; }}
    const ctx = qlCanvas('ql-c2');
    qlCharts.ram = new Chart(ctx, {{type:'bar',data:{{labels:sRows.map(r=>r[0]+'-'+r[1]+'s'),datasets:[
      {{label:'RAM (MB)',data:sRows.map(r=>+r[8]),backgroundColor:'#2563eb99',borderColor:'#2563eb',borderWidth:1,borderRadius:2}}
    ]}},options:{{responsive:true,maintainAspectRatio:false,
      plugins:{{legend:{{display:false}}}},
      scales:{{x:{{grid:{{display:false}},ticks:CHART_TICKS_X,title:{{...CHART_TITLE,text:'',display:true}}}},y:{{title:{{...CHART_TITLE,text:'RAM (MB)',display:true}}}}}}
    }}}});
  }} else if (qlActiveView==='runtime_seconds') {{
    let sRows = (DATA.summaries[run]||[]).slice(1);
    if (algo) sRows = sRows.filter(r => r[0]===algo);
    if (scen) sRows = sRows.filter(r => r[1]===scen);
    if (!sRows.length) {{ $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No data.</p>'; return; }}
    const ctx = qlCanvas('ql-c2');
    qlCharts.runtime = new Chart(ctx, {{type:'bar',data:{{labels:sRows.map(r=>r[0]+'-'+r[1]+'s'),datasets:[
      {{label:'Runtime (s)',data:sRows.map(r=>+r[7]),backgroundColor:'#16a34a99',borderColor:'#16a34a',borderWidth:1,borderRadius:2}}
    ]}},options:{{responsive:true,maintainAspectRatio:false,
      plugins:{{legend:{{display:false}}}},
      scales:{{x:{{grid:{{display:false}},ticks:CHART_TICKS_X,title:{{...CHART_TITLE,text:'',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Runtime (s)',display:true}}}}}}
    }}}});
  }} else if (qlActiveView==='convergence') {{
    let rows = (DATA.iterations[run]||[]).slice(1);
    if (algo) rows = rows.filter(r => r[0]===algo);
    if (scen) rows = rows.filter(r => r[1]===scen);
    if (!rows.length) {{ $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No data.</p>'; return; }}
    const groups = {{}};
    rows.forEach(r => {{ const k=r[0]+'-'+r[1]+'s'; if(!groups[k])groups[k]=[]; groups[k].push({{x:+r[2],y:Math.max(+r[6],1e-8)}}); }});
    const maxIter = Math.max(...rows.map(r=>+r[2]));
    const ctx = qlCanvas('ql-c2');
    const datasets = Object.entries(groups).map(([k,v],i) => {{
      const yByIter = {{}}; v.forEach(p=>{{yByIter[p.x]=p.y;}});
      const data = [];
      for (let iter=1;iter<=maxIter;iter++) data.push(yByIter[iter]||null);
      return {{label:k,data,borderColor:QL_COLORS[i%QL_COLORS.length],backgroundColor:QL_COLORS[i%QL_COLORS.length]+'20',fill:false,tension:.2,pointRadius:1,spanGaps:true}};
    }});
    qlCharts.conv = new Chart(ctx, {{type:'line',data:{{labels:Array.from({{length:maxIter}},(_,i)=>i+1),datasets}},
      options:{{responsive:true,maintainAspectRatio:false,
        scales:{{x:{{ticks:{{font:{{size:11}},padding:0,maxRotation:0,minRotation:0}},title:{{...CHART_TITLE,text:'Iteration',display:true}}}},y:{{type:'logarithmic',title:{{...CHART_TITLE,text:'Optimality Gap',display:true}},min:1e-6}}}},
        plugins:CHART_PLUGINS
      }}
    }});
  }} else if (qlActiveView==='bounds') {{
    let rows = (DATA.iterations[run]||[]).slice(1);
    if (algo) rows = rows.filter(r => r[0]===algo);
    if (scen) rows = rows.filter(r => r[1]===scen);
    if (!rows.length) {{ $('ql-view-display').innerHTML='<p style="color:#94a3b8;padding:40px;text-align:center;">No data.</p>'; return; }}
    const maxIter = Math.max(...rows.map(r=>+r[2]));
    const groups = {{}};
    rows.forEach(r => {{ const k=r[0]+'-'+r[1]+'s'; if(!groups[k])groups[k]={{lb:[],ub:[]}}; }});
    Object.keys(groups).forEach(k => {{
      for (let i=1;i<=maxIter;i++) {{ groups[k].lb.push(null); groups[k].ub.push(null); }}
    }});
    rows.forEach(r => {{
      const k=r[0]+'-'+r[1]+'s'; const idx=+r[2]-1;
      groups[k].lb[idx]=+r[4]; groups[k].ub[idx]=+r[5];
    }});
    const ctx = qlCanvas('ql-c2');
    const datasets = [];
    Object.entries(groups).forEach(([k,v],i) => {{
      datasets.push({{label:k+' LB',data:v.lb,borderColor:QL_COLORS[i%QL_COLORS.length],borderDash:[3,3],tension:.2,pointRadius:0,spanGaps:true}});
      datasets.push({{label:k+' UB',data:v.ub,borderColor:QL_COLORS[i%QL_COLORS.length],tension:.2,pointRadius:0,spanGaps:true}});
    }});
    qlCharts.bounds = new Chart(ctx, {{type:'line',data:{{labels:Array.from({{length:maxIter}},(_,i)=>i+1),datasets}},
      options:{{responsive:true,maintainAspectRatio:false,
        scales:{{x:{{ticks:{{font:{{size:11}},padding:0,maxRotation:0,minRotation:0}},title:{{...CHART_TITLE,text:'Iteration',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Cost',display:true}}}}}},
        plugins:CHART_PLUGINS
      }}
    }});
  }}
}}

function updateQualFilters() {{
  const run = $('ql-run').value;
  const rows = DATA.qualities[run];
  if (!rows || rows.length<2) return;
  const algos = [...new Set(rows.slice(1).map(r => r[0]))];
  $('ql-algo').innerHTML = '<option value="">All</option>'+algos.map(a => `<option>${{a}}</option>`).join('');
  const scens = [...new Set(rows.slice(1).map(r => r[1]))];
  $('ql-scen').innerHTML = '<option value="">All</option>'+scens.map(s => `<option>${{s}}</option>`).join('');
}}

function getQualFiltered() {{
  const run = $('ql-run').value;
  const algo = $('ql-algo').value;
  const scen = $('ql-scen').value;
  let rows = (DATA.qualities[run]||[]).slice(1);
  if (algo) rows = rows.filter(r => r[0]===algo);
  if (scen) rows = rows.filter(r => r[1]===scen);
  return rows;
}}

function drawQualChart(ctx) {{
  const rows = getQualFiltered();
  if (!rows.length) return;
  qlCharts.curtailment = new Chart(ctx, {{type:'bar',data:{{labels:rows.map(r=>r[0]+'-'+r[1]+'s'),datasets:[
    {{label:'Wind Curtailment',data:rows.map(r=>Number(r[4])),backgroundColor:'#16a34a99',borderColor:'#16a34a',borderWidth:1,borderRadius:2}},
    {{label:'Load Curtailment',data:rows.map(r=>Number(r[3])),backgroundColor:'#dc262699',borderColor:'#dc2626',borderWidth:1,borderRadius:2}},
  ]}},options:{{responsive:true,maintainAspectRatio:false,
    plugins:CHART_PLUGINS,
    scales:{{x:{{grid:{{display:false}},ticks:CHART_TICKS_X,title:{{...CHART_TITLE,text:'',display:true}}}},y:{{title:{{...CHART_TITLE,text:'Curtailment (MW)',display:true}}}}}}
  }}}});
}}

function qualIterFiltered() {{
  const run = $('ql-run').value;
  const algo = $('ql-algo').value;
  const scen = $('ql-scen').value;
  let rows = (DATA.iterations[run]||[]).slice(1);
  if (algo) rows = rows.filter(r => r[0]===algo);
  if (scen) rows = rows.filter(r => r[1]===scen);
  return rows;
}}

function qualSummaryFiltered() {{
  const run = $('ql-run').value;
  const algo = $('ql-algo').value;
  const scen = $('ql-scen').value;
  let rows = (DATA.summaries[run]||[]).slice(1) || [];
  if (algo) rows = rows.filter(r => r[0]===algo);
  if (scen) rows = rows.filter(r => r[1]===scen);
  return rows;
}}

function renderQualTables() {{
  const run = $('ql-run').value;
  const algo = $('ql-algo').value;
  const scen = $('ql-scen').value;

  let qRows = (DATA.qualities[run]||[]).slice(1);
  if (algo) qRows = qRows.filter(r => r[0]===algo);
  if (scen) qRows = qRows.filter(r => r[1]===scen);
  let qhtml = '<thead><tr><th>Run</th><th>Algorithm</th><th>Scen</th><th>Max Balance Error</th><th>Load Curtail</th><th>Wind Curtail</th><th>Peak Load</th></tr></thead><tbody>';
  qRows.forEach(r => {{ qhtml += `<tr><td>${{run}}</td><td>${{r[0]}}</td><td>${{r[1]}}</td><td>${{Number(r[2]).toExponential(2)}}</td><td>${{Number(r[3]).toFixed(3)}}</td><td>${{Number(r[4]).toFixed(2)}}</td><td>${{Number(r[5]).toFixed(4)}}</td></tr>`; }});
  qhtml += '</tbody>';
  $('ql-quality-table').innerHTML = qhtml;

  let sRows = qualSummaryFiltered();
  if (!sRows.length) {{ $('ql-summary-table').innerHTML=''; }}
  else {{
    let shtml = '<thead><tr><th>Run</th><th>Algorithm</th><th>Scenarios</th><th>Status</th><th>Iter</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Time (s)</th><th>RAM (MB)</th></tr></thead><tbody>';
    sRows.forEach(r => {{
      const gap=parseFloat(r[6]); const gapCls=gap<0.01?'gap-good':gap>0.5?'gap-bad':'';
      let badge=''; const st=(r[2]||'').toLowerCase();
      if (st==='optimal') badge='badge-ok';
      else if (st==='converged') badge='badge-info';
      else if (st.includes('inconsistency')||st.includes('error')) badge='badge-err';
      else badge='badge-warn';
      shtml+=`<tr><td>${{run}}</td><td>${{r[0]}}</td><td>${{r[1]}}</td><td><span class="badge ${{badge}}">${{r[2]}}</span></td><td>${{r[3]}}</td><td>${{Number(r[4]).toFixed(1)}}</td><td>${{Number(r[5]).toFixed(1)}}</td><td class="${{gapCls}}">${{gap.toFixed(5)}}</td><td>${{Number(r[7]).toFixed(1)}}</td><td>${{Number(r[8]).toFixed(0)}}</td></tr>`;
    }});
    shtml+='</tbody>';
    $('ql-summary-table').innerHTML = shtml;
  }}

  let iRows = qualIterFiltered();
  if (!iRows.length) {{ $('ql-iter-table').innerHTML=''; }}
  else {{
    let ihtml = '<thead><tr><th>Algorithm</th><th>Scen</th><th>Iter</th><th>Active</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Added</th><th>RAM</th></tr></thead><tbody>';
    iRows.forEach(r => {{
      ihtml+=`<tr><td>${{r[0]}}</td><td>${{r[1]}}</td><td>${{r[2]}}</td><td>${{r[3]}}</td><td>${{Number(r[4]).toFixed(1)}}</td><td>${{Number(r[5]).toFixed(1)}}</td><td>${{parseFloat(r[6]).toFixed(5)}}</td><td>${{r[7]}}</td><td>${{r[8]}}</td></tr>`;
    }});
    ihtml+='</tbody>';
    $('ql-iter-table').innerHTML = ihtml;
  }}
}}

// ---- txt ----
// ---- details ----
function renderDetails() {{
  $('uc-pre').textContent = DATA.schedule_txt;
  $('bess-pre').textContent = DATA.bess_txt;
  const d = DATA.details;
  const keys = ['res_thermalunits','res_windunits','res_bess_charging','res_bess_discharging','res_forcedloadcurtailment'];
  const labels = ['Thermal','Wind','BESS Charge','BESS Discharge','Curtailment'];
  const colors = ['#dc2626','#16a34a','#2563eb','#9333ea','#d97706'];
  const timeLabels = Array.from({{length:24}},(_,i)=>i+1);
  const ctx = $('det-chart').getContext('2d');
  new Chart(ctx, {{type:'line',data:{{labels:timeLabels,
    datasets:keys.map((k,i)=>({{label:labels[i],data:d[k]||[],borderColor:colors[i],backgroundColor:colors[i]+'55',tension:.3,pointRadius:0,fill:true,borderWidth:1.5}}))
  }},options:{{responsive:true,maintainAspectRatio:false,
    plugins:CHART_PLUGINS,
    scales:{{x:{{ticks:{{font:{{size:11}},padding:0,maxRotation:0,minRotation:0}},title:{{...CHART_TITLE,text:'Time (h)',display:true}}}},y:{{stacked:true,title:{{...CHART_TITLE,text:'MW',display:true}}}}}}
  }}}});
  let html = '<thead><tr><th>Time</th>'+labels.map(l=>`<th>${{l}} (MW)</th>`).join('')+'</tr></thead><tbody>';
  for (let t=0;t<24;t++) html += '<tr><td>'+(t+1)+'</td>'+keys.map(k=>`<td>${{(d[k]?.[t]||0).toFixed(4)}}</td>`).join('')+'</tr>';
  html += '</tbody>';
  $('det-table').innerHTML = html;
}}

// ---- settings ----
function renderSettings() {{
  const cfg = DATA.config;
  if (!cfg || !cfg.sections) return;
  let html = '';
  const labelMap = {{
    boundary:'Boundary Reporting',common:'Common Settings',model:'Model Parameters',
    benders:'Benders Decomposition','benders.cuts':'Benders — Cut Settings',
    'benders.subproblems':'Benders — Subproblems',ccg:'CCG Settings',
    dro:'DRO (Wasserstein)',frequency:'Frequency Control',test:'Test'
  }};
  cfg.sections.forEach(sec => {{
    html += `<div class="settings-section"><h3>${{labelMap[sec.name]||sec.name}}</h3><div class="fields">`;
    sec.fields.forEach(f => {{
      const id = 'cfg-'+f.key;
      if (f.type==='bool') {{
        html += `<div class="field"><label for="${{id}}">${{f.key}}</label>
          <input type="checkbox" id="${{id}}" data-key="${{f.key}}" ${{f.value?'checked':''}}></div>`;
      }} else if (f.type==='number') {{
        html += `<div class="field"><label for="${{id}}">${{f.key}}</label>
          <input type="number" id="${{id}}" data-key="${{f.key}}" value="${{f.value}}" step="any"></div>`;
      }} else {{
        html += `<div class="field"><label for="${{id}}">${{f.key}}</label>
          <input type="text" id="${{id}}" data-key="${{f.key}}" value="${{escapeHtml(String(f.value))}}"></div>`;
      }}
    }});
    html += '</div></div>';
  }});
  $('settings-grid').innerHTML = html;
}}

function escapeHtml(s) {{ return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }}

async function saveConfig() {{
  const btn = $('save-config-btn');
  const msg = $('save-msg');
  btn.disabled = true;
  msg.className = 'msg';
  msg.textContent = 'Saving...';
  const updates = {{}};
  document.querySelectorAll('[data-key]').forEach(el => {{
    const key = el.dataset.key;
    if (el.type==='checkbox') updates[key] = el.checked;
    else if (el.type==='number') updates[key] = parseFloat(el.value);
    else updates[key] = el.value;
  }});
  try {{
    const r = await fetch('/api/config', {{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify(updates)}});
    if (r.ok) {{ msg.className = 'msg ok'; msg.textContent = 'Saved successfully.'; }}
    else {{ msg.className = 'msg err'; msg.textContent = 'Save failed: '+r.status; }}
  }} catch(e) {{ msg.className = 'msg err'; msg.textContent = 'Save failed — is the server running? (python3 gui/server.py)'; }}
  btn.disabled = false;
  setTimeout(()=>{{msg.textContent='';}},3000);
}}

try {{ init(); }} catch(e) {{ document.body.innerHTML = '<div style=\"padding:40px;color:#dc2626;font-family:monospace;\"><h2>Error</h2><pre>'+e.message+'</pre><pre>'+e.stack+'</pre></div>'; }}
</script></body></html>'''

    out_path = GUI / 'index.html'
    with open(out_path, 'w') as f:
        f.write(html)
    print(f'Generated {out_path} ({len(html)} bytes)')

if __name__ == '__main__':
    main()
