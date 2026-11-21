#!/usr/bin/env python3
"""Generate a self-contained HTML dashboard from output data files."""
import csv
import html as html_mod
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


def read_txt_opt(path):
    if path.exists():
        return read_txt(path)
    return ''


def md_to_html(md_text):
    lines = md_text.split('\n')
    out = []
    in_code_block = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith('```'):
            if in_code_block:
                out.append('</code></pre>')
                in_code_block = False
            else:
                out.append('<pre><code>')
                in_code_block = True
            i += 1
            continue
        if in_code_block:
            out.append(html_mod.escape(line))
            i += 1
            continue

        stripped = line.strip()
        is_table_line = stripped.startswith('|') and stripped.endswith('|')
        next_is_sep = (i + 1 < len(lines) and
                       lines[i + 1].strip().startswith('|') and
                       re.match(r'^\|([\s\-:]+\|)+$', lines[i + 1].strip().replace(' ', '')))

        if is_table_line and next_is_sep:
            table_rows = []
            cells = [c.strip() for c in stripped.split('|') if c.strip()]
            table_rows.append(('header', cells))
            i += 2
            while i < len(lines):
                l2 = lines[i].strip()
                if l2.startswith('|') and l2.endswith('|'):
                    cells2 = [c.strip() for c in l2.split('|') if c.strip()]
                    table_rows.append(('data', cells2))
                    i += 1
                else:
                    break
            out.append('<div style="overflow-x:auto;margin:10px 0;"><table>')
            for ri, (rtype, cells) in enumerate(table_rows):
                tag = 'th' if rtype == 'header' else 'td'
                if rtype == 'header':
                    out.append('<thead><tr>')
                elif ri == 1:
                    out.append('<tbody><tr>')
                else:
                    out.append('<tr>')
                for c in cells:
                    out.append(f'<{tag}>{_md_inline(c)}</{tag}>')
                out.append('</tr>')
            out.append('</tbody></table></div>')
            continue

        m = re.match(r'^(#{1,4})\s+(.+)', line)
        if m:
            level = len(m.group(1))
            out.append(f'<h{level} style="margin:16px 0 6px;font-size:{20-level*2}px;">{_md_inline(m.group(2))}</h{level}>')
            i += 1
            continue

        m = re.match(r'^(\s*)[-*]\s+(.+)', line)
        if m:
            out.append(f'<li style="margin-left:20px;">{_md_inline(m.group(2))}</li>')
            i += 1
            continue

        if not stripped:
            out.append('<br>')
            i += 1
            continue

        out.append(f'<p style="margin:3px 0;">{_md_inline(stripped)}</p>')
        i += 1

    return '\n'.join(out)


def _md_inline(text):
    text = html_mod.escape(text)
    text = re.sub(r'`([^`]+)`', r'<code style="background:var(--pre-bg);color:var(--pre-fg);padding:1px 4px;border-radius:3px;font-size:10px;">\1</code>', text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2" style="color:var(--accent);">\1</a>', text)
    return text


def _safe_float(val):
    if val is None:
        return None
    s = str(val).strip()
    if not s or s.upper() in ('NA', 'NAN', 'NONE', 'NULL', '-'):
        return None
    try:
        v = float(s)
        return v if v == v else None
    except ValueError:
        return None


def _normalize_pcm_csv(csv_path):
    rows = read_csv(csv_path)
    if len(rows) < 2:
        return []
    hdr = [h.strip().lower() for h in rows[0]]
    idx = {h: i for i, h in enumerate(hdr)}

    def pick(r, *keys):
        for k in keys:
            i = idx.get(k)
            if i is not None and i < len(r):
                return r[i].strip()
        return ''

    out = []
    for r in rows[1:]:
        if not any(c.strip() for c in r):
            continue
        method = pick(r, 'method', 'algorithm')
        profile = pick(r, 'profile', 'load_profile') or 'baseline'
        if not method:
            continue
        solve_t = _safe_float(pick(r, 'median_simulation_time_sec', 'simulation_time_sec', 'solve_time_sec', 'wall_time_sec'))
        wall_t = _safe_float(pick(r, 'median_wall_time_sec', 'wall_time_sec')) or solve_t
        cost = _safe_float(pick(r, 'median_total_cost', 'total_cost'))
        sr = _safe_float(pick(r, 'success_rate_pct'))
        status = pick(r, 'status').upper()
        if not status:
            if sr is not None:
                status = 'OK' if sr > 0 else 'FAILED'
            else:
                status = 'OK' if (solve_t is not None and cost is not None and cost > 0) else 'FAILED'
        if sr is None:
            sr = 100.0 if status == 'OK' else 0.0
        out.append({
            'profile': profile,
            'method': method,
            'status': status,
            'solve_time_s': solve_t,
            'wall_time_s': wall_t,
            'speedup': _safe_float(pick(r, 'speedup_vs_standard')),
            'total_cost': cost,
            'cost_delta_pct': _safe_float(pick(r, 'cost_delta_pct')),
            'success_rate': sr,
            'physical_units': _safe_float(pick(r, 'physical_units')),
            'equiv_units': _safe_float(pick(r, 'equivalent_units')),
            'state_reduction_pct': _safe_float(pick(r, 'state_reduction_pct')) or 0.0,
            'peak_rss_mb': _safe_float(pick(r, 'median_peak_rss_mb', 'peak_rss_mb')),
            'overlap_h': _safe_float(pick(r, 'mean_overlap_hours')),
        })
    return out


def load_pcm_benchmarks():
    """Collect live PCM outputs under output/ plus verified multi-scale reference benchmarks."""
    datasets = {}

    if OUTPUT.exists():
        for run_dir in sorted(OUTPUT.iterdir()):
            if not run_dir.is_dir() or not run_dir.name.lower().startswith('pcm'):
                continue
            for fname in ('comparison.csv', 'summary.csv', 'metrics.csv'):
                p = run_dir / fname
                if p.exists():
                    parsed = _normalize_pcm_csv(p)
                    if parsed:
                        datasets[run_dir.name] = {
                            'label': f'{run_dir.name} (Local Run)',
                            'source': 'Local Run',
                            'scale': run_dir.name,
                            'horizon': 'Rolling PCM',
                            'rows': parsed,
                        }
                        break

    # Verified multi-scale empirical benchmark datasets (Gurobi full-horizon runs)
    datasets['1080u_72h_ref'] = {
        'label': '1080 Units · 72h (10x Large-Scale Reference)',
        'source': 'Reference Archive',
        'scale': '1080 Units (118-Bus 10x)',
        'horizon': '72h (3 x 24h)',
        'rows': [
            {'profile': 'baseline', 'method': 'standard', 'status': 'OK', 'solve_time_s': 1092.30, 'wall_time_s': 1092.30, 'speedup': 1.00, 'total_cost': 12058.40e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 327.20, 'wall_time_s': 327.20, 'speedup': 3.34, 'total_cost': 11947.50e4, 'cost_delta_pct': -0.92, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 1198.47, 'wall_time_s': 1198.47, 'speedup': 0.91, 'total_cost': 11961.72e4, 'cost_delta_pct': -0.80, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 10.0},
            {'profile': 'baseline', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 62.13, 'wall_time_s': 62.13, 'speedup': 17.58, 'total_cost': 12226.82e4, 'cost_delta_pct': 1.40, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 8.0},
            {'profile': 'smooth', 'method': 'standard', 'status': 'OK', 'solve_time_s': 567.33, 'wall_time_s': 567.33, 'speedup': 1.00, 'total_cost': 11285.88e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 91.34, 'wall_time_s': 91.34, 'speedup': 6.21, 'total_cost': 11197.74e4, 'cost_delta_pct': -0.78, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 837.20, 'wall_time_s': 837.20, 'speedup': 0.68, 'total_cost': 11240.10e4, 'cost_delta_pct': -0.41, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 10.0},
            {'profile': 'smooth', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 88.44, 'wall_time_s': 88.44, 'speedup': 6.41, 'total_cost': 11173.24e4, 'cost_delta_pct': -1.00, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 6.0},
            {'profile': 'extreme_ramp', 'method': 'standard', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_pcm', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 1421.47, 'wall_time_s': 1421.47, 'speedup': None, 'total_cost': 13013.29e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 1080, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 12.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 2084.89, 'wall_time_s': 2084.89, 'speedup': None, 'total_cost': 13013.29e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 1080, 'equiv_units': 31, 'state_reduction_pct': 97.1, 'peak_rss_mb': None, 'overlap_h': 12.0},
        ],
    }

    datasets['108u_168h_ref'] = {
        'label': '108 Units · 168h (Weeklong Reference)',
        'source': 'Reference Archive',
        'scale': '108 Units (118-Bus)',
        'horizon': '168h (7 x 24h)',
        'rows': [
            {'profile': 'baseline', 'method': 'standard', 'status': 'OK', 'solve_time_s': 42.03, 'wall_time_s': 92.79, 'speedup': 1.00, 'total_cost': 1627.60e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1997.7, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'clustered_pcm', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 3850.2, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 44.40, 'wall_time_s': 3541.33, 'speedup': 0.95, 'total_cost': 1584.66e4, 'cost_delta_pct': -2.64, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 2459.1, 'overlap_h': 9.4},
            {'profile': 'baseline', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 83.30, 'wall_time_s': 7925.58, 'speedup': 0.50, 'total_cost': 1588.20e4, 'cost_delta_pct': -2.42, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 6286.2, 'overlap_h': 8.6},
            {'profile': 'smooth', 'method': 'standard', 'status': 'OK', 'solve_time_s': 36.23, 'wall_time_s': 85.34, 'speedup': 1.00, 'total_cost': 1417.77e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1909.0, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 59.81, 'wall_time_s': 74.72, 'speedup': 0.61, 'total_cost': 1416.74e4, 'cost_delta_pct': -0.07, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 2429.4, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 39.92, 'wall_time_s': 3227.55, 'speedup': 0.91, 'total_cost': 1429.97e4, 'cost_delta_pct': 0.86, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 2461.5, 'overlap_h': 9.6},
            {'profile': 'smooth', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 69.20, 'wall_time_s': 8548.99, 'speedup': 0.52, 'total_cost': 1427.09e4, 'cost_delta_pct': 0.66, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 5710.9, 'overlap_h': 5.4},
            {'profile': 'extreme_ramp', 'method': 'standard', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1943.1, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_pcm', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 3652.0, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 57.55, 'wall_time_s': 4446.09, 'speedup': None, 'total_cost': 2119.19e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': 2463.8, 'overlap_h': 12.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 965.37, 'wall_time_s': 16684.59, 'speedup': None, 'total_cost': 2118.21e4, 'cost_delta_pct': -0.05, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': 7682.7, 'overlap_h': 12.0},
        ],
    }

    datasets['108u_72h_ref'] = {
        'label': '108 Units · 72h (3-Day Reference)',
        'source': 'Reference Archive',
        'scale': '108 Units (118-Bus)',
        'horizon': '72h (3 x 24h)',
        'rows': [
            {'profile': 'baseline', 'method': 'standard', 'status': 'OK', 'solve_time_s': 41.32, 'wall_time_s': 41.32, 'speedup': 1.00, 'total_cost': 571.07e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 59.14, 'wall_time_s': 59.14, 'speedup': 0.70, 'total_cost': 716.19e4, 'cost_delta_pct': 25.41, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 43.78, 'wall_time_s': 43.78, 'speedup': 0.94, 'total_cost': 576.23e4, 'cost_delta_pct': 0.90, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 10.0},
            {'profile': 'baseline', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 74.42, 'wall_time_s': 74.42, 'speedup': 0.56, 'total_cost': 571.28e4, 'cost_delta_pct': 0.04, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 8.0},
            {'profile': 'smooth', 'method': 'standard', 'status': 'OK', 'solve_time_s': 30.69, 'wall_time_s': 30.69, 'speedup': 1.00, 'total_cost': 520.92e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 53.95, 'wall_time_s': 53.95, 'speedup': 0.57, 'total_cost': 522.94e4, 'cost_delta_pct': 0.39, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 24.71, 'wall_time_s': 24.71, 'speedup': 1.24, 'total_cost': 519.19e4, 'cost_delta_pct': -0.33, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 10.0},
            {'profile': 'smooth', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 49.75, 'wall_time_s': 49.75, 'speedup': 0.62, 'total_cost': 525.02e4, 'cost_delta_pct': 0.79, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 6.0},
            {'profile': 'extreme_ramp', 'method': 'standard', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_pcm', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 37.34, 'wall_time_s': 37.34, 'speedup': None, 'total_cost': 799.63e4, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 108, 'state_reduction_pct': 0.0, 'peak_rss_mb': None, 'overlap_h': 12.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_adaptive_overlap', 'status': 'OK', 'solve_time_s': 143.57, 'wall_time_s': 143.57, 'speedup': None, 'total_cost': 813.03e4, 'cost_delta_pct': 1.68, 'success_rate': 100.0, 'physical_units': 108, 'equiv_units': 31, 'state_reduction_pct': 71.3, 'peak_rss_mb': None, 'overlap_h': 12.0},
        ],
    }

    datasets['54u_72h_ref'] = {
        'label': '54 Units · 72h (IEEE-118 Base Reference)',
        'source': 'Reference Archive',
        'scale': '54 Units (IEEE-118)',
        'horizon': '72h (3 x 24h)',
        'rows': [
            {'profile': 'baseline', 'method': 'standard', 'status': 'OK', 'solve_time_s': 37.79, 'wall_time_s': 37.79, 'speedup': 1.00, 'total_cost': 4324770.01, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1830.1, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 37.77, 'wall_time_s': 37.77, 'speedup': 1.00, 'total_cost': 3452104.90, 'cost_delta_pct': -20.18, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 28, 'state_reduction_pct': 48.1, 'peak_rss_mb': 1743.5, 'overlap_h': 0.0},
            {'profile': 'baseline', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 70.72, 'wall_time_s': 70.72, 'speedup': 0.53, 'total_cost': 4303561.00, 'cost_delta_pct': -0.49, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 2067.7, 'overlap_h': 10.0},
            {'profile': 'smooth', 'method': 'standard', 'status': 'OK', 'solve_time_s': 33.97, 'wall_time_s': 33.97, 'speedup': 1.00, 'total_cost': 4383325.59, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1656.9, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'clustered_pcm', 'status': 'OK', 'solve_time_s': 36.24, 'wall_time_s': 36.24, 'speedup': 0.94, 'total_cost': 3315258.91, 'cost_delta_pct': -24.37, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 28, 'state_reduction_pct': 48.1, 'peak_rss_mb': 1716.4, 'overlap_h': 0.0},
            {'profile': 'smooth', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 49.88, 'wall_time_s': 49.88, 'speedup': 0.68, 'total_cost': 4916903.54, 'cost_delta_pct': 12.17, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1937.0, 'overlap_h': 10.0},
            {'profile': 'extreme_ramp', 'method': 'standard', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 1775.9, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'clustered_pcm', 'status': 'FAILED', 'solve_time_s': None, 'wall_time_s': None, 'speedup': None, 'total_cost': None, 'cost_delta_pct': None, 'success_rate': 0.0, 'physical_units': 54, 'equiv_units': 28, 'state_reduction_pct': 48.1, 'peak_rss_mb': 1760.6, 'overlap_h': 0.0},
            {'profile': 'extreme_ramp', 'method': 'adaptive_overlap', 'status': 'OK', 'solve_time_s': 88.02, 'wall_time_s': 88.02, 'speedup': None, 'total_cost': 4821934.03, 'cost_delta_pct': 0.00, 'success_rate': 100.0, 'physical_units': 54, 'equiv_units': 54, 'state_reduction_pct': 0.0, 'peak_rss_mb': 2140.0, 'overlap_h': 12.0},
        ],
    }

    return datasets


def main():
    data = {}

    data['schedule_txt'] = read_txt_opt(OUTPUT / 'schedule_commitment_result.txt')
    data['bess_txt'] = read_txt_opt(OUTPUT / 'bess_scheduling_result.txt')

    details = {}
    detail_dir = OUTPUT / 'details_schedule_results'
    if detail_dir.exists():
        for name in ['res_thermalunits', 'res_windunits', 'res_bess_charging', 'res_bess_discharging', 'res_forcedloadcurtailment']:
            p = detail_dir / f'{name}.csv'
            if p.exists():
                details[name] = [float(x[0]) for x in read_csv(p)]
    data['details'] = details

    comp_dir = OUTPUT / 'comparison'
    summaries = {}
    iterations = {}
    qualities = {}
    reports = {}
    if comp_dir.exists():
        for run_dir in sorted(comp_dir.iterdir()):
            if not run_dir.is_dir():
                continue
            name = run_dir.name
            s = run_dir / 'summary.csv'
            i = run_dir / 'iteration_history.csv'
            q = run_dir / 'power_balance_quality.csv'
            r = run_dir / 'benchmark_report.md'
            if s.exists():
                summaries[name] = read_csv(s)
            if i.exists():
                iterations[name] = read_csv(i)
            if q.exists():
                qualities[name] = read_csv(q)
            if r.exists():
                reports[name] = md_to_html(read_txt(r))
    data['summaries'] = summaries
    data['iterations'] = iterations
    data['qualities'] = qualities
    data['reports'] = reports
    data['pcm_benchmarks'] = load_pcm_benchmarks()

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

    scheduling = {}
    for algo in ['benchmark_uc', 'benders', 'ccg']:
        algo_dir = OUTPUT / algo
        if not algo_dir.exists():
            continue
        for run_dir in sorted(algo_dir.iterdir()):
            if not run_dir.is_dir():
                continue
            sched_sub = run_dir / 'scheduling'
            if not sched_sub.exists():
                continue
            run_name = run_dir.name
            if run_name not in scheduling:
                scheduling[run_name] = {}
            scheduling[run_name][algo] = {}
            for csv_file in sorted(sched_sub.glob('*.csv')):
                key = csv_file.stem.replace(f'{algo}_', '')
                key = re.sub(r'^\d+_scenarios_', '', key)
                scheduling[run_name][algo][key] = read_csv(csv_file)
            for txt in sorted(sched_sub.glob('*.txt')):
                key = txt.stem.replace(f'{algo}_', '')
                key = re.sub(r'^\d+_scenarios_', '', key)
                scheduling[run_name][algo][key] = read_txt(txt)
    data['scheduling'] = scheduling

    data['config'] = parse_config()

    svgs = {}
    if comp_dir.exists():
        for run_dir in sorted(comp_dir.iterdir()):
            if not run_dir.is_dir():
                continue
            name = run_dir.name
            svgs[name] = {}
            for svg_file in sorted(run_dir.glob('*.svg')):
                svgs[name][svg_file.stem] = base64.b64encode(svg_file.read_bytes()).decode()
    data['svgs'] = svgs

    all_runs = sorted(set(list(summaries.keys()) + list(qualities.keys()) + list(scheduling.keys())))

    run_css = r'''
/* ===== Run Tab ===== */
.run-toolbar { display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px; }
.run-group-label { font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.6px;color:var(--text3);margin:8px 0 5px; }
.run-btn { padding:6px 14px;border:1px solid var(--border);border-radius:6px;background:var(--card-bg);font-size:11px;font-weight:600;color:var(--text);cursor:pointer;transition:all .15s; }
.run-btn:hover { border-color:var(--accent);color:var(--accent);transform:translateY(-1px); }
.run-btn.primary { background:var(--accent);color:#fff;border-color:var(--accent); }
.run-btn.primary:hover { opacity:.9;color:#fff; }
.run-btn.danger { background:#dc2626;color:#fff;border-color:#dc2626; }
.run-btn:disabled { opacity:.4;cursor:not-allowed;transform:none; }
.run-params { display:flex;gap:12px;align-items:center;flex-wrap:wrap;padding-top:6px;border-top:1px solid var(--border2); }
.run-params label { font-size:11px;color:var(--text2);font-weight:500; }
.run-params input,.run-params select { padding:4px 8px;border:1px solid var(--border);border-radius:5px;font-size:11px;background:var(--card-bg);color:var(--text); }
.run-params input { width:90px; }
.run-params input:focus,.run-params select:focus { outline:none;border-color:var(--accent); }
.run-output { max-height:500px;overflow-y:auto;font-size:10px;line-height:1.5; }
.run-success { display:none;margin-bottom:10px;padding:10px 12px;border:1px solid #86efac;border-left:4px solid #16a34a;border-radius:6px;background:#f0fdf4;color:#166534;font-size:12px;line-height:1.5; }
.run-success strong { font-weight:700; }
.run-success code { display:inline-block;max-width:100%;margin-top:4px;padding:2px 6px;border-radius:4px;background:rgba(22,101,52,.08);font-family:'SF Mono',Monaco,monospace;font-size:11px;color:#14532d;white-space:normal;word-break:break-all; }
[data-theme="dark"] .run-success { background:#052e16;border-color:#166534;color:#bbf7d0; }
[data-theme="dark"] .run-success code { background:rgba(187,247,208,.1);color:#dcfce7; }
.status-badge { display:inline-block;padding:2px 10px;border-radius:4px;font-size:11px;font-weight:600; }
.status-idle { background:var(--section-hdr);color:var(--text2); }
.status-running { background:#dbeafe;color:#2563eb; }
.status-completed { background:#dcfce7;color:#16a34a; }
.status-failed { background:#fee2e2;color:#dc2626; }
.status-cancelled { background:#fef3c7;color:#d97706; }
.boundary-grid { display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin-bottom:12px; }
.boundary-stat { background:var(--section-bg);border:1px solid var(--border);border-radius:6px;padding:8px 12px;text-align:center; }
.boundary-stat .val { font-size:22px;font-weight:700;color:var(--accent); }
.boundary-stat .lbl { font-size:9px;color:var(--text3);text-transform:uppercase;letter-spacing:.5px;margin-top:2px; }
.boundary-sub-tabs { display:flex;gap:4px;margin-bottom:8px;flex-wrap:wrap; }
.boundary-sub-tab { padding:3px 10px;border:1px solid var(--border);border-radius:4px;background:var(--card-bg);font-size:10px;color:var(--text2);cursor:pointer; }
.boundary-sub-tab.active { background:var(--accent);color:#fff;border-color:var(--accent); }
.boundary-panel { display:none; }
.boundary-panel.active { display:block; }
'''

    run_html = r'''
<!-- ============ RUN TAB ============ -->
<div id="tab-run" class="tab">
  <div class="card">
    <h2>Run Optimization &amp; Benchmark Tasks</h2>
    <div class="run-group-label">Stochastic UC &amp; Decomposition</div>
    <div class="run-toolbar">
      <button class="run-btn" onclick="runTask('boundary')">Boundary Check</button>
      <button class="run-btn primary" onclick="runTask('benchmark')">UC Benchmark (3-Way)</button>
      <button class="run-btn" onclick="runTask('ccg')">CCG</button>
      <button class="run-btn" onclick="runTask('benders')">Benders</button>
      <button class="run-btn" onclick="runTask('benders_fast')">Benders Fast</button>
      <button class="run-btn" onclick="runTask('tests')">Run All Tests</button>
    </div>
    <div class="run-group-label">Production Cost Modeling (PCM)</div>
    <div class="run-toolbar">
      <button class="run-btn" onclick="runTask('pcm_standard')">Standard PCM</button>
      <button class="run-btn" onclick="runTask('pcm_clustered')">Clustered PCM</button>
      <button class="run-btn" onclick="runTask('pcm_adaptive')">Adaptive Overlap</button>
      <button class="run-btn" onclick="runTask('pcm_clustered_adaptive')">Clustered Adaptive</button>
      <button class="run-btn primary" onclick="runTask('pcm_suite')">PCM Benchmark Suite</button>
      <button class="run-btn" id="rebuild-btn" onclick="rebuildDashboard()" style="margin-left:auto;">Rebuild &amp; Refresh Data</button>
      <button class="run-btn danger" id="run-cancel-btn" style="display:none" onclick="cancelRun()">Cancel</button>
    </div>
    <div class="run-params">
      <label>UC Scenarios:</label>
      <input type="text" id="run-scenario-counts" value="2,6,10" placeholder="counts" title="Scenario counts for UC benchmark (comma-separated)">
      <label>Limit:</label>
      <input type="number" id="run-scenario-limit" value="20" min="1" max="200" title="Scenario limit for individual CCG/Benders runs">
      <label>PCM Profile:</label>
      <select id="run-pcm-profile" title="Load profile for PCM runs">
        <option value="all">All Profiles</option>
        <option value="baseline">Baseline</option>
        <option value="smooth">Smooth</option>
        <option value="extreme_ramp">Extreme Ramp</option>
      </select>
      <span id="run-status-badge" class="status-badge status-idle">Idle</span>
      <span id="julia-status" style="margin-left:auto;font-size:10px;">Checking Julia...</span>
    </div>
  </div>
  <div class="card">
    <h2>Output</h2>
    <div id="run-success-msg" class="run-success"></div>
    <pre class="run-output" id="run-output">Ready. Select a task above to run.</pre>
  </div>
  <div id="boundary-results" style="display:none">
    <div class="card">
      <h2>System Boundary Summary</h2>
      <div class="boundary-grid" id="boundary-stats"></div>
      <div class="boundary-sub-tabs" id="boundary-sub-tabs"></div>
      <div id="boundary-validation" class="boundary-panel active"></div>
      <div id="boundary-units" class="boundary-panel"></div>
      <div id="boundary-lines" class="boundary-panel"></div>
      <div id="boundary-load" class="boundary-panel"></div>
      <div id="boundary-wind" class="boundary-panel"></div>
      <div id="boundary-config" class="boundary-panel"></div>
    </div>
  </div>
  <div id="test-results" style="display:none">
    <div class="card">
      <h2>Test Results Summary</h2>
      <div id="test-summary"></div>
    </div>
  </div>
</div>
'''

    run_js = r'''
// ============ RUN TAB ============
var juliaOk = null;
var boundaryActivePanel = 'validation';
let GUI_TOKEN = '';

async function apiFetch(url, options){
  const request = options || {};
  const headers = Object.assign({}, request.headers || {});
  if (GUI_TOKEN) headers.Authorization = 'Bearer ' + GUI_TOKEN;
  request.headers = headers;
  let response = await fetch(url, request);
  if (response.status === 401 && !GUI_TOKEN) {
    const token = window.prompt('Enter the GUI token (kept only in this page):');
    if (token) {
      GUI_TOKEN = token.trim();
      headers.Authorization = 'Bearer ' + GUI_TOKEN;
      response = await fetch(url, request);
    }
  }
  return response;
}

function escapeHTML(s){ return escapeHtml(String(s)); }

function checkJuliaStatus(){
  apiFetch('/api/check/julia').then(function(r){return r.json();}).then(function(d){
    juliaOk = d.ok;
    var el = $('julia-status');
    if (el) {
      el.innerHTML = d.ok
        ? '<span style="color:#16a34a;font-weight:600">Julia OK</span>'
        : '<span style="color:#dc2626;font-weight:600" title="' + escapeHTML(d.msg) + '">Julia unavailable: ' + escapeHTML((d.msg || '').split('\n')[0]) + '</span>';
    }
    setRunButtonsDisabled(!d.ok);
  }).catch(function(){
    juliaOk = null;
    var el = $('julia-status');
    if (el) el.innerHTML = '<span style="color:#dc2626;font-weight:600">Server unavailable (retrying...)</span>';
    setRunButtonsDisabled(false);
  });
}

function runTask(task){
  var params = {};
  if (task === 'boundary') params.scenario_limit = parseInt($('run-scenario-limit').value) || 5;
  else if (task === 'benchmark') params.scenario_counts = $('run-scenario-counts').value || '2,6,10';
  else if (task === 'ccg' || task === 'benders' || task === 'benders_fast') params.scenario_limit = parseInt($('run-scenario-limit').value) || 20;
  else if (task.indexOf('pcm_') === 0) params.pcm_profile = ($('run-pcm-profile') ? $('run-pcm-profile').value : 'all') || 'all';

  clearRunSuccess();
  $('boundary-results').style.display = 'none';
  $('test-results').style.display = 'none';
  $('run-output').textContent = 'Starting ' + task + '...\n';
  $('run-cancel-btn').style.display = 'inline-block';
  setRunButtonsDisabled(true);
  setStatusBadge('running');

  apiFetch('/api/run', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({task: task, params: params})
  }).then(function(r){return r.json();}).then(function(data){
    if (data.ok) startPolling();
    else {
      apiFetch('/api/run').then(function(r2){return r2.json();}).then(function(state){
        if (state.status === 'running') {
          $('run-output').textContent += '[INFO] A task is already running.\n';
          setStatusBadge('running');
          startPolling();
          return;
        }
        setStatusBadge('failed');
        $('run-cancel-btn').style.display = 'none';
        setRunButtonsDisabled(juliaOk === false);
        var txt = (state.output || []).join('');
        $('run-output').textContent = txt || ('[ERROR] ' + (data.error || 'Failed to start task') + '\n');
      });
    }
  }).catch(function(err){
    $('run-output').textContent += '[ERROR] ' + err.message + '\n';
    setStatusBadge('failed');
    $('run-cancel-btn').style.display = 'none';
    setRunButtonsDisabled(false);
  });
}

function cancelRun(){
  clearRunSuccess();
  apiFetch('/api/run/cancel', {method:'POST'}).then(function(r){return r.json();}).then(function(data){
    if (data.ok) {
      $('run-output').textContent += '\n[Cancelled by user]\n';
      setStatusBadge('cancelled');
      $('run-cancel-btn').style.display = 'none';
      setRunButtonsDisabled(juliaOk === false);
    }
  });
}

function startPolling(){
  if (runPollTimer) clearInterval(runPollTimer);
  runPollTimer = setInterval(pollRunStatus, 500);
  pollRunStatus();
}

function pollRunStatus(){
  apiFetch('/api/run').then(function(r){return r.json();}).then(function(state){
    var out = $('run-output');
    if (state.output && state.output.length) {
      var lastOutput = state.output.join('');
      if (state.output_len > state.output.length + 100) {
        lastOutput = '... (' + (state.output_len - state.output.length) + ' more lines) ...\n' + lastOutput;
      }
      out.textContent = lastOutput;
      out.scrollTop = out.scrollHeight;
    }
    if (state.status === 'running') {
      setStatusBadge('running');
      return;
    }
    if (runPollTimer) { clearInterval(runPollTimer); runPollTimer = null; }
    setStatusBadge(state.status || 'idle');
    $('run-cancel-btn').style.display = 'none';
    setRunButtonsDisabled(juliaOk === false);
    if (state.status === 'completed') {
      out.textContent += '\nTask completed.\n';
      renderRunSuccess(state.task, state);
      handleTaskResult(state.task, state.structured);
    } else if (state.status === 'failed') {
      out.textContent += '\nTask failed.\n';
    }
  }).catch(function(){
    if (runPollTimer) { clearInterval(runPollTimer); runPollTimer = null; }
  });
}

function setStatusBadge(status){
  var el = $('run-status-badge');
  if (!el) return;
  el.className = 'status-badge status-' + status;
  var map = {idle:'Idle', running:'Running...', completed:'Completed', failed:'Failed', cancelled:'Cancelled'};
  el.textContent = map[status] || status;
}

function setRunButtonsDisabled(disabled){
  document.querySelectorAll('.run-btn:not(.danger)').forEach(function(btn){ btn.disabled = disabled; });
}

function clearRunSuccess(){
  var el = $('run-success-msg');
  if (!el) return;
  el.style.display = 'none';
  el.innerHTML = '';
}

function renderRunSuccess(task, state){
  var el = $('run-success-msg');
  if (!el) return;
  var path = getRunResultPath(task, state || {});
  var taskName = taskLabel(task);
  var suffix = path
    ? 'Results saved to:<br><code>' + escapeHTML(path) + '</code>'
    : 'The result path was not returned. Check the Output log below.';
  el.innerHTML = '<strong>&#127881; Task ' + escapeHTML(taskName) + ' completed.</strong><br>' + suffix;
  el.style.display = 'block';
}

function taskLabel(task){
  var map = {
    boundary:'Boundary Check', benchmark:'UC Benchmark (3-Way)', ccg:'CCG',
    benders:'Benders', benders_fast:'Benders Fast', tests:'Run All Tests',
    pcm_standard:'Standard PCM', pcm_clustered:'Clustered PCM',
    pcm_adaptive:'Adaptive Overlap PCM', pcm_clustered_adaptive:'Clustered Adaptive PCM',
    pcm_suite:'PCM Benchmark Suite'
  };
  return map[task] || task || 'Unknown';
}

async function rebuildDashboard(){
  var btn = $('rebuild-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Rebuilding...'; }
  try {
    var r = await apiFetch('/api/rebuild', {method:'POST'});
    var d = await r.json();
    if (d.ok) {
      window.location.reload();
      return;
    }
    alert('Rebuild failed: ' + (d.error || r.status));
  } catch (e) {
    alert('Rebuild failed — is gui/server.py running?');
  }
  if (btn) { btn.disabled = false; btn.textContent = 'Rebuild & Refresh Data'; }
}

function getRunResultPath(task, state){
  if (state.result_path) return state.result_path;
  if (state.structured) {
    var fromStructured = findPathInObject(state.structured);
    if (fromStructured) return fromStructured;
  }
  if (Array.isArray(state.summaries) && state.summaries.length) {
    for (var i = state.summaries.length - 1; i >= 0; i--) {
      var p = findPathInObject(state.summaries[i]);
      if (p) return p;
    }
  }
  return findPathInDataSummaries(task);
}

function findPathInObject(obj){
  if (!obj || typeof obj !== 'object') return '';
  var preferred = ['log_path', 'result_path', 'data_path', 'file_path', 'path'];
  for (var i = 0; i < preferred.length; i++) {
    var v = obj[preferred[i]];
    if (typeof v === 'string' && v) return v;
  }
  if (Array.isArray(obj)) {
    for (var j = obj.length - 1; j >= 0; j--) {
      var p = findPathInObject(obj[j]);
      if (p) return p;
    }
  }
  return '';
}

function findPathInDataSummaries(task){
  var expected = {benchmark:'benchmark_uc', benders_fast:'benders'}[task] || task;
  var newest = '';
  Object.keys(DATA.summaries || {}).sort().reverse().some(function(run){
    var rows = DATA.summaries[run] || [];
    if (!rows.length) return false;
    var header = rows[0].map(function(h){ return String(h).toLowerCase(); });
    var pathIdx = header.indexOf('log_path');
    if (pathIdx < 0) pathIdx = header.indexOf('result_path');
    if (pathIdx < 0) pathIdx = header.indexOf('path');
    if (pathIdx < 0) return false;
    for (var i = rows.length - 1; i >= 1; i--) {
      var algo = String(rows[i][0] || '');
      var path = rows[i][pathIdx];
      if (path && (!expected || algo === expected || task === 'benchmark')) {
        newest = path;
        return true;
      }
    }
    return false;
  });
  return newest;
}

function handleTaskResult(task, structured){
  if (task === 'boundary' && structured) {
    $('boundary-results').style.display = 'block';
    renderBoundaryData(structured);
  }
  if (task === 'tests') {
    $('test-results').style.display = 'block';
    renderTestResults();
  }
}

function renderBoundaryData(d){
  var sys = d.system || {};
  var totals = d.totals || {};
  var items = [
    ['Buses', sys.NB], ['Generators', sys.NG], ['Lines', sys.NL],
    ['Loads', sys.ND], ['Time Periods', sys.NT], ['Wind Units', sys.NW],
    ['Scenarios', sys.NS], ['Storage Units', sys.NC],
    ['Total Pmax (MW)', fmt(totals.total_pmax, 1)],
    ['Peak Load (MW)', fmt(totals.peak_load, 1)],
    ['Wind Capacity (MW)', fmt(totals.total_wind_cap, 1)]
  ];
  $('boundary-stats').innerHTML = items.map(function(i){
    return '<div class="boundary-stat"><div class="val">' + escapeHTML(i[1] == null ? '-' : i[1]) + '</div><div class="lbl">' + escapeHTML(i[0]) + '</div></div>';
  }).join('');

  var subtabs = [
    {id:'validation', label:'Validation'}, {id:'units', label:'Units'},
    {id:'lines', label:'Lines'}, {id:'load', label:'Load'},
    {id:'wind', label:'Wind'}, {id:'config', label:'Config'}
  ];
  $('boundary-sub-tabs').innerHTML = subtabs.map(function(t){
    return '<button class="boundary-sub-tab' + (t.id === boundaryActivePanel ? ' active' : '') + '" data-bpanel="' + t.id + '">' + t.label + '</button>';
  }).join('');
  $('boundary-sub-tabs').onclick = function(e){
    var b = e.target.closest('.boundary-sub-tab');
    if (!b) return;
    boundaryActivePanel = b.dataset.bpanel;
    document.querySelectorAll('.boundary-sub-tab').forEach(function(x){ x.classList.remove('active'); });
    b.classList.add('active');
    document.querySelectorAll('.boundary-panel').forEach(function(x){ x.classList.remove('active'); });
    $('boundary-' + b.dataset.bpanel).classList.add('active');
  };

  renderBoundaryValidation(d.validation);
  renderObjectTable('boundary-units', d.units, 'No unit data');
  renderObjectTable('boundary-lines', d.lines, 'No line data');
  renderObjectTable('boundary-load', d.load_totals, 'No load data');
  renderObjectTable('boundary-wind', d.wind, 'No wind data');
  renderObjectTable('boundary-config', d.config, 'No config data');
}

function renderBoundaryValidation(checks){
  if (!checks || !checks.length) { $('boundary-validation').innerHTML = '<div class="empty-state">No validation data</div>'; return; }
  var h = '<table><thead><tr><th>Check</th><th>Status</th></tr></thead><tbody>';
  checks.forEach(function(c){
    h += '<tr><td>' + escapeHTML(c.label) + '</td><td><span class="badge ' + (c.ok ? 'badge-ok' : 'badge-err') + '">' + (c.ok ? 'PASS' : 'FAIL') + '</span></td></tr>';
  });
  $('boundary-validation').innerHTML = h + '</tbody></table>';
}

function renderObjectTable(id, data, emptyText){
  var el = $(id);
  if (!data || (Array.isArray(data) && !data.length)) { el.innerHTML = '<div class="empty-state">' + emptyText + '</div>'; return; }
  if (!Array.isArray(data)) {
    var sections = Object.entries(data).map(function(e){
      if (Array.isArray(e[1]) && e[1].length && typeof e[1][0] === 'object') {
        return '<h3 style="font-size:11px;margin:6px 0 4px;color:var(--text2)">' + escapeHTML(e[0]) + '</h3>' + tableHtml(e[1]);
      }
      return '<h3 style="font-size:11px;margin:6px 0 4px;color:var(--text2)">' + escapeHTML(e[0]) + '</h3><p style="font-size:11px;margin-bottom:8px;">' + escapeHTML(Array.isArray(e[1]) ? e[1].join(', ') : e[1]) + '</p>';
    }).join('');
    el.innerHTML = '<div style="overflow-x:auto;max-height:400px;overflow-y:auto;">' + sections + '</div>';
    return;
  }
  el.innerHTML = tableHtml(data);
}

function tableHtml(data){
  var keys = Array.from(new Set(data.flatMap(function(row){ return Object.keys(row); })));
  var h = '<div style="overflow-x:auto;max-height:400px;overflow-y:auto;"><table><thead><tr>' + keys.map(function(k){return '<th>' + escapeHTML(k) + '</th>';}).join('') + '</tr></thead><tbody>';
  data.forEach(function(row){
    h += '<tr>' + keys.map(function(k){ return '<td>' + escapeHTML(row[k] == null ? '' : row[k]) + '</td>'; }).join('') + '</tr>';
  });
  return h + '</tbody></table></div>';
}

function renderTestResults(){
  var out = $('run-output').textContent;
  var passed = (out.match(/Test.*Passed|passed/g) || []).length;
  var failed = (out.match(/Test.*Failed|FAILED|failed|Error/g) || []).length;
  $('test-summary').innerHTML = '<div class="metrics"><div class="metric"><div class="label">Passed</div><div class="value" style="color:#16a34a">' + passed + '</div></div><div class="metric"><div class="label">Failed/Errors</div><div class="value" style="color:' + (failed ? '#dc2626' : '#94a3b8') + '">' + failed + '</div></div></div>';
}
'''

    # ============ HTML + PLOTLY.JS ============
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Unit Commitment Results Dashboard</title>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
:root {{ --bg:#f0f2f5;--card-bg:#fff;--text:#1e293b;--text2:#64748b;--text3:#94a3b8;--border:#e2e8f0;--border2:#f1f5f9;--header-from:#0f172a;--header-to:#1e3a5f;--accent:#2563eb;--accent-bg:#eff6ff;--hover-bg:#f8fafc;--pre-bg:#1e293b;--pre-fg:#e2e8f0;--th-bg:#f8fafc;--section-bg:#f8fafc;--section-hdr:#e2e8f0;--section-text:#334155; }}
[data-theme="dark"] {{ --bg:#111827;--card-bg:#1f2937;--text:#e5e7eb;--text2:#9ca3af;--text3:#6b7280;--border:#374151;--border2:#1f2937;--header-from:#030712;--header-to:#111827;--accent:#3b82f6;--accent-bg:#1e3a5f;--hover-bg:#283548;--pre-bg:#030712;--pre-fg:#d1d5db;--th-bg:#1f2937;--section-bg:#1f2937;--section-hdr:#374151;--section-text:#d1d5db; }}
[data-theme="forest"] {{ --bg:#ecfdf5;--card-bg:#fff;--text:#064e3b;--text2:#64748b;--text3:#94a3b8;--border:#d1fae5;--border2:#ecfdf5;--header-from:#064e3b;--header-to:#059669;--accent:#059669;--accent-bg:#d1fae5;--hover-bg:#f0fdf4;--pre-bg:#064e3b;--pre-fg:#d1fae5;--th-bg:#f0fdf4;--section-bg:#f0fdf4;--section-hdr:#d1fae5;--section-text:#065f46; }}
[data-theme="sunset"] {{ --bg:#fff7ed;--card-bg:#fff;--text:#431407;--text2:#9a3412;--text3:#c2410c;--border:#fed7aa;--border2:#fff7ed;--header-from:#7c2d12;--header-to:#c2410c;--accent:#ea580c;--accent-bg:#ffedd5;--hover-bg:#fff7ed;--pre-bg:#431407;--pre-fg:#fed7aa;--th-bg:#fffbeb;--section-bg:#fffbeb;--section-hdr:#fed7aa;--section-text:#9a3412; }}
[data-theme="ocean"] {{ --bg:#f0f9ff;--card-bg:#fff;--text:#0c4a6e;--text2:#64748b;--text3:#94a3b8;--border:#e0f2fe;--border2:#f0f9ff;--header-from:#0c4a6e;--header-to:#0284c7;--accent:#0284c7;--accent-bg:#e0f2fe;--hover-bg:#f0f9ff;--pre-bg:#0c4a6e;--pre-fg:#bae6fd;--th-bg:#f0f9ff;--section-bg:#f0f9ff;--section-hdr:#bae6fd;--section-text:#0369a1; }}

* {{ margin:0;padding:0;box-sizing:border-box; }}
body {{ font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);line-height:1.4; }}
.header {{ background:linear-gradient(135deg,var(--header-from),var(--header-to));color:#fff;padding:14px 24px;display:flex;justify-content:space-between;align-items:center; }}
.header h1 {{ font-size:17px;font-weight:600; }}
.header span {{ opacity:.6;font-size:11px; }}
.header-left {{ display:flex;flex-direction:column;gap:2px; }}
.theme-switcher {{ display:flex;gap:4px; }}
.theme-dot {{ width:20px;height:20px;border-radius:50%;border:2px solid rgba(255,255,255,.3);cursor:pointer;transition:all .15s; }}
.theme-dot:hover {{ border-color:#fff;transform:scale(1.15); }}
.theme-dot.active {{ border-color:#fff;box-shadow:0 0 0 2px rgba(255,255,255,.5); }}

.nav {{ background:var(--card-bg);border-bottom:1px solid var(--border);padding:0 18px;display:flex;gap:0;overflow-x:auto;position:sticky;top:0;z-index:10; }}
.nav-btn {{ padding:9px 14px;border:none;background:none;cursor:pointer;font-size:12px;color:var(--text2);border-bottom:2px solid transparent;white-space:nowrap;transition:all .15s; }}
.nav-btn:hover {{ color:var(--accent); }}
.nav-btn.active {{ color:var(--accent);border-bottom-color:var(--accent);font-weight:600; }}

.main {{ padding:14px 20px;max-width:1500px;margin:0 auto; }}
.tab {{ display:none; }}
.tab.active {{ display:block; }}

.card {{ background:var(--card-bg);border-radius:8px;box-shadow:0 1px 2px rgba(0,0,0,.06);padding:14px;margin-bottom:12px; }}
.card h2 {{ font-size:13px;margin-bottom:10px;color:var(--text);display:flex;align-items:center;gap:8px; }}
.card h2::before {{ content:'';width:3px;height:13px;background:var(--accent);border-radius:2px;flex-shrink:0; }}

.metrics {{ display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px;margin-bottom:12px; }}
.metric {{ background:var(--card-bg);border:1px solid var(--border2);border-radius:10px;padding:12px 15px;box-shadow:0 1px 3px rgba(0,0,0,.04);position:relative;overflow:hidden; }}
.metric::after {{ content:'';position:absolute;top:0;left:0;right:0;height:3px;background:var(--metric-accent,var(--accent));opacity:.85; }}
.metric .label {{ font-size:10px;color:var(--text3);text-transform:uppercase;letter-spacing:.5px;font-weight:600; }}
.metric .value {{ font-size:21px;font-weight:700;color:var(--text);margin-top:4px;font-variant-numeric:tabular-nums; }}
.metric .sub {{ font-size:10px;color:var(--text2);margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }}

.perf-grid-2 {{ display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-bottom:12px; }}
.perf-card {{ background:var(--section-bg);border:1px solid var(--border);border-radius:8px;padding:10px 12px; }}
.perf-card h3 {{ font-size:11px;font-weight:700;color:var(--text2);text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px; }}
.plot-mini {{ width:100%;height:310px;min-height:310px; }}
.plot-dual {{ width:100%;height:400px;min-height:400px; }}
@media (max-width:960px) {{ .perf-grid-2 {{ grid-template-columns:1fr; }} }}

.method-pill {{ display:inline-flex;align-items:center;gap:5px;padding:2px 8px;border-radius:999px;font-size:10px;font-weight:600;background:var(--section-bg);border:1px solid var(--border); }}
.method-dot {{ width:7px;height:7px;border-radius:50%;flex-shrink:0; }}
.bar-wrap {{ display:flex;align-items:center;gap:6px;min-width:110px; }}
.bar-track {{ flex:1;height:6px;border-radius:999px;background:var(--border);overflow:hidden; }}
.bar-fill {{ height:100%;border-radius:999px;background:var(--accent); }}
.num {{ font-variant-numeric:tabular-nums;font-family:'SF Mono',Monaco,ui-monospace,monospace;font-size:10.5px; }}
.speedup-chip {{ display:inline-block;padding:1px 6px;border-radius:4px;font-size:10px;font-weight:700;font-variant-numeric:tabular-nums; }}
.speedup-fast {{ background:#dcfce7;color:#15803d; }}
.speedup-base {{ background:var(--section-hdr);color:var(--text2); }}
.speedup-slow {{ background:#fef3c7;color:#b45309; }}
.source-tag {{ display:inline-block;padding:2px 8px;border-radius:999px;font-size:10px;font-weight:600;background:var(--accent-bg);color:var(--accent);margin-left:auto; }}

table {{ width:100%;border-collapse:collapse;font-size:11px; }}
th,td {{ padding:5px 7px;text-align:left;border-bottom:1px solid var(--border2); }}
th {{ background:var(--th-bg);color:var(--text2);font-weight:600;font-size:10px;text-transform:uppercase;letter-spacing:.3px;position:sticky;top:0; }}
tr:hover td {{ background:var(--hover-bg); }}

.badge {{ display:inline-block;padding:1px 7px;border-radius:3px;font-size:10px;font-weight:600; }}
.badge-ok {{ background:#dcfce7;color:#16a34a; }} .badge-warn {{ background:#fef3c7;color:#d97706; }}
.badge-err {{ background:#fee2e2;color:#dc2626; }} .badge-info {{ background:#dbeafe;color:#2563eb; }}
.gap-good {{ color:#16a34a;font-weight:600; }} .gap-bad {{ color:#dc2626;font-weight:600; }}

.ctrl {{ display:flex;gap:8px;align-items:center;margin-bottom:10px;flex-wrap:wrap; }}
.ctrl label {{ font-size:11px;color:var(--text2); }}
.ctrl select {{ padding:3px 7px;border:1px solid var(--border);border-radius:5px;font-size:11px;background:var(--card-bg);color:var(--text);max-width:260px; }}
.ctrl select:focus {{ outline:none;border-color:var(--accent); }}

.chart-stage {{ display:flex;justify-content:center;align-items:stretch;width:100%;min-height:480px;margin:8px 0 14px; }}
.plot-div {{ width:100%;max-width:1280px;height:480px;min-height:480px; }}
.chart-stage pre.short {{ width:100%;height:480px;max-height:480px; }}
.table-stack {{ display:grid;gap:12px; }}
.data-block h3 {{ font-size:12px;margin:2px 0 8px;color:var(--text);font-weight:600; }}
.table-panel {{ overflow-x:auto;max-height:300px;overflow-y:auto;border:1px solid var(--border2);border-radius:6px; }}
.table-panel.tight {{ max-height:280px; }}

pre {{ font-family:'SF Mono',Monaco,monospace;font-size:10px;line-height:1.4;overflow-x:auto;white-space:pre;max-height:480px;overflow-y:auto;background:var(--pre-bg);color:var(--pre-fg);padding:12px;border-radius:6px; }}
pre.short {{ max-height:220px; }}

.reports-shell {{ display:grid;gap:12px; }}
.report-toolbar {{ display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:10px; }}
.report-toolbar label {{ font-size:11px;color:var(--text2); }}
.report-toolbar select {{ padding:3px 7px;border:1px solid var(--border);border-radius:5px;font-size:11px;background:var(--card-bg);color:var(--text);max-width:280px; }}
.chart-tabs {{ display:flex;gap:6px;flex-wrap:wrap;margin:8px 0 10px; }}
.chart-tab {{ padding:5px 10px;border:1px solid var(--border);border-radius:6px;background:var(--card-bg);font-size:11px;color:var(--text2);cursor:pointer;transition:all .15s; }}
.chart-tab:hover {{ border-color:var(--accent);color:var(--accent); }}
.chart-tab.active {{ background:var(--accent);color:#fff;border-color:var(--accent);box-shadow:0 3px 10px rgba(37,99,235,.16); }}
.report-svg-wrap {{ background:var(--hover-bg);border:1px solid var(--border);border-radius:8px;padding:10px;min-height:460px;overflow:auto;transition:background .2s,border-color .2s; }}
.report-svg-stage {{ min-width:760px;transform-origin:top left;transition:transform .15s; }}
.report-svg-stage svg {{ width:100%;height:auto;display:block;border-radius:6px;background:var(--card-bg); }}
.report-svg-wrap.dark-chart {{ background:#1e1e1e;border-color:#3f3f46; }}
.report-svg-wrap.dark-chart .report-svg-stage svg {{ background:#2a2a2a; }}
.svg-tools {{ margin-left:auto;display:flex;gap:4px; }}
.svg-tool {{ width:28px;height:24px;border:1px solid var(--border);border-radius:5px;background:var(--card-bg);color:var(--text);cursor:pointer;font-size:12px; }}
.svg-tool:hover {{ border-color:var(--accent);color:var(--accent); }}
.svg-hotspot {{ cursor:pointer;transition:opacity .15s,stroke-width .15s; }}
.svg-hotspot:hover {{ opacity:.82; }}
.svg-selected {{ stroke:var(--accent)!important;stroke-width:4!important; }}
.report-body {{ font-size:12px;line-height:1.6;max-height:520px;overflow-y:auto;padding:12px;background:var(--section-bg);border:1px solid var(--border);border-radius:8px; }}

.settings-grid {{ display:grid;grid-template-columns:repeat(auto-fit,minmax(450px,1fr));gap:20px;align-items:start; }}
.settings-category {{ background:var(--card-bg);border:1px solid var(--border);border-radius:12px;padding:18px;box-shadow:0 4px 6px -1px rgba(0,0,0,.05);min-width:0;transition:background .2s ease,border-color .2s ease,box-shadow .2s ease; }}
.settings-category legend {{ padding:0 6px;font-size:13px;font-weight:700;color:var(--text); }}
.settings-category .category-note {{ margin:4px 0 14px;font-size:10px;color:var(--text3);line-height:1.5; }}
.setting-control {{ display:grid;grid-template-columns:1.2fr 2fr;gap:16px;align-items:center;margin-bottom:14px;padding:12px;border:1px solid var(--border);border-radius:10px;background:var(--section-bg); }}
.setting-control label {{ font-size:11px;font-weight:600;color:var(--text);text-align:left; }}
.setting-control select,.field select,.field input[type="text"],.field input[type="number"] {{ width:100%;min-height:34px;padding:7px 10px;border:1px solid var(--border);border-radius:7px;background:var(--card-bg);color:var(--text);font-family:inherit;font-size:12px;box-shadow:none;transition:all .2s ease;accent-color:var(--accent); }}
.setting-control select option,.field select option {{ background:var(--card-bg);color:var(--text); }}
.setting-control select:focus,.field select:focus,.field input:focus {{ outline:none;border-color:var(--accent);box-shadow:0 0 0 3px color-mix(in srgb,var(--accent) 18%,transparent); }}
.setting-panels {{ display:grid;gap:12px; }}
.setting-panel {{ display:grid;gap:12px;max-height:0;opacity:0;overflow:hidden;transform:translateY(-4px);pointer-events:none;transition:max-height .24s ease,opacity .2s ease,transform .2s ease; }}
.setting-panel.active {{ max-height:2400px;opacity:1;transform:translateY(0);pointer-events:auto; }}
.setting-panel.sf-hidden {{ max-height:0;opacity:0;pointer-events:none; }}
.setting-panel-note {{ padding:9px 11px;border:1px dashed var(--border);border-radius:8px;background:var(--hover-bg);color:var(--text2);font-size:11px;line-height:1.5; }}
.settings-section {{ background:var(--section-bg);border:1px solid var(--border);border-radius:9px;overflow:hidden;margin-bottom:0; }}
.settings-section:last-child {{ margin-bottom:0; }}
.settings-section h3 {{ font-size:11px;padding:8px 11px;background:var(--section-hdr);color:var(--section-text);font-weight:600; }}
.settings-section .fields {{ display:grid;grid-template-columns:1fr;gap:9px;padding:12px; }}
.field {{ display:grid;grid-template-columns:1.2fr 2fr;align-items:center;padding:8px 10px;border:1px solid var(--border2);border-radius:8px;background:var(--card-bg);gap:16px;min-height:42px; }}
.field:last-child {{ border-bottom:none; }}
.field label {{ font-size:11px;color:var(--text);flex:1;cursor:pointer;overflow:hidden;text-overflow:ellipsis;text-align:left; }}
.field input[type="text"],.field input[type="number"] {{ text-align:right; }}
.field input[type="checkbox"] {{ width:16px;height:16px;accent-color:var(--accent);justify-self:end; }}
[data-theme="dark"] .setting-control select,[data-theme="dark"] .field select,[data-theme="dark"] .field input[type="text"],[data-theme="dark"] .field input[type="number"] {{ background:#111827;color:#e5e7eb;border-color:#374151; }}
[data-theme="dark"] .setting-control select option,[data-theme="dark"] .field select option {{ background:#111827;color:#e5e7eb; }}
@media (max-width:980px) {{ .settings-grid {{ grid-template-columns:1fr; }} }}
@media (max-width:560px) {{ .settings-grid {{ grid-template-columns:1fr;gap:14px; }} .settings-category {{ padding:14px; }} .setting-control,.field {{ grid-template-columns:1fr;gap:7px; }} .field input[type="checkbox"] {{ justify-self:start; }} }}

.save-bar {{ display:flex;align-items:center;gap:10px;margin-bottom:12px; }}
.save-bar button {{ padding:6px 16px;background:var(--accent);color:#fff;border:none;border-radius:5px;font-size:12px;cursor:pointer;font-weight:600; }}
.save-bar button:hover {{ opacity:.85; }}
.save-bar button:disabled {{ opacity:.5;cursor:not-allowed; }}
.save-bar .msg {{ font-size:11px; }}
.save-bar .msg.ok {{ color:#16a34a; }} .save-bar .msg.err {{ color:#dc2626; }}

.view-tabs,.sched-tabs {{ display:flex;gap:4px;margin-bottom:10px;flex-wrap:wrap; }}
.view-tab,.sched-tab {{ padding:4px 10px;border:1px solid var(--border);border-radius:5px;background:var(--card-bg);font-size:11px;color:var(--text2);cursor:pointer;transition:all .15s; }}
.view-tab:hover,.sched-tab:hover {{ border-color:var(--accent);color:var(--accent); }}
.view-tab.active,.sched-tab.active {{ background:var(--accent);color:#fff;border-color:var(--accent); }}

.cost-grid {{ display:grid;grid-template-columns:1fr 1fr;gap:12px;width:100%;height:480px; }}
.cost-grid .plot-div {{ height:480px;min-height:480px; }}
@media (max-width:700px) {{ .cost-grid {{ grid-template-columns:repeat(2,minmax(260px,1fr));overflow-x:auto; }} }}

.empty-state {{ padding:40px;text-align:center;color:var(--text3);font-size:13px; }}
.plot-div > .empty-state {{ height:480px;display:flex;align-items:center;justify-content:center;padding:0; }}
{run_css}
</style>
</head>
<body>

<div class="header">
  <div class="header-left"><h1>ModuleUnitCommitmentToolkit &middot; Performance &amp; Results Workbench</h1><span>Benchmark UC &middot; Benders &middot; CCG &middot; Standard PCM &middot; Clustered PCM &middot; Adaptive Overlap &middot; Clustered Adaptive</span></div>
  <div class="theme-switcher" id="theme-switcher"></div>
</div>

<div class="nav" id="nav"></div>

<div class="main">

<div id="tab-overview" class="tab active">
  <div class="metrics" id="overview-metrics"></div>
  <div class="card">
    <h2>Stochastic UC Methods &mdash; Performance &amp; Result Matrix</h2>
    <div class="ctrl">
      <label>Run</label><select id="ov-run"></select>
      <label>Algorithm Filter</label><select id="ov-algo"><option value="">All Algorithms</option></select>
    </div>
    <div class="perf-grid-2">
      <div class="perf-card"><h3>Solve Time (s) by Algorithm &amp; Scenarios</h3><div id="ov-chart-time" class="plot-mini"></div></div>
      <div class="perf-card"><h3>Optimality Gap (Log Scale)</h3><div id="ov-chart-gap" class="plot-mini"></div></div>
      <div class="perf-card"><h3>Objective Value (Lower vs Upper Bound)</h3><div id="ov-chart-obj" class="plot-mini"></div></div>
      <div class="perf-card"><h3>Peak Memory Usage (RAM MB)</h3><div id="ov-chart-ram" class="plot-mini"></div></div>
    </div>
  </div>
  <div class="card"><h2>Algorithm Comparison Summary</h2><div style="overflow-x:auto;max-height:460px;overflow-y:auto;"><table id="summary-table"></table></div></div>
</div>

<div id="tab-pcm" class="tab">
  <div class="metrics" id="pcm-metrics"></div>
  <div class="card">
    <h2>PCM Multi-Method Performance &amp; Solution Comparison <span id="pcm-source-tag" class="source-tag"></span></h2>
    <div class="ctrl">
      <label>Scale / Dataset</label><select id="pcm-dataset"></select>
      <label>Load Profile</label>
      <select id="pcm-profile">
        <option value="">All Profiles</option>
        <option value="baseline">Baseline</option>
        <option value="smooth">Smooth</option>
        <option value="extreme_ramp">Extreme Ramp</option>
      </select>
    </div>
    <div class="view-tabs" id="pcm-view-tabs"></div>
    <div class="perf-grid-2">
      <div class="perf-card"><h3 id="pcm-chart1-title">Solve Time (s)</h3><div id="pcm-chart1" class="plot-dual"></div></div>
      <div class="perf-card"><h3 id="pcm-chart2-title">Speedup Ratio vs Standard PCM</h3><div id="pcm-chart2" class="plot-dual"></div></div>
    </div>
    <div class="data-block">
      <h3>Detailed PCM Performance &amp; Economic Metrics</h3>
      <div class="table-panel" style="max-height:420px;"><table id="pcm-table"></table></div>
    </div>
  </div>
</div>

<div id="tab-quality" class="tab">
  <div class="card"><h2>Results &amp; Charts</h2>
    <div class="ctrl"><label>Run</label><select id="ql-run"></select><label>Algorithm</label><select id="ql-algo"><option value="">All</option></select><label>Scenarios</label><select id="ql-scen"><option value="">All</option></select></div>
    <div class="view-tabs" id="ql-view-tabs"></div>
    <div class="chart-stage"><div id="ql-plot" class="plot-div"></div></div>
    <div class="table-stack">
      <div class="data-block"><h3>Power Balance Quality</h3><div class="table-panel tight"><table id="ql-quality-table"></table></div></div>
      <div class="data-block"><h3>Iteration History</h3><div class="table-panel"><table id="ql-iter-table"></table></div></div>
    </div>
  </div>
</div>

<div id="tab-schedule" class="tab">
  <div class="card"><h2>Schedule Details</h2>
    <div class="ctrl"><label>Run</label><select id="sc-run"></select><label>Algorithm</label><select id="sc-algo"></select></div>
    <div class="sched-tabs" id="sc-tabs"></div>
    <div class="chart-stage"><div id="sc-plot" class="plot-div"></div></div>
    <div class="table-panel"><table id="sc-table"></table></div>
  </div>
</div>

<div id="tab-reports" class="tab">
  <div class="reports-shell">
    <div class="card"><h2>Report Charts</h2>
      <div class="report-toolbar">
        <label>Run</label><select id="svg-run"></select>
        <div class="svg-tools">
          <button class="svg-tool" id="svg-zoom-out" title="Zoom out">-</button>
          <button class="svg-tool" id="svg-zoom-reset" title="Reset zoom">1x</button>
          <button class="svg-tool" id="svg-zoom-in" title="Zoom in">+</button>
        </div>
      </div>
      <div class="chart-tabs" id="svg-chart-tabs"></div>
      <div id="svg-display" class="report-svg-wrap"><div class="empty-state">No SVG</div></div>
    </div>
    <div class="card"><h2>Benchmark Reports</h2>
      <div class="report-toolbar"><label>Run</label><select id="rp-run"></select></div>
      <div id="rp-content" class="report-body"></div>
    </div>
  </div>
</div>

<div id="tab-settings" class="tab">
  <div class="card"><h2>Runtime Configuration</h2>
    <div class="save-bar"><button id="save-config-btn" onclick="saveConfig()">Save Changes</button><span class="msg" id="save-msg"></span></div>
    <div class="settings-grid" id="settings-grid"></div>
  </div>
</div>
{run_html}

</div>

<script>
const DATA = {json.dumps(data, ensure_ascii=False)};

const TABS = [
  {{id:'overview',label:'Overview'}},
  {{id:'pcm',label:'PCM Benchmark'}},
  {{id:'quality',label:'Quality & Convergence'}},
  {{id:'schedule',label:'Schedule'}},
  {{id:'reports',label:'Reports'}},
  {{id:'run',label:'Run Tasks'}},
  {{id:'settings',label:'Settings'}}
];
const ACOL = {{
  benchmark_uc:'#3b82f6', benders:'#ef4444', ccg:'#10b981',
  standard:'#64748b', clustered_pcm:'#f59e0b', adaptive_overlap:'#06b6d4', clustered_adaptive_overlap:'#8b5cf6'
}};
const ALABEL = {{
  benchmark_uc:'Benchmark UC', benders:'Benders', ccg:'CCG',
  standard:'Standard PCM', clustered_pcm:'Clustered PCM',
  adaptive_overlap:'Adaptive Overlap', clustered_adaptive_overlap:'Clustered Adaptive'
}};
const C10 = ['#3b82f6','#ef4444','#10b981','#f59e0b','#06b6d4','#8b5cf6','#ec4899','#14b8a6','#f97316','#6366f1'];
const PLCFG = {{responsive:true,displayModeBar:true,displaylogo:false,modeBarButtonsToRemove:['lasso2d','select2d','autoScale2d'],toImageButtonOptions:{{format:'png',height:600,width:1000,scale:2}}}};
const PLMARGIN = {{l:58,r:18,t:24,b:46}};
let qlActive='curtailment';
let scActive='dispatch';
let pcmActiveView='perf';
let runPollTimer = null;
let activeSvgChart = '';
let svgZoom = 1;
let themeObserver = null;

function $(id){{return document.getElementById(id);}}
function fmt(n,d){{if(n===null||n===undefined||n==='')return'—';const v=Number(n);return Number.isNaN(v)?String(n):v.toFixed(d===undefined?2:d);}}
function pl(id){{const d=document.getElementById(id);if(d)Plotly.purge(d);return d;}}
function getPlotTheme(){{
  const dark=isDarkTheme();
  return {{
    paper_bgcolor:'rgba(0,0,0,0)',
    plot_bgcolor:'rgba(0,0,0,0)',
    font:{{color:dark?'#e5e7eb':'#1e293b',size:11}},
    gridcolor:dark?'#374151':'#e2e8f0'
  }};
}}
function show(id,data,layout){{
  const th=getPlotTheme();
  const base={{
    height:480,margin:PLMARGIN,hovermode:'x unified',
    paper_bgcolor:th.paper_bgcolor,plot_bgcolor:th.plot_bgcolor,font:th.font,
    legend:{{orientation:'h',y:-0.2,x:0}},
    xaxis:{{tickfont:{{size:10}},gridcolor:th.gridcolor}},
    yaxis:{{tickfont:{{size:10}},title:{{font:{{size:11}}}},gridcolor:th.gridcolor}}
  }};
  const merged=Object.assign({{}},base,layout||{{}});
  merged.xaxis=Object.assign({{}},base.xaxis,(layout&&layout.xaxis)||{{}});
  merged.yaxis=Object.assign({{}},base.yaxis,(layout&&layout.yaxis)||{{}});
  Plotly.newPlot(pl(id),data,merged,PLCFG);
}}
function showCompact(id,data,layout,h){{
  const th=getPlotTheme();
  const base={{
    height:h||310,margin:{{l:56,r:16,t:16,b:44}},hovermode:'closest',
    paper_bgcolor:th.paper_bgcolor,plot_bgcolor:th.plot_bgcolor,font:th.font,
    legend:{{orientation:'h',y:-0.24,x:0,font:{{size:10}}}},
    xaxis:{{tickfont:{{size:10}},gridcolor:th.gridcolor}},
    yaxis:{{tickfont:{{size:10}},title:{{font:{{size:10}}}},gridcolor:th.gridcolor}}
  }};
  const merged=Object.assign({{}},base,layout||{{}});
  merged.xaxis=Object.assign({{}},base.xaxis,(layout&&layout.xaxis)||{{}});
  merged.yaxis=Object.assign({{}},base.yaxis,(layout&&layout.yaxis)||{{}});
  Plotly.newPlot(pl(id),data,merged,PLCFG);
}}
function methodPill(m){{
  const c=ACOL[m]||'#64748b';
  const lbl=ALABEL[m]||m;
  return '<span class="method-pill"><span class="method-dot" style="background:'+c+'"></span>'+escapeHTML(lbl)+'</span>';
}}

function init(){{
  try{{var s=localStorage.getItem('uc-theme');}}catch(e){{s=null;}}
  if(s)document.documentElement.dataset.theme=s;
  buildThemeSwitcher();buildNav();
  initThemeWatcher();
  renderOverview();renderPcm();renderQuality();renderSchedule();renderReports();renderSettings();
}}

const THEMES=[{{id:'',label:'Default',color:'#2563eb'}},{{id:'dark',label:'Dark',color:'#1f2937'}},{{id:'forest',label:'Forest',color:'#059669'}},{{id:'sunset',label:'Sunset',color:'#ea580c'}},{{id:'ocean',label:'Ocean',color:'#0284c7'}}];

function buildThemeSwitcher(){{
  const c=document.documentElement.dataset.theme||'';
  $('theme-switcher').innerHTML=THEMES.map(function(t){{return'<div class="theme-dot'+(t.id===c?' active':'')+'" data-theme="'+t.id+'" title="'+t.label+'" style="background:'+t.color+'"></div>';}}).join('');
  $('theme-switcher').onclick=function(e){{const d=e.target.closest('.theme-dot');if(!d)return;const t=d.dataset.theme;document.documentElement.dataset.theme=t;document.querySelectorAll('.theme-dot').forEach(function(x){{x.classList.remove('active');}});d.classList.add('active');try{{localStorage.setItem('uc-theme',t);}}catch(e){{}}applyReportTheme();renderOverviewCharts();renderPcmView();switchQl();switchSc();}};
}}

function initThemeWatcher(){{
  if(themeObserver)themeObserver.disconnect();
  themeObserver=new MutationObserver(function(){{applyReportTheme();}});
  themeObserver.observe(document.documentElement,{{attributes:true,attributeFilter:['data-theme','class']}});
  if(document.body)themeObserver.observe(document.body,{{attributes:true,attributeFilter:['class']}});
  applyReportTheme();
}}

function isDarkTheme(){{
  const rootTheme=document.documentElement.dataset.theme||'';
  const bodyClass=document.body?document.body.className:'';
  const rootClass=document.documentElement.className||'';
  return rootTheme==='dark'||bodyClass.indexOf('dark-theme')>=0||bodyClass.indexOf('dark')>=0||String(rootClass).indexOf('dark-theme')>=0;
}}

function buildNav(){{
  $('nav').innerHTML=TABS.map(function(t,i){{return'<button class="nav-btn'+(i===0?' active':'')+'" data-tab="'+t.id+'">'+t.label+'</button>';}}).join('');
  $('nav').onclick=function(e){{const b=e.target.closest('button');if(!b)return;const tid=b.dataset.tab;document.querySelectorAll('.nav-btn').forEach(function(x){{x.classList.remove('active');}});b.classList.add('active');document.querySelectorAll('.tab').forEach(function(x){{x.classList.remove('active');}});$('tab-'+tid).classList.add('active');if(tid==='overview')renderOverviewCharts();if(tid==='pcm')renderPcmView();if(tid==='quality')renderQuality();if(tid==='schedule')renderSchedule();if(tid==='reports')renderReports();if(tid==='run')checkJuliaStatus();}};
}}

// ============ OVERVIEW ============
function renderOverview(){{
  const runs=Object.keys(DATA.summaries||{{}}).sort().reverse();
  var total=0,ok=0,conv=0,err=0,bestGap=Infinity,fastest=null;
  const allAlgos=new Set();
  for(const[k,v]of Object.entries(DATA.summaries||{{}})){{
    if(!v||v.length<2)continue;
    for(var i=1;i<v.length;i++){{
      total++;
      allAlgos.add(v[i][0]);
      const st=(v[i][2]||'').toLowerCase();
      if(st==='optimal')ok++;else if(st==='converged')conv++;else if(st.includes('inconsistency')||st.includes('error')||st.includes('fail'))err++;
      const g=parseFloat(v[i][6]); if(!Number.isNaN(g)&&g>=0&&g<bestGap)bestGap=g;
      const t=parseFloat(v[i][7]); if(!Number.isNaN(t)&&t>0&&(!fastest||t<fastest.t))fastest={{t:t,algo:v[i][0],scen:v[i][1]}};
    }}
  }}
  let pcmMaxSpeedup=0,pcmMaxRed=0;
  Object.values(DATA.pcm_benchmarks||{{}}).forEach(function(ds){{
    (ds.rows||[]).forEach(function(r){{
      if(r.speedup&&r.speedup>pcmMaxSpeedup)pcmMaxSpeedup=r.speedup;
      if(r.state_reduction_pct&&r.state_reduction_pct>pcmMaxRed)pcmMaxRed=r.state_reduction_pct;
    }});
  }});
  const successRate=total?((ok+conv)/total*100).toFixed(1)+'%':'—';
  $('overview-metrics').innerHTML=[
    '<div class="metric" style="--metric-accent:#3b82f6"><div class="label">UC Benchmark Runs</div><div class="value">'+runs.length+'</div><div class="sub">'+total+' total solver records</div></div>',
    '<div class="metric" style="--metric-accent:#10b981"><div class="label">UC Success Rate</div><div class="value" style="color:#16a34a">'+successRate+'</div><div class="sub">'+ok+' optimal &middot; '+conv+' converged &middot; '+err+' failed</div></div>',
    '<div class="metric" style="--metric-accent:#06b6d4"><div class="label">Fastest UC Solve</div><div class="value">'+(fastest?fmt(fastest.t,2)+'s':'—')+'</div><div class="sub">'+(fastest?(ALABEL[fastest.algo]||fastest.algo)+' ('+fastest.scen+' scen)':'No local UC runs')+'</div></div>',
    '<div class="metric" style="--metric-accent:#8b5cf6"><div class="label">Best Optimality Gap</div><div class="value">'+(bestGap<Infinity?(bestGap*100).toFixed(3)+'%':'—')+'</div><div class="sub">Minimum relative MIP/decomposition gap</div></div>',
    '<div class="metric" style="--metric-accent:#f59e0b"><div class="label">PCM Peak Speedup</div><div class="value">'+(pcmMaxSpeedup?pcmMaxSpeedup.toFixed(2)+'&times;':'—')+'</div><div class="sub">1080-unit clustered adaptive vs standard</div></div>',
    '<div class="metric" style="--metric-accent:#ec4899"><div class="label">Max State Reduction</div><div class="value">'+(pcmMaxRed?pcmMaxRed.toFixed(1)+'%':'—')+'</div><div class="sub">Equivalent units compression (1080 &rarr; 31)</div></div>'
  ].join('');

  $('ov-run').innerHTML=runs.length?runs.map(function(r){{return'<option value="'+escapeHTML(r)+'">'+escapeHTML(r)+'</option>';}}).join(''):'<option value="">No local runs</option>';
  $('ov-algo').innerHTML='<option value="">All Algorithms</option>'+Array.from(allAlgos).sort().map(function(a){{return'<option value="'+escapeHTML(a)+'">'+escapeHTML(ALABEL[a]||a)+'</option>';}}).join('');
  $('ov-run').onchange=function(){{renderOverviewCharts();renderOverviewTable();}};
  $('ov-algo').onchange=function(){{renderOverviewCharts();renderOverviewTable();}};
  renderOverviewCharts();
  renderOverviewTable();
}}

function renderOverviewCharts(){{
  const run=$('ov-run')?$('ov-run').value:'';
  const algoFilter=$('ov-algo')?$('ov-algo').value:'';
  var rows=(DATA.summaries[run]||[]).slice(1);
  if(algoFilter)rows=rows.filter(function(r){{return r[0]===algoFilter;}});
  const ids=['ov-chart-time','ov-chart-gap','ov-chart-obj','ov-chart-ram'];
  if(!rows.length){{
    ids.forEach(function(id){{const el=$(id);if(el)el.innerHTML='<div class="empty-state" style="height:310px;display:flex;align-items:center;justify-content:center;">No UC comparison run selected. Run UC Benchmark or check PCM Benchmark tab.</div>';}});
    return;
  }}
  const xLabels=rows.map(function(r){{return(ALABEL[r[0]]||r[0])+' ('+r[1]+'s)';}});
  const colors=rows.map(function(r){{return ACOL[r[0]]||'#3b82f6';}});

  showCompact('ov-chart-time',[{{
    type:'bar',x:xLabels,y:rows.map(function(r){{return +r[7];}}),
    text:rows.map(function(r){{return fmt(r[7],2)+'s';}}),textposition:'auto',
    marker:{{color:colors}}
  }}],{{yaxis:{{title:'Time (s)'}},showlegend:false}});

  const gaps=rows.map(function(r){{return Math.max(parseFloat(r[6])||0,1e-8);}});
  showCompact('ov-chart-gap',[{{
    type:'bar',x:xLabels,y:gaps,
    text:rows.map(function(r){{return ((parseFloat(r[6])||0)*100).toFixed(3)+'%';}}),textposition:'auto',
    marker:{{color:gaps.map(function(g){{return g<0.01?'#10b981':g<0.1?'#f59e0b':'#ef4444';}})}}
  }}],{{yaxis:{{title:'Gap',type:'log'}},showlegend:false}});

  showCompact('ov-chart-obj',[
    {{type:'bar',name:'Lower Bound',x:xLabels,y:rows.map(function(r){{return +r[4];}}),marker:{{color:'#3b82f6'}}}},
    {{type:'bar',name:'Upper Bound',x:xLabels,y:rows.map(function(r){{return +r[5];}}),marker:{{color:'#10b981'}}}}
  ],{{barmode:'group',yaxis:{{title:'Objective Cost'}}}});

  showCompact('ov-chart-ram',[{{
    type:'bar',x:xLabels,y:rows.map(function(r){{return +r[8];}}),
    text:rows.map(function(r){{return fmt(r[8],1)+' MB';}}),textposition:'auto',
    marker:{{color:colors}}
  }}],{{yaxis:{{title:'Peak RAM (MB)'}},showlegend:false}});
}}

function renderOverviewTable(){{
  const algoFilter=$('ov-algo')?$('ov-algo').value:'';
  var html='<thead><tr><th>Run</th><th>Algorithm</th><th>Scen</th><th>Status</th><th>Iter</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Time (s)</th><th>Speedup</th><th>RAM (MB)</th></tr></thead><tbody>';
  var count=0;
  for(const[run,rows]of Object.entries(DATA.summaries||{{}}).sort().reverse()){{
    const baseByScen={{}};
    for(var j=1;j<rows.length;j++){{if(rows[j][0]==='benchmark_uc')baseByScen[rows[j][1]]=parseFloat(rows[j][7]);}}
    for(var i=1;i<rows.length;i++){{
      const r=rows[i];
      if(algoFilter&&r[0]!==algoFilter)continue;
      count++;
      const gap=parseFloat(r[6]);
      const gc=gap<0.01?'gap-good':gap>0.5?'gap-bad':'';
      var b='',st=(r[2]||'').toLowerCase();
      if(st==='optimal')b='badge-ok';else if(st==='converged')b='badge-info';else if(st.includes('inconsistency')||st.includes('error')||st.includes('fail'))b='badge-err';else b='badge-warn';
      const t=parseFloat(r[7]), bt=baseByScen[r[1]];
      let spHtml='<span class="speedup-chip speedup-base">—</span>';
      if(bt&&t>0){{const sp=bt/t;const cls=sp>=1.15?'speedup-fast':sp<0.85?'speedup-slow':'speedup-base';spHtml='<span class="speedup-chip '+cls+'">'+sp.toFixed(2)+'&times;</span>';}}
      html+='<tr><td>'+escapeHTML(run)+'</td><td>'+methodPill(r[0])+'</td><td class="num">'+r[1]+'</td><td><span class="badge '+b+'">'+escapeHTML(r[2])+'</span></td><td class="num">'+r[3]+'</td><td class="num">'+fmt(r[4],1)+'</td><td class="num">'+fmt(r[5],1)+'</td><td class="num '+gc+'">'+(Number.isNaN(gap)?'—':gap.toFixed(5))+'</td><td class="num">'+fmt(r[7],2)+'</td><td>'+spHtml+'</td><td class="num">'+fmt(r[8],1)+'</td></tr>';
    }}
  }}
  if(!count)html+='<tr><td colspan="11" class="empty-state">No UC comparison summary records found.</td></tr>';
  html+='</tbody>';
  $('summary-table').innerHTML=html;
}}

// ============ PCM BENCHMARK ============
function renderPcm(){{
  const keys=Object.keys(DATA.pcm_benchmarks||{{}});
  $('pcm-dataset').innerHTML=keys.map(function(k){{return'<option value="'+escapeHTML(k)+'">'+escapeHTML(DATA.pcm_benchmarks[k].label||k)+'</option>';}}).join('');
  $('pcm-dataset').onchange=renderPcmView;
  $('pcm-profile').onchange=renderPcmView;
  const views=[
    {{id:'perf',label:'Solve Time & Speedup'}},
    {{id:'cost',label:'Total Cost & Savings'}},
    {{id:'reduction',label:'Dimension Reduction & Feasibility'}},
    {{id:'pareto',label:'Time vs Cost Pareto'}}
  ];
  $('pcm-view-tabs').innerHTML=views.map(function(v){{return'<button class="view-tab'+(v.id===pcmActiveView?' active':'')+'" data-pview="'+v.id+'">'+v.label+'</button>';}}).join('');
  $('pcm-view-tabs').onclick=function(e){{
    const b=e.target.closest('.view-tab');if(!b)return;
    pcmActiveView=b.dataset.pview;
    document.querySelectorAll('#pcm-view-tabs .view-tab').forEach(function(x){{x.classList.remove('active');}});
    b.classList.add('active');
    renderPcmView();
  }};
  renderPcmView();
}}

function renderPcmView(){{
  const key=$('pcm-dataset')?$('pcm-dataset').value:'';
  const ds=(DATA.pcm_benchmarks||{{}})[key];
  if(!ds)return;
  const profFilter=$('pcm-profile')?$('pcm-profile').value:'';
  const rows=(ds.rows||[]).filter(function(r){{return !profFilter||r.profile===profFilter;}});
  if($('pcm-source-tag'))$('pcm-source-tag').textContent=(ds.source||'Archive')+' · '+(ds.scale||'')+' · '+(ds.horizon||'');

  const okRows=rows.filter(function(r){{return r.status==='OK'&&r.solve_time_s!=null;}});
  const fastest=okRows.length?okRows.reduce(function(a,b){{return a.solve_time_s<b.solve_time_s?a:b;}}):null;
  const maxSp=rows.reduce(function(m,r){{return r.speedup&&r.speedup>m?r.speedup:m;}},0);
  const maxRed=rows.reduce(function(m,r){{return r.state_reduction_pct&&r.state_reduction_pct>m?r.state_reduction_pct:m;}},0);
  const extRows=rows.filter(function(r){{return r.profile==='extreme_ramp';}});
  const extOk=extRows.filter(function(r){{return r.status==='OK';}}).length;
  const bestSave=rows.reduce(function(best,r){{return (r.cost_delta_pct!=null&&r.status==='OK'&&(best===null||r.cost_delta_pct<best.cost_delta_pct))?r:best;}},null);

  $('pcm-metrics').innerHTML=[
    '<div class="metric" style="--metric-accent:#8b5cf6"><div class="label">Peak Speedup</div><div class="value">'+(maxSp?maxSp.toFixed(2)+'&times;':'—')+'</div><div class="sub">vs Standard PCM baseline</div></div>',
    '<div class="metric" style="--metric-accent:#06b6d4"><div class="label">Fastest Feasible Solve</div><div class="value">'+(fastest?fmt(fastest.solve_time_s,2)+'s':'—')+'</div><div class="sub">'+(fastest?(ALABEL[fastest.method]||fastest.method)+' ('+fastest.profile+')':'—')+'</div></div>',
    '<div class="metric" style="--metric-accent:#f59e0b"><div class="label">State Space Reduction</div><div class="value">'+(maxRed?maxRed.toFixed(1)+'%':'0.0%')+'</div><div class="sub">Clustered equivalent units compression</div></div>',
    '<div class="metric" style="--metric-accent:#10b981"><div class="label">Best Cost Delta</div><div class="value">'+(bestSave?(bestSave.cost_delta_pct>0?'+':'')+bestSave.cost_delta_pct.toFixed(2)+'%':'—')+'</div><div class="sub">'+(bestSave?(ALABEL[bestSave.method]||bestSave.method)+' ('+bestSave.profile+')':'—')+'</div></div>',
    '<div class="metric" style="--metric-accent:#ef4444"><div class="label">Extreme-Ramp Feasible</div><div class="value">'+(extRows.length?extOk+'/'+extRows.length:'—')+'</div><div class="sub">Adaptive overlap prevents boundary infeasibility</div></div>'
  ].join('');

  const profiles=Array.from(new Set(rows.map(function(r){{return r.profile;}})));
  const methods=['standard','clustered_pcm','adaptive_overlap','clustered_adaptive_overlap'].filter(function(m){{return rows.some(function(r){{return r.method===m;}});}});

  if(pcmActiveView==='perf'){{
    $('pcm-chart1-title').textContent='Simulation Solve Time (s) — Lower is Better';
    $('pcm-chart2-title').textContent='Speedup Ratio vs Standard PCM (x) — Higher is Better';
    const s1=methods.map(function(m){{
      return {{
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.status==='OK';}});return f?f.solve_time_s:null;}}),
        text:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m;}});return !f?'':f.status!=='OK'?'FAIL':fmt(f.solve_time_s,1)+'s';}}),
        textposition:'auto',marker:{{color:ACOL[m]||'#64748b'}}
      }};
    }});
    showCompact('pcm-chart1',s1,{{barmode:'group',yaxis:{{title:'Solve Time (s)'}}}},400);

    const s2=methods.map(function(m){{
      return {{
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.speedup!=null;}});return f?f.speedup:null;}}),
        text:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.speedup!=null;}});return f?f.speedup.toFixed(2)+'x':'';}}),
        textposition:'auto',marker:{{color:ACOL[m]||'#64748b'}}
      }};
    }});
    showCompact('pcm-chart2',s2,{{barmode:'group',yaxis:{{title:'Speedup (x)'}},shapes:[{{type:'line',xref:'paper',x0:0,x1:1,y0:1,y1:1,line:{{color:'#94a3b8',dash:'dot',width:1.5}}}}]}},400);
  }} else if(pcmActiveView==='cost'){{
    $('pcm-chart1-title').textContent='Total Operating Cost (Million)';
    $('pcm-chart2-title').textContent='Cost Delta vs Standard PCM (%) — Negative = Savings';
    const s1=methods.map(function(m){{
      return {{
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.total_cost!=null;}});return f?f.total_cost/1e6:null;}}),
        text:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.total_cost!=null;}});return f?(f.total_cost/1e6).toFixed(2)+'M':'';}}),
        textposition:'auto',marker:{{color:ACOL[m]||'#64748b'}}
      }};
    }});
    showCompact('pcm-chart1',s1,{{barmode:'group',yaxis:{{title:'Total Cost (M)'}}}},400);

    const s2=methods.map(function(m){{
      return {{
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.cost_delta_pct!=null&&r.status==='OK';}});return f?f.cost_delta_pct:null;}}),
        text:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m&&r.cost_delta_pct!=null&&r.status==='OK';}});return f?(f.cost_delta_pct>0?'+':'')+f.cost_delta_pct.toFixed(2)+'%':'';}}),
        textposition:'auto',marker:{{color:ACOL[m]||'#64748b'}}
      }};
    }});
    showCompact('pcm-chart2',s2,{{barmode:'group',yaxis:{{title:'Cost Delta (%)'}},shapes:[{{type:'line',xref:'paper',x0:0,x1:1,y0:0,y1:0,line:{{color:'#94a3b8',dash:'dot',width:1.5}}}}]}},400);
  }} else if(pcmActiveView==='reduction'){{
    $('pcm-chart1-title').textContent='Equivalent Unit Count (Physical vs Clustered)';
    $('pcm-chart2-title').textContent='Feasibility Success Rate Across Load Profiles (%)';
    const sampleByMethod=methods.map(function(m){{return rows.find(function(r){{return r.method===m;}})||{{}};}});
    showCompact('pcm-chart1',[
      {{type:'bar',name:'Physical Units',x:methods.map(function(m){{return ALABEL[m]||m;}}),y:sampleByMethod.map(function(r){{return r.physical_units||0;}}),marker:{{color:'#94a3b8'}}}},
      {{type:'bar',name:'Equivalent Units',x:methods.map(function(m){{return ALABEL[m]||m;}}),y:sampleByMethod.map(function(r){{return r.equiv_units||0;}}),text:sampleByMethod.map(function(r){{return r.state_reduction_pct?'-'+r.state_reduction_pct.toFixed(1)+'%':'0%';}}),textposition:'auto',marker:{{color:methods.map(function(m){{return ACOL[m]||'#3b82f6';}})}}}}
    ],{{barmode:'group',yaxis:{{title:'Unit Count'}}}},400);

    const s2=methods.map(function(m){{
      return {{
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m;}});return f?f.success_rate:0;}}),
        text:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m;}});return f?f.success_rate.toFixed(0)+'%':'';}}),
        textposition:'auto',marker:{{color:ACOL[m]||'#64748b'}}
      }};
    }});
    showCompact('pcm-chart2',s2,{{barmode:'group',yaxis:{{title:'Success Rate (%)',range:[0,115]}}}},400);
  }} else {{
    $('pcm-chart1-title').textContent='Solve Time vs Total Cost Pareto (Lower-Left is Better)';
    $('pcm-chart2-title').textContent='Mean Overlap Window & Peak RSS Memory';
    const symbols={{baseline:'circle',smooth:'square',extreme_ramp:'diamond'}};
    const s1=methods.map(function(m){{
      const mr=rows.filter(function(r){{return r.method===m&&r.status==='OK'&&r.solve_time_s!=null&&r.total_cost!=null;}});
      return {{
        type:'scatter',mode:'markers+text',name:ALABEL[m]||m,
        x:mr.map(function(r){{return r.solve_time_s;}}),
        y:mr.map(function(r){{return r.total_cost/1e6;}}),
        text:mr.map(function(r){{return r.profile;}}),textposition:'top center',
        marker:{{size:13,color:ACOL[m]||'#3b82f6',symbol:mr.map(function(r){{return symbols[r.profile]||'circle';}}),line:{{width:1.5,color:'#fff'}}}}
      }};
    }});
    showCompact('pcm-chart1',s1,{{xaxis:{{title:'Solve Time (s)'}},yaxis:{{title:'Total Cost (M)'}}}},400);

    const hasRss=rows.some(function(r){{return r.peak_rss_mb!=null;}});
    if(hasRss){{
      const s2=methods.map(function(m){{
        return {{
          type:'bar',name:ALABEL[m]||m,x:profiles,
          y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m;}});return f?f.peak_rss_mb:null;}}),
          marker:{{color:ACOL[m]||'#64748b'}}
        }};
      }});
      showCompact('pcm-chart2',s2,{{barmode:'group',yaxis:{{title:'Peak RSS (MB)'}}}},400);
    }} else {{
      const s2=methods.map(function(m){{
        return {{
          type:'bar',name:ALABEL[m]||m,x:profiles,
          y:profiles.map(function(p){{const f=rows.find(function(r){{return r.profile===p&&r.method===m;}});return f?(f.overlap_h||0):0;}}),
          marker:{{color:ACOL[m]||'#64748b'}}
        }};
      }});
      showCompact('pcm-chart2',s2,{{barmode:'group',yaxis:{{title:'Mean Overlap Window (h)'}}}},400);
    }}
  }}

  var th='<thead><tr><th>Profile</th><th>Method</th><th>Status</th><th>Solve Time (s)</th><th>Speedup</th><th>Total Cost (M)</th><th>Cost Delta</th><th>Units (Phys &rarr; Equiv)</th><th>State Reduction</th><th>Overlap (h)</th><th>Peak RSS (MB)</th></tr></thead><tbody>';
  rows.forEach(function(r){{
    const ok=r.status==='OK';
    const stBadge=ok?'<span class="badge badge-ok">OK</span>':'<span class="badge badge-err">INFEASIBLE</span>';
    let spHtml='<span class="speedup-chip speedup-base">—</span>';
    if(r.speedup!=null){{const cls=r.speedup>=1.2?'speedup-fast':r.speedup<0.85?'speedup-slow':'speedup-base';spHtml='<span class="speedup-chip '+cls+'">'+r.speedup.toFixed(2)+'&times;</span>';}}
    let cdHtml='—';
    if(r.cost_delta_pct!=null&&ok){{const cls=r.cost_delta_pct<=-0.1?'gap-good':r.cost_delta_pct>2?'gap-bad':'';cdHtml='<span class="'+cls+'">'+(r.cost_delta_pct>0?'+':'')+r.cost_delta_pct.toFixed(2)+'%</span>';}}
    const red=r.state_reduction_pct||0;
    const redBar='<div class="bar-wrap"><div class="bar-track"><div class="bar-fill" style="width:'+Math.min(100,Math.max(0,red))+'%;background:'+(ACOL[r.method]||'#3b82f6')+'"></div></div><span class="num">'+red.toFixed(1)+'%</span></div>';
    th+='<tr><td><strong>'+escapeHTML(r.profile)+'</strong></td><td>'+methodPill(r.method)+'</td><td>'+stBadge+'</td><td class="num">'+(ok&&r.solve_time_s!=null?fmt(r.solve_time_s,2):'—')+'</td><td>'+spHtml+'</td><td class="num">'+(ok&&r.total_cost!=null?(r.total_cost/1e6).toFixed(3)+'M':'—')+'</td><td class="num">'+cdHtml+'</td><td class="num">'+(r.physical_units!=null?Math.round(r.physical_units)+' &rarr; '+Math.round(r.equiv_units||r.physical_units):'—')+'</td><td>'+redBar+'</td><td class="num">'+(r.overlap_h!=null?fmt(r.overlap_h,1):'—')+'</td><td class="num">'+(r.peak_rss_mb!=null?fmt(r.peak_rss_mb,1):'—')+'</td></tr>';
  }});
  th+='</tbody>';
  $('pcm-table').innerHTML=th;
}}

// ============ QUALITY ============
function renderQuality(){{
  const runs=Object.keys(DATA.qualities).sort();
  $('ql-run').innerHTML=runs.map(function(r){{return'<option>'+r+'</option>';}}).join('');
  $('ql-run').onchange=function(){{updateQualFilters();switchQl();renderQualTables();}};
  $('ql-algo').onchange=function(){{switchQl();renderQualTables();}};
  $('ql-scen').onchange=function(){{switchQl();renderQualTables();}};
  updateQualFilters();renderQualTables();buildQlViewTabs();
}}

function buildQlViewTabs(){{
  const views=[{{id:'curtailment',label:'Curtailment'}},{{id:'gap',label:'Gap'}},{{id:'runtime',label:'Runtime'}},{{id:'ram',label:'RAM'}},{{id:'convergence',label:'Convergence'}},{{id:'bounds',label:'Bounds'}}];
  $('ql-view-tabs').innerHTML=views.map(function(v){{return'<button class="view-tab'+(v.id===qlActive?' active':'')+'" data-view="'+v.id+'">'+v.label+'</button>';}}).join('');
  $('ql-view-tabs').onclick=function(e){{const b=e.target.closest('.view-tab');if(!b)return;qlActive=b.dataset.view;document.querySelectorAll('.view-tab').forEach(function(x){{x.classList.remove('active');}});b.classList.add('active');switchQl();}};
  switchQl();
}}

function getQlSumRows(){{var r=$('ql-run').value,a=$('ql-algo').value,s=$('ql-scen').value;var rows=(DATA.summaries[r]||[]).slice(1);if(a)rows=rows.filter(function(x){{return x[0]===a;}});if(s)rows=rows.filter(function(x){{return x[1]===s;}});return rows;}}
function getQlItRows(){{var r=$('ql-run').value,a=$('ql-algo').value,s=$('ql-scen').value;var rows=(DATA.iterations[r]||[]).slice(1);if(a)rows=rows.filter(function(x){{return x[0]===a;}});if(s)rows=rows.filter(function(x){{return x[1]===s;}});return rows;}}

function switchQl(){{
  const run=$('ql-run')?.value,algo=$('ql-algo')?.value,scen=$('ql-scen')?.value;
  if(qlActive==='curtailment'){{
    const rows=(DATA.qualities[run]||[]).slice(1).filter(function(r){{return(!algo||r[0]===algo)&&(!scen||r[1]===scen);}});
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}}
    const layout={{height:480,yaxis:{{title:'Curtailment (MW)'}},barmode:'group'}};
    Plotly.newPlot(pl('ql-plot'),[
      {{type:'bar',x:rows.map(function(r){{return r[0]+'-'+r[1]+'s';}}),y:rows.map(function(r){{return +r[4];}}),name:'Wind Curtailment',marker:{{color:'#91cc75'}}}},
      {{type:'bar',x:rows.map(function(r){{return r[0]+'-'+r[1]+'s';}}),y:rows.map(function(r){{return +r[3];}}),name:'Load Curtailment',marker:{{color:'#ee6666'}}}}
    ],Object.assign({{margin:PLMARGIN,hovermode:'x unified',legend:{{orientation:'h',y:-0.2}},xaxis:{{tickfont:{{size:10}}}},yaxis:{{tickfont:{{size:10}},title:{{font:{{size:11}}}}}}}},layout));
  }}else if(qlActive==='gap'){{
    const rows=getQlSumRows();
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}}
    const g=rows.map(function(r){{return +r[6];}});
    show('ql-plot',[{{type:'bar',x:rows.map(function(r){{return r[0]+'-'+r[1]+'s';}}),y:g.map(function(x){{return Math.max(x,1e-8);}}),marker:{{color:g.map(function(x){{return x<0.01?'#91cc75':x<0.2?'#fac858':'#ee6666';}})}}}}],{{yaxis:{{title:'Optimality Gap',type:'log'}}}});
  }}else if(qlActive==='runtime'){{
    const rows=getQlSumRows();
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}}
    show('ql-plot',[{{type:'bar',x:rows.map(function(r){{return r[0]+'-'+r[1]+'s';}}),y:rows.map(function(r){{return +r[7];}}),marker:{{color:rows.map(function(r){{return ACOL[r[0]]||'#5470c6';}})}}}}],{{yaxis:{{title:'Runtime (s)'}}}});
  }}else if(qlActive==='ram'){{
    const rows=getQlSumRows();
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}}
    show('ql-plot',[{{type:'bar',x:rows.map(function(r){{return r[0]+'-'+r[1]+'s';}}),y:rows.map(function(r){{return +r[8];}}),marker:{{color:rows.map(function(r){{return ACOL[r[0]]||'#5470c6';}})}}}}],{{yaxis:{{title:'RAM (MB)'}}}});
  }}else if(qlActive==='convergence'){{
    const rows=getQlItRows();
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No iteration data</div>';return;}}
    const g={{}};rows.forEach(function(r){{const k=r[0]+'-'+r[1]+'s';if(!g[k])g[k]=[];g[k].push({{x:+r[2],y:Math.max(+r[6],1e-8)}});}});
    const mi=Math.max.apply(null,rows.map(function(r){{return +r[2];}}));
    const series=Object.entries(g).map(function(e,i){{const m={{}};e[1].forEach(function(p){{m[p.x]=p.y;}});const d=[];for(var j=1;j<=mi;j++)d.push(m[j]||null);return{{x:Array.from({{length:mi}},function(_,x){{return x+1;}}),y:d,name:e[0],type:'scatter',mode:'lines+markers',line:{{color:C10[i%C10.length]}},marker:{{size:3}}}};}});
    show('ql-plot',series,{{xaxis:{{title:'Iteration'}},yaxis:{{title:'Gap',type:'log'}}}});
  }}else if(qlActive==='bounds'){{
    const rows=getQlItRows();
    if(!rows.length){{$('ql-plot').innerHTML='<div class="empty-state">No iteration data</div>';return;}}
    const mi=Math.max.apply(null,rows.map(function(r){{return +r[2];}}));
    const g={{}};rows.forEach(function(r){{const k=r[0]+'-'+r[1]+'s';if(!g[k])g[k]={{lb:new Array(mi).fill(null),ub:new Array(mi).fill(null)}};}});
    rows.forEach(function(r){{const k=r[0]+'-'+r[1]+'s';g[k].lb[+r[2]-1]=+r[4];g[k].ub[+r[2]-1]=+r[5];}});
    const x=Array.from({{length:mi}},function(_,i){{return i+1;}});
    const series=[];Object.entries(g).forEach(function(e,i){{series.push({{x:x,y:e[1].lb,name:e[0]+' LB',type:'scatter',mode:'lines',line:{{color:C10[i%C10.length],dash:'dash'}}}});series.push({{x:x,y:e[1].ub,name:e[0]+' UB',type:'scatter',mode:'lines',line:{{color:C10[i%C10.length]}}}});}});
    show('ql-plot',series,{{xaxis:{{title:'Iteration'}},yaxis:{{title:'Cost'}}}});
  }}
}}

function updateQualFilters(){{
  const run=$('ql-run').value,rows=DATA.qualities[run];
  if(!rows||rows.length<2)return;
  const algos=Array.from(new Set(rows.slice(1).map(function(r){{return r[0];}})));
  $('ql-algo').innerHTML='<option value="">All</option>'+algos.map(function(a){{return'<option>'+a+'</option>';}}).join('');
  const scens=Array.from(new Set(rows.slice(1).map(function(r){{return r[1];}})));
  $('ql-scen').innerHTML='<option value="">All</option>'+scens.map(function(s){{return'<option>'+s+'</option>';}}).join('');
}}

function renderQualTables(){{
  const run=$('ql-run').value,algo=$('ql-algo').value,scen=$('ql-scen').value;
  var qRows=(DATA.qualities[run]||[]).slice(1).filter(function(r){{return(!algo||r[0]===algo)&&(!scen||r[1]===scen);}});
  var qh='<thead><tr><th>Algorithm</th><th>Scenarios</th><th>Max Balance Error</th><th>Load Curtail</th><th>Wind Curtail</th><th>Peak Load</th></tr></thead><tbody>';
  qRows.forEach(function(r){{qh+='<tr><td>'+r[0]+'</td><td>'+r[1]+'</td><td>'+Number(r[2]).toExponential(2)+'</td><td>'+fmt(r[3],3)+'</td><td>'+fmt(r[4],2)+'</td><td>'+fmt(r[5],4)+'</td></tr>';}});qh+='</tbody>';$('ql-quality-table').innerHTML=qh;
  var iRows=getQlItRows();
  if(!iRows.length){{$('ql-iter-table').innerHTML='<tbody><tr><td class="empty-state" colspan="9">No iteration data</td></tr></tbody>';}}
  else{{var ih='<thead><tr><th>Algo</th><th>Scen</th><th>Iter</th><th>Active</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Added</th><th>RAM</th></tr></thead><tbody>';
  iRows.forEach(function(r){{ih+='<tr><td>'+r[0]+'</td><td>'+r[1]+'</td><td>'+r[2]+'</td><td>'+r[3]+'</td><td>'+fmt(r[4],1)+'</td><td>'+fmt(r[5],1)+'</td><td>'+parseFloat(r[6]).toFixed(5)+'</td><td>'+r[7]+'</td><td>'+r[8]+'</td></tr>';}});ih+='</tbody>';$('ql-iter-table').innerHTML=ih;}}
}}

// ============ SCHEDULE ============
function renderSchedule(){{
  const runs=Object.keys(DATA.scheduling).sort();
  $('sc-run').innerHTML=runs.map(function(r){{return'<option>'+r+'</option>';}}).join('');
  $('sc-run').onchange=updateScAlgo;
  $('sc-algo').onchange=function(){{buildScTabs();switchSc();}};
  buildScTabs();if(runs.length)updateScAlgo();
}}

function updateScAlgo(){{const run=$('sc-run').value;const algos=Object.keys(DATA.scheduling[run]||{{}}).sort();$('sc-algo').innerHTML=algos.map(function(a){{return'<option>'+a+'</option>';}}).join('');buildScTabs();switchSc();}}

function buildScTabs(){{
  const run=$('sc-run').value,algo=$('sc-algo').value,sched=(DATA.scheduling[run]||{{}})[algo]||{{}};
  const tabs=[];
  if(sched['generator_dispatch'])tabs.push({{id:'dispatch',label:'Generator Dispatch'}});
  if(sched['unit_commitment_status'])tabs.push({{id:'uc_status',label:'UC Status'}});
  if(sched['schedule_cost_summary'])tabs.push({{id:'cost',label:'Cost Breakdown'}});
  if(sched['curtailment_schedule'])tabs.push({{id:'curtailment',label:'Curtailment'}});
  if(sched['power_balance_summary'])tabs.push({{id:'power_bal',label:'Power Balance'}});
  if(sched['unit_startup_shutdown_decisions'])tabs.push({{id:'startup',label:'Startup/Shutdown'}});
  if(sched['schedule_commitment_result'])tabs.push({{id:'commit_txt',label:'Commitment Report'}});
  if(sched['reserve_schedule'])tabs.push({{id:'reserve',label:'Reserves'}});
  if(!tabs.length){{$('sc-tabs').innerHTML='';return;}}
  if(!tabs.find(function(t){{return t.id===scActive;}}))scActive=tabs[0].id;
  $('sc-tabs').innerHTML=tabs.map(function(t){{return'<button class="sched-tab'+(t.id===scActive?' active':'')+'" data-sc="'+t.id+'">'+t.label+'</button>';}}).join('');
  $('sc-tabs').onclick=function(e){{const b=e.target.closest('.sched-tab');if(!b)return;scActive=b.dataset.sc;document.querySelectorAll('.sched-tab').forEach(function(x){{x.classList.remove('active');}});b.classList.add('active');switchSc();}};
  switchSc();
}}

function switchSc(){{
  const run=$('sc-run').value,algo=$('sc-algo').value,sched=(DATA.scheduling[run]||{{}})[algo]||{{}};
  $('sc-table').innerHTML='';Plotly.purge('sc-plot');

  if(scActive==='dispatch'){{
    const rows=sched['generator_dispatch'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No dispatch data</div>';return;}}
    const hdr=rows[0],nU=hdr.length-2,byScen={{}};
    rows.slice(1).forEach(function(r){{const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);}});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){{return r[1];}}))).sort(function(a,b){{return a-b;}});
    const series=[];scens.forEach(function(sc,i){{for(var u=0;u<nU;u++){{const dash=i===1&&scens.length>1?'dash':'solid';series.push({{x:tl,y:byScen[sc].map(function(r){{return +r[2+u];}}),name:'S'+sc+' Unit '+(u+1),type:'scatter',mode:'lines',line:{{color:C10[u%C10.length],dash:dash}}}});}}}});
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Dispatch (MW)'}}}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){{byScen[sc].forEach(function(r){{th+='<tr><td>'+sc+'</td>'+r.slice(1).map(function(v){{return'<td>'+fmt(v,4)+'</td>';}}).join('')+'</tr>';}});}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='uc_status'){{
    const rows=sched['unit_commitment_status'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No UC data</div>';return;}}
    const hdr=rows[0],dr=rows.slice(1),nU=hdr.length-1,tl=dr.map(function(r){{return r[0];}});
    const series=[];for(var u=0;u<nU;u++){{series.push({{x:tl,y:dr.map(function(r){{return Math.round(+r[1+u]);}}),name:'Unit '+(u+1),type:'bar',marker:{{color:C10[u%C10.length]}}}});}}
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Commitment',range:[0,nU+0.5],dtick:1}},barmode:'stack'}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){{th+='<tr>'+r.map(function(v){{return'<td>'+fmt(v,3)+'</td>';}}).join('')+'</tr>';}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='cost'){{
    const rows=sched['schedule_cost_summary'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No cost data</div>';return;}}
    const others=rows.slice(1).filter(function(r){{return +r[1]!==0&&r[0]!=='total_cost';}});
    const total=rows.slice(1).find(function(r){{return r[0]==='total_cost';}});
    $('sc-plot').innerHTML='<div class="cost-grid"><div id="sc-pie" class="plot-div"></div><div id="sc-bar" class="plot-div"></div></div>';
    const names=others.map(function(r){{return r[0].replace(/_/g,' ').replace(/cost/g,'');}});
    Plotly.newPlot('sc-pie',[{{type:'pie',labels:names,values:others.map(function(r){{return +r[1];}}),marker:{{colors:C10}},textinfo:'label+percent',textfont:{{size:10}}}}],{{height:480,margin:{{l:10,r:10,t:10,b:10}}}},PLCFG);
    Plotly.newPlot('sc-bar',[{{type:'bar',y:others.map(function(r){{return r[0];}}),x:others.map(function(r){{return +r[1];}}),orientation:'h',marker:{{color:others.map(function(_,i){{return C10[i%C10.length];}})}}}}],{{height:480,margin:{{l:140,r:15,t:10,b:30}},xaxis:{{title:'Cost'}}}},PLCFG);
    var th='<thead><tr><th>Component</th><th>Value</th></tr></thead><tbody>';
    if(total)th+='<tr><td><strong>'+total[0]+'</strong></td><td><strong>'+fmt(total[1],2)+'</strong></td></tr>';
    others.forEach(function(r){{th+='<tr><td>'+r[0]+'</td><td>'+fmt(r[1],2)+'</td></tr>';}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='curtailment'){{
    const rows=sched['curtailment_schedule'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No curtailment data</div>';return;}}
    const hdr=rows[0],byScen={{}};rows.slice(1).forEach(function(r){{const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);}});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){{return r[1];}}))).sort(function(a,b){{return a-b;}});
    const series=[];for(var c=2;c<hdr.length;c++){{series.push({{x:tl,y:tl.map(function(t){{const rs=byScen[scens[0]];const r=rs?rs.find(function(rr){{return rr[1]===String(t);}}):null;return r?+r[c]:0;}}),name:hdr[c],type:'scatter',mode:'lines',fill:'tozeroy',line:{{color:C10[(c-2)%C10.length]}},fillcolor:C10[(c-2)%C10.length]+'22'}});}}
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Curtailment (MW)'}}}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){{byScen[sc].forEach(function(r){{th+='<tr>'+r.map(function(v){{return'<td>'+fmt(v,4)+'</td>';}}).join('')+'</tr>';}});}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='power_bal'){{
    const rows=sched['power_balance_summary'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No power balance data</div>';return;}}
    const hdr=rows[0],byScen={{}};rows.slice(1).forEach(function(r){{const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);}});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){{return r[1];}}))).sort(function(a,b){{return a-b;}});
    const keys=[2,3,4];const labels=['Thermal','Served Load','DataCenter Load'];
    const series=keys.map(function(k,i){{return{{x:tl,y:tl.map(function(t){{const rs=byScen[scens[0]];const r=rs?rs.find(function(rr){{return rr[1]===String(t);}}):null;return r?+r[k]:null;}}),name:labels[i],type:'scatter',mode:'lines',line:{{color:C10[i]}}}};}});
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Power (MW)'}}}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){{byScen[sc].forEach(function(r){{th+='<tr>'+r.map(function(v){{return'<td>'+fmt(v,4)+'</td>';}}).join('')+'</tr>';}});}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='startup'){{
    const rows=sched['unit_startup_shutdown_decisions'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No startup data</div>';return;}}
    const hdr=rows[0],dr=rows.slice(1),tl=dr.map(function(r){{return r[0];}}),nU=Math.floor((hdr.length-1)/2);
    const series=[];for(var u=0;u<nU;u++){{series.push({{x:tl,y:dr.map(function(r){{return +r[1+u];}}),name:'Unit '+(u+1)+' Start',type:'bar',marker:{{color:'#91cc75'}}}});series.push({{x:tl,y:dr.map(function(r){{return -Math.abs(+r[1+nU+u]);}}),name:'Unit '+(u+1)+' Stop',type:'bar',marker:{{color:'#ee6666'}}}});}}
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Decision',range:[-1.5,1.5],dtick:1}},barmode:'stack'}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){{th+='<tr>'+r.map(function(v){{return'<td>'+fmt(v,2)+'</td>';}}).join('')+'</tr>';}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}else if(scActive==='commit_txt'){{
    var txt=sched['schedule_commitment_result']||'';for(const k of Object.keys(sched)){{if(k.endsWith('_schedule_commitment_result')){{txt=sched[k];break;}}}}
    $('sc-plot').innerHTML='<pre class="short">'+escapeHTML(txt||'No commitment report available')+'</pre>';$('sc-table').innerHTML='';
  }}else if(scActive==='reserve'){{
    const rows=sched['reserve_schedule'];if(!rows||rows.length<2){{$('sc-plot').innerHTML='<div class="empty-state">No reserve data</div>';return;}}
    const hdr=rows[0],dr=rows.slice(1);
    const units=Array.from(new Set(dr.map(function(r){{return r[1];}}))).sort();
    const tl=Array.from(new Set(dr.map(function(r){{return r[2];}}))).sort(function(a,b){{return a-b;}});
    const series=[];units.forEach(function(u,i){{const d=dr.filter(function(r){{return r[1]===u;}});
      series.push({{x:tl,y:tl.map(function(t){{const r=d.find(function(rr){{return rr[2]===String(t);}});return r?+r[3]:null;}}),name:'Unit '+u+' Up',type:'scatter',mode:'lines',line:{{color:C10[(i*2)%C10.length]}}}});
      series.push({{x:tl,y:tl.map(function(t){{const r=d.find(function(rr){{return rr[2]===String(t);}});return r?+r[4]:null;}}),name:'Unit '+u+' Down',type:'scatter',mode:'lines',line:{{color:C10[(i*2+1)%C10.length],dash:'dash'}}}});
    }});
    show('sc-plot',series,{{xaxis:{{title:'Time (h)'}},yaxis:{{title:'Reserve (MW)'}}}});
    var th='<thead><tr>'+hdr.map(function(h){{return'<th>'+h+'</th>';}}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){{th+='<tr>'+r.map(function(v){{return'<td>'+fmt(v,4)+'</td>';}}).join('')+'</tr>';}});th+='</tbody>';$('sc-table').innerHTML=th;
  }}
}}

// ============ REPORTS ============
function renderReports(){{
  const runs=Object.keys(DATA.reports).sort();
  $('rp-run').innerHTML=runs.map(function(r){{return'<option>'+r+'</option>';}}).join('');
  $('rp-run').onchange=updateRp;
  const svgRuns=Object.keys(DATA.svgs).filter(function(r){{return Object.keys(DATA.svgs[r]).length;}}).sort();
  $('svg-run').innerHTML=svgRuns.map(function(r){{return'<option>'+r+'</option>';}}).join('');
  $('svg-run').onchange=updateSvgCharts;
  $('svg-zoom-out').onclick=function(){{setSvgZoom(Math.max(.5,svgZoom-.15));}};
  $('svg-zoom-reset').onclick=function(){{setSvgZoom(1);}};
  $('svg-zoom-in').onclick=function(){{setSvgZoom(Math.min(2.5,svgZoom+.15));}};
  if(runs.length)updateRp();if(svgRuns.length)updateSvgCharts();
}}

function updateRp(){{const r=$('rp-run').value;const h=DATA.reports[r]||'';$('rp-content').innerHTML=h||'<div class="empty-state">No report</div>';}}

function updateSvgCharts(){{
  const r=$('svg-run').value;
  const charts=Object.keys(DATA.svgs[r]||{{}}).sort();
  if(!charts.length){{activeSvgChart='';$('svg-chart-tabs').innerHTML='';updateSvgDisplay();return;}}
  if(!activeSvgChart||charts.indexOf(activeSvgChart)<0)activeSvgChart=charts[0];
  $('svg-chart-tabs').innerHTML=charts.map(function(c){{return'<button class="chart-tab'+(c===activeSvgChart?' active':'')+'" data-chart="'+escapeHTML(c)+'">'+formatChartLabel(c)+'</button>';}}).join('');
  $('svg-chart-tabs').onclick=function(e){{const b=e.target.closest('.chart-tab');if(!b)return;activeSvgChart=b.dataset.chart;document.querySelectorAll('.chart-tab').forEach(function(x){{x.classList.remove('active');}});b.classList.add('active');setSvgZoom(1);updateSvgDisplay();}};
  updateSvgDisplay();
}}

function updateSvgDisplay(){{
  const r=$('svg-run').value,c=activeSvgChart,b64=(DATA.svgs[r]||{{}})[c];
  if(!b64){{$('svg-display').innerHTML='<div class="empty-state">No SVG</div>';applyReportTheme();return;}}
  $('svg-display').innerHTML='<div class="report-svg-stage">'+atob(b64)+'</div>';
  const svg=$('svg-display').querySelector('svg');
  if(svg){{svg.setAttribute('role','img');svg.setAttribute('aria-label',formatChartLabel(c));if(!svg.querySelector('title')){{const title=document.createElementNS('http://www.w3.org/2000/svg','title');title.textContent=formatChartLabel(c);svg.prepend(title);}}}}
  attachSvgInteractions();
  setSvgZoom(svgZoom);
  applyReportTheme();
}}

function formatChartLabel(c){{return String(c||'Chart').replace(/_/g,' ').replace(/\\b\\w/g,function(m){{return m.toUpperCase();}});}}

function setSvgZoom(z){{
  svgZoom=z;
  const stage=$('svg-display')?$('svg-display').querySelector('.report-svg-stage'):null;
  if(stage)stage.style.transform='scale('+svgZoom+')';
  const reset=$('svg-zoom-reset');
  if(reset)reset.textContent=svgZoom.toFixed(1)+'x';
}}

function attachSvgInteractions(){{
  const svg=$('svg-display')?$('svg-display').querySelector('svg'):null;
  if(!svg)return;
  svg.querySelectorAll('rect,polyline,line,path,circle,text').forEach(function(el,i){{
    el.classList.add('svg-hotspot');
    if(!el.querySelector('title')){{const t=document.createElementNS('http://www.w3.org/2000/svg','title');t.textContent=(el.textContent||el.getAttribute('aria-label')||formatChartLabel(activeSvgChart)||'Chart item').trim();el.appendChild(t);}}
    el.addEventListener('click',function(ev){{ev.stopPropagation();svg.querySelectorAll('.svg-selected').forEach(function(x){{x.classList.remove('svg-selected');}});el.classList.add('svg-selected');}});
  }});
  svg.addEventListener('click',function(){{svg.querySelectorAll('.svg-selected').forEach(function(x){{x.classList.remove('svg-selected');}});}});
}}

function applyReportTheme(){{
  const wrap=$('svg-display');
  if(!wrap)return;
  const dark=isDarkTheme();
  wrap.classList.toggle('dark-chart',dark);
  const svg=wrap.querySelector('svg');
  if(!svg)return;
  const bg=dark?'#2a2a2a':'#ffffff';
  const text=dark?'#f8fafc':'#1e293b';
  const muted=dark?'#b0b0b0':'#333333';
  svg.style.background=bg;
  svg.querySelectorAll('rect').forEach(function(el,i){{const fill=(el.getAttribute('fill')||'').toLowerCase();if(i===0||fill==='white'||fill==='#fff'||fill==='#ffffff')el.setAttribute('fill',bg);}});
  svg.querySelectorAll('text').forEach(function(el){{el.setAttribute('fill',text);}});
  svg.querySelectorAll('line').forEach(function(el){{el.setAttribute('stroke',muted);}});
}}

// ============ SETTINGS ============
function renderSettings(){{
  const cfg=DATA.config;if(!cfg||!cfg.sections)return;
  const lm={{boundary:'Boundary',common:'Common',model:'Model',benders:'Benders','benders.cuts':'Benders \\u2014 Cuts','benders.subproblems':'Benders \\u2014 Subproblems',ccg:'CCG',dro:'DRO',frequency:'Frequency',test:'Test'}};
  const bySec={{}};cfg.sections.forEach(function(sec){{bySec[sec.name]=sec.fields||[];}});
  const inputSections=collectSections(cfg.sections,function(sec,f){{return classifySetting(sec.name,f)==='input';}});
  const testSections=collectSections(cfg.sections,function(sec,f){{return classifySetting(sec.name,f)==='testing';}});
  const modelLinearKeys=['MODEL_IS_PIECE_LINEAR','MODEL_NUM_SEGMENTS','MODEL_ALPHA','MODEL_BETA'];
  const modelLinear=collectSections(cfg.sections,function(sec,f){{return modelLinearKeys.indexOf(f.key)>=0;}});
  const modelFrequency=collectSections(cfg.sections,function(sec,f){{return String(sec.name).toLowerCase()==='frequency';}});
  const modelBase=collectSections(cfg.sections,function(sec,f){{return classifySetting(sec.name,f)==='model'&&modelLinearKeys.indexOf(f.key)<0&&String(sec.name).toLowerCase()!=='frequency';}});
  const bendersSections=['benders','benders.cuts','benders.subproblems'].map(function(name){{return{{name:name,fields:bySec[name]||[]}};}}).filter(function(sec){{return sec.fields.length;}});
  const ccgSections=['ccg','dro'].map(function(name){{return{{name:name,fields:bySec[name]||[]}};}}).filter(function(sec){{return sec.fields.length;}});

  var html='';
  html+=settingsCard('algorithm','Algorithm Settings','Solvers, decomposition controls, convergence tolerances, cuts, and iteration policies.',
    'Algorithm Mode','settings-algorithm-mode',[['benders','Benders'],['ccg','CCG']],[
      panelHtml('benders',bendersSections,'Benders-specific relaxation, cut, and subproblem parameters.'),
      panelHtml('ccg',ccgSections,'Column-and-constraint generation master/recourse and DRO parameters.')
    ]);
  html+=settingsCard('input','Input Settings','Input source presets and boundary/data loading controls.',
    'Data Source','settings-data-source',[['excel','Custom Excel'],['ieee118','Built-in IEEE 118 Case'],['ieee14','Built-in IEEE 14 Case']],[
      panelHtml('excel',inputSections,'Custom data source and boundary import controls.'),
      panelNote('ieee118','Built-in IEEE 118 benchmark selected. Custom Excel path controls are hidden but kept in the saved configuration.'),
      panelNote('ieee14','Built-in IEEE 14 benchmark selected. Use this lightweight case for fast validation runs.')
    ]);
  html+=settingsCard('model','Model Settings','Network topology, constraint architecture, relaxation coefficients, BESS, and frequency model parameters.',
    'Network topology / constraint architecture','settings-model-formulation',[['dc','DC-OPF (DC power flow)'],['ac','AC-OPF (AC power flow)'],['linearized','Grid Linearization (linearized network)']],[
      panelHtml('dc',modelBase,'DC-OPF and system-level model switches.'),
      panelHtml('ac',modelFrequency,'AC-OPF placeholder mapped to frequency/security related controls available in this project.'),
      panelHtml('linearized',modelLinear,'Piecewise and grid linearization parameters.')
    ]);
  html+=settingsCard('testing','Testing Settings','Benchmark cases, scenario mode, deterministic/stochastic validation, and test harness options.',
    'Testing Mode','settings-testing-mode',[['deterministic','Deterministic Validation'],['stochastic','Stochastic Scenario Test'],['reduction','Scenario Reduction']],[
      panelHtml('deterministic',testSections,'Deterministic test harness and local project activation settings.'),
      panelNote('stochastic','Stochastic scenario count and algorithm iteration controls are managed in Algorithm Settings for Benders/CCG.'),
      panelNote('reduction','Scenario reduction mode is a UI preset; add project-specific reduction keys to runtime_config.toml to expose editable fields here.')
    ]);
  $('settings-grid').innerHTML=html;
  bindSettingSelects();
}}

function classifySetting(sectionName,f){{
  const sec=String(sectionName||'').toLowerCase();
  const key=String(f.key||'').toUpperCase();
  if(sec==='test'||key.indexOf('TEST')>=0||key.indexOf('BENCHMARK')>=0||key.indexOf('IEEE')>=0||key.indexOf('CASE')>=0)return'testing';
  if(sec==='boundary'||key.indexOf('PATH')>=0||key.indexOf('EXCEL')>=0||key.indexOf('SOURCE')>=0||key.indexOf('INPUT')>=0||key.indexOf('SAMPLE')>=0||key.indexOf('LOAD')>=0)return'input';
  if(sec==='model'||sec==='frequency'||key.indexOf('MODEL_')===0||key.indexOf('FREQUENCY_')===0||key.indexOf('NETWORK')>=0||key.indexOf('SYSTEM')>=0||key.indexOf('THERMAL')>=0||key.indexOf('WIND')>=0||key.indexOf('BESS')>=0||key.indexOf('COEFFICIENT')>=0||key.indexOf('BASE')>=0)return'model';
  return'algorithm';
}}

function settingFieldHtml(f){{
  const id='cfg-'+f.key;
  if(f.type==='bool')return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="checkbox" id="'+id+'" data-key="'+f.key+'" '+(f.value?'checked':'')+'></div>';
  if(f.type==='number'||f.type==='float'||f.type==='integer')return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="number" id="'+id+'" data-key="'+f.key+'" value="'+f.value+'" step="any"></div>';
  return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="text" id="'+id+'" data-key="'+f.key+'" value="'+escapeHtml(String(f.value))+'"></div>';
}}

function collectSections(sections,predicate){{
  return sections.map(function(sec){{return{{name:sec.name,fields:(sec.fields||[]).filter(function(f){{return predicate(sec,f);}})}};}}).filter(function(sec){{return sec.fields.length;}});
}}

function settingsCard(id,title,note,controlLabel,selectId,options,panels){{
  return '<fieldset class="settings-category settings-'+id+'"><legend>'+title+'</legend><div class="category-note">'+note+'</div><div class="setting-control"><label for="'+selectId+'">'+controlLabel+'</label><select id="'+selectId+'" data-setting-router="'+id+'">'+options.map(function(o){{return'<option value="'+o[0]+'">'+o[1]+'</option>';}}).join('')+'</select></div><div class="setting-panels" data-setting-panels="'+id+'">'+panels.join('')+'</div></fieldset>';
}}

function panelHtml(value,sections,note){{
  var body=sections.length?sections.map(renderSettingsSection).join(''):'<div class="setting-panel-note">No editable fields are currently mapped to this mode.</div>';
  return '<div class="setting-panel sf-hidden" data-panel="'+value+'"><div class="setting-panel-note">'+note+'</div>'+body+'</div>';
}}

function panelNote(value,note){{
  return '<div class="setting-panel sf-hidden" data-panel="'+value+'"><div class="setting-panel-note">'+note+'</div></div>';
}}

function renderSettingsSection(sec){{
  const lm={{boundary:'Boundary',common:'Common',model:'Model',benders:'Benders','benders.cuts':'Benders \\u2014 Cuts','benders.subproblems':'Benders \\u2014 Subproblems',ccg:'CCG',dro:'DRO',frequency:'Frequency',test:'Test'}};
  return '<div class="settings-section"><h3>'+(lm[sec.name]||sec.name)+'</h3><div class="fields">'+sec.fields.map(settingFieldHtml).join('')+'</div></div>';
}}

function bindSettingSelects(){{
  document.querySelectorAll('[data-setting-router]').forEach(function(sel){{
    function sync(){{
      const group=sel.dataset.settingRouter;
      document.querySelectorAll('[data-setting-panels="'+group+'"] .setting-panel').forEach(function(panel){{const active=panel.dataset.panel===sel.value;panel.classList.toggle('active',active);panel.classList.toggle('sf-hidden',!active);}});
    }}
    sel.onchange=sync;
    sync();
  }});
}}

function escapeHtml(s){{return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}}

async function saveConfig(){{
  const btn=$('save-config-btn'),msg=$('save-msg');btn.disabled=true;msg.className='msg';msg.textContent='Saving...';
  const u={{}};let invalid=null;document.querySelectorAll('[data-key]').forEach(function(el){{const k=el.dataset.key;if(el.type==='checkbox')u[k]=el.checked;else if(el.type==='number'){{const v=Number(el.value);if(el.value===''||Number.isNaN(v))invalid=k;else u[k]=v;}}else u[k]=el.value;}});
  if(invalid){{msg.className='msg err';msg.textContent='Invalid numeric value: '+invalid;btn.disabled=false;return;}}
  try{{const r=await apiFetch('/api/config',{{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify(u)}});if(r.ok){{msg.className='msg ok';msg.textContent='Saved.';}}else{{let detail='';try{{const err=await r.json();detail=err.error?': '+err.error:'';}}catch(e){{}}msg.className='msg err';msg.textContent='Save failed: '+r.status+detail;}}}}catch(e){{msg.className='msg err';msg.textContent='Save failed - server running?';}}
  btn.disabled=false;setTimeout(function(){{msg.textContent='';}},3000);
}}
{run_js}

try{{init();}}catch(e){{document.body.innerHTML='<div style="padding:40px;color:#dc2626;font-family:monospace;"><h2>Error</h2><pre>'+e.message+'</pre><pre>'+e.stack+'</pre></div>';}}
</script></body></html>'''

    out_path = GUI / 'index.html'
    with open(out_path, 'w') as f:
        f.write(html)
    print(f'Generated {out_path} ({len(html)} bytes)')


if __name__ == '__main__':
    main()
