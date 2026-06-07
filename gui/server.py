#!/usr/bin/env python3
"""HTTP server: serves static files + config read/write API for the dashboard."""
import json
import re
import tomllib
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / 'config' / 'runtime_config.toml'


def parse_toml_with_lines(path):
    """Parse TOML and return sections + line-number metadata for write-back."""
    text = path.read_text()
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
        fields = []
        sec_data = parsed[sec_name]
        if isinstance(sec_data, dict):
            for k, v in sec_data.items():
                if isinstance(v, dict):
                    continue
                t = 'bool' if isinstance(v, bool) else 'float' if isinstance(v, (int, float)) else 'string'
                fields.append({'key': k, 'value': v, 'type': t,
                               'section': sec_name,
                               'line': key_lines.get(k, {}).get('line', -1),
                               'raw_value': key_lines.get(k, {}).get('raw_value', str(v))})
        sections.append({'name': sec_name, 'fields': fields})

    for sec_name in parsed:
        sec_data = parsed[sec_name]
        if isinstance(sec_data, dict):
            for k, v in sec_data.items():
                if isinstance(v, dict):
                    sections.append({'name': f'{sec_name}.{k}', 'fields': [
                        {'key': fk, 'value': fv,
                         'type': 'bool' if isinstance(fv, bool) else 'float' if isinstance(fv, (int, float)) else 'string',
                         'section': f'{sec_name}.{k}',
                         'line': key_lines.get(fk, {}).get('line', -1),
                         'raw_value': key_lines.get(fk, {}).get('raw_value', str(fv))}
                        for fk, fv in v.items()
                    ]})

    return {'sections': sections, '_lines': lines, '_key_lines': key_lines,
            '_raw': {k: v['raw_value'] for k, v in key_lines.items()}}


def write_toml_values(path, updates):
    """Write updated values back to TOML by replacing on specific lines."""
    parsed = parse_toml_with_lines(path)
    lines = parsed['_lines'][:]
    key_lines = parsed['_key_lines']

    for key, new_value in updates.items():
        if key not in key_lines:
            continue
        meta = key_lines[key]
        line_no = meta['line']
        old_line = lines[line_no]
        old_raw = meta['raw_value']
        if isinstance(new_value, bool):
            new_raw = 'true' if new_value else 'false'
        elif isinstance(new_value, str):
            new_raw = f'"{new_value}"' if '"' in old_raw or "'" in old_raw else new_raw
        elif isinstance(new_value, (int, float)):
            new_raw = str(new_value)
        else:
            new_raw = str(new_value)
        lines[line_no] = old_line.replace(old_raw, new_raw, 1)

    path.write_text('\n'.join(lines))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        if self.path == '/api/config':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            result = parse_toml_with_lines(CONFIG_PATH)
            del result['_lines']
            del result['_key_lines']
            self.wfile.write(json.dumps(result).encode())
            return
        if self.path == '/':
            self.path = '/gui/index.html'
        super().do_GET()

    def do_POST(self):
        if self.path == '/api/config':
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length))
            write_toml_values(CONFIG_PATH, body)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'ok': True}).encode())
            return
        self.send_response(404)
        self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()


if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print('Server running at http://localhost:8080/gui/')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
