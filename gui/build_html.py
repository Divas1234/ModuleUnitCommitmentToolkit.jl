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
    assets_dir = GUI / "assets"
    css_text = (assets_dir / "style.css").read_text(encoding="utf-8").replace("/* __RUN_CSS__ */", run_css)
    body_text = (assets_dir / "body.html").read_text(encoding="utf-8").replace("<!-- __RUN_HTML__ -->", run_html)
    js_text = (
        (assets_dir / "app.js")
        .read_text(encoding="utf-8")
        .replace("__DATA_JSON__", json.dumps(data, ensure_ascii=False))
        .replace("/* __RUN_JS__ */", run_js)
    )
    html = (
        '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="UTF-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
        '<title>Unit Commitment Results Dashboard</title>\n'
        '<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>\n'
        '<style>\n' + css_text + '\n</style>\n</head>\n<body>\n'
        + body_text + '<script>\n' + js_text + '\n</script></body></html>'
    )

    out_path = GUI / 'index.html'
    with open(out_path, 'w') as f:
        f.write(html)
    print(f'Generated {out_path} ({len(html)} bytes)')


if __name__ == '__main__':
    main()
