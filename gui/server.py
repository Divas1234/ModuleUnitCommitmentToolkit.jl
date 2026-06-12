#!/usr/bin/env python3
"""HTTP server: serves static files + config read/write API + Julia task runner."""
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import tomllib
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / 'config' / 'runtime_config.toml'
VALID_TASKS = ("boundary", "benchmark", "ccg", "benders", "benders_fast", "tests")
JULIA_STARTUP_TIMEOUT = 60
JULIA_RUN_TIMEOUT = 3600
ANSI_RE = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def julia_env():
    """Return a clean Julia subprocess environment.

    Passing JULIA_DEPOT_PATH="" makes Julia 1.12 fail during precompilation with
    an internal BoundsError, so preserve it only when the user actually set it.
    """
    env = os.environ.copy()
    if not env.get("JULIA_DEPOT_PATH"):
        env.pop("JULIA_DEPOT_PATH", None)
    return env

# ---------------------------------------------------------------------------
# Julia check
# ---------------------------------------------------------------------------

def check_julia():
    """Return (ok, msg). Checks if `julia` is available and responsive."""
    julia = shutil.which("julia")
    if not julia:
        return False, "`julia` not found in PATH. Install Julia (https://julialang.org) and ensure it is on $PATH."
    try:
        r = subprocess.run(
            [julia, "-v"],
            capture_output=True, text=True, timeout=15,
            env=julia_env(),
        )
        if r.returncode == 0 and r.stdout.strip():
            return True, r.stdout.strip()
        stderr = (r.stderr or "").strip()
        if "locked by another process" in stderr:
            return False, "Julia is locked by another process. Run:  pkill -f juliaup  &&  pkill -f julia"
        return False, f"Julia binary found but not responding:\n{stderr or '(no output)'}"
    except FileNotFoundError:
        return False, f"Julia binary not found at {julia}"
    except subprocess.TimeoutExpired:
        return False, f"Julia binary at {julia} timed out (possibly corrupted installation)."
    except OSError as e:
        return False, f"Cannot execute Julia at {julia}: {e}"

# ---------------------------------------------------------------------------
# Run manager — background Julia process handling
# ---------------------------------------------------------------------------

class RunManager:
    def __init__(self):
        self._lock = threading.Lock()
        self._timer = None
        self.reset()

    def reset(self):
        self.task = None
        self.status = "idle"
        self.output = []
        self._proc = None
        self._structured = None
        self._cancel_requested = False
        if self._timer:
            self._timer.cancel()
            self._timer = None

    def start(self, task, params=None):
        if task not in VALID_TASKS:
            raise ValueError(f"Unknown task '{task}'. Valid: {', '.join(VALID_TASKS)}")

        julia_ok, julia_msg = check_julia()
        if not julia_ok:
            self.output = [f"[ERROR] {julia_msg}\n"]
            self.task = task
            self.status = "failed"
            return False

        with self._lock:
            if self.status == "running":
                return False
            self.reset()
            self.task = task
            self.status = "running"

        def _run():
            try:
                cmd, env = self._build_cmd(task, params or {})
                self._proc = subprocess.Popen(
                    cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, bufsize=1, cwd=str(ROOT), env=env,
                )

                self._timer = threading.Timer(JULIA_RUN_TIMEOUT, self._timeout_kill)
                self._timer.start()

                structured_lines = []
                in_structured = False
                for line in iter(self._proc.stdout.readline, ""):
                    line = ANSI_RE.sub("", line)
                    stripped = line.strip()
                    with self._lock:
                        if in_structured:
                            if stripped == "###END_STRUCTURED_DATA###":
                                in_structured = False
                            else:
                                structured_lines.append(line)
                            continue
                        if stripped == "###STRUCTURED_DATA###":
                            in_structured = True
                            continue
                        self.output.append(line)

                self._proc.wait()
                rc = self._proc.returncode
                with self._lock:
                    if self._cancel_requested or self.status == "cancelled":
                        self.status = "cancelled"
                    elif rc == 0:
                        self.status = "completed"
                    else:
                        self.status = "failed"
                    self._proc = None
                    if structured_lines:
                        try:
                            self._structured = json.loads("".join(structured_lines))
                        except json.JSONDecodeError:
                            self._structured = None
            except Exception as e:
                with self._lock:
                    self.output.append(f"\n[ERROR] {e}\n")
                    self.status = "failed"
            finally:
                if self._timer:
                    self._timer.cancel()
                    self._timer = None

        threading.Thread(target=_run, daemon=True).start()
        return True

    def _timeout_kill(self):
        with self._lock:
            if self._proc and self._proc.poll() is None:
                self._proc.kill()
                self.output.append(f"\n[ERROR] Task timed out after {JULIA_RUN_TIMEOUT}s\n")
                self.status = "failed"
                self._proc = None

    def cancel(self):
        with self._lock:
            if self._proc and self._proc.poll() is None:
                self._cancel_requested = True
                self._proc.terminate()
                self.output.append("\n[INFO] Cancellation requested.\n")
                self.status = "cancelled"
                return True
            if self.status == "running":
                self._cancel_requested = True
                self.status = "cancelled"
                return True
        return False

    def get_state(self):
        with self._lock:
            return {
                "task": self.task,
                "status": self.status,
                "output_len": len(self.output),
                "output": self.output[-600:],
                "structured": self._structured,
            }

    def _build_cmd(self, task, params):
        env = julia_env()
        env["PYTHON"] = ""
        env["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

        if task == "boundary":
            limit = str(params.get("scenario_limit", 5))
            return ["julia", "gui/run_boundary.jl", limit], env

        if task == "benchmark":
            counts = params.get("scenario_counts", "2,6,10")
            env["BENCHMARK_SCENARIO_COUNTS"] = counts
            return ["julia", "tools/benchmark/run_algorithm_comparison.jl"], env

        if task == "ccg":
            limit = str(params.get("scenario_limit", 20))
            env["CCG_SCENARIO_LIMIT"] = limit
            return ["julia", "tools/ccg/driver.jl"], env

        if task == "benders":
            limit = str(params.get("scenario_limit", 20))
            env["BENDERS_SCENARIO_LIMIT"] = limit
            return ["julia", "tools/benders/driver.jl"], env

        if task == "benders_fast":
            limit = str(params.get("scenario_limit", 20))
            env["BENDERS_SCENARIO_LIMIT"] = limit
            env["BENDERS_FAST_DIRECT_SOLVE"] = "1"
            return ["julia", "tools/benders/driver.jl"], env

        if task == "tests":
            env["MODULE_UC_TEST_ACTIVATE_LOCAL_PROJECT"] = "0"
            return ["julia", "test/runtests.jl"], env

        raise ValueError(f"Unknown task: {task}")


RUN_MGR = RunManager()

# ---------------------------------------------------------------------------
# TOML helpers
# ---------------------------------------------------------------------------

def parse_toml_with_lines(path):
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
                t = 'bool' if isinstance(v, bool) else 'number' if isinstance(v, (int, float)) else 'string'
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
                         'type': 'bool' if isinstance(fv, bool) else 'number' if isinstance(fv, (int, float)) else 'string',
                         'section': f'{sec_name}.{k}',
                         'line': key_lines.get(fk, {}).get('line', -1),
                         'raw_value': key_lines.get(fk, {}).get('raw_value', str(fv))}
                        for fk, fv in v.items()
                    ]})

    return {'sections': sections, '_lines': lines, '_key_lines': key_lines,
            '_raw': {k: v['raw_value'] for k, v in key_lines.items()}}


def write_toml_values(path, updates):
    parsed = parse_toml_with_lines(path)
    lines = parsed['_lines'][:]
    key_lines = parsed['_key_lines']

    def _format_toml_value(new_value, old_raw):
        if new_value is None:
            raise ValueError("Empty numeric values are not valid TOML values")
        if isinstance(new_value, bool):
            return 'true' if new_value else 'false'
        if isinstance(new_value, str):
            if old_raw.startswith(("'", '"')):
                return json.dumps(new_value)
            return new_value
        if isinstance(new_value, (int, float)):
            return str(new_value)
        raise ValueError(f"Unsupported value type: {type(new_value).__name__}")

    for key, new_value in updates.items():
        if key not in key_lines:
            continue
        meta = key_lines[key]
        line_no = meta['line']
        old_line = lines[line_no]
        old_raw = meta['raw_value']
        new_raw = _format_toml_value(new_value, old_raw)
        lines[line_no] = old_line.replace(old_raw, new_raw, 1)

    path.write_text('\n'.join(lines))


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/config':
            result = parse_toml_with_lines(CONFIG_PATH)
            del result['_lines']
            del result['_key_lines']
            self._send_json(result)
            return

        if path == '/api/run':
            self._send_json(RUN_MGR.get_state())
            return

        if path == '/api/check/julia':
            ok, msg = check_julia()
            self._send_json({'ok': ok, 'msg': msg})
            return

        if path in ('/', '/gui', '/gui/', '/GUI', '/GUI/'):
            self.path = '/gui/index.html'
        super().do_GET()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        try:
            body = json.loads(self.rfile.read(length)) if length else {}
        except json.JSONDecodeError as e:
            self._send_json({'ok': False, 'error': f'Invalid JSON: {e}'}, status=400)
            return

        path = urlparse(self.path).path

        if path == '/api/config':
            try:
                write_toml_values(CONFIG_PATH, body)
                self._send_json({'ok': True})
            except ValueError as e:
                self._send_json({'ok': False, 'error': str(e)}, status=400)
            return

        if path == '/api/run':
            task = body.get('task', '')
            params = body.get('params', {})
            try:
                ok = RUN_MGR.start(task, params)
                state = RUN_MGR.get_state()
                error = 'Task already running' if not ok and state.get('status') == 'running' else None
                self._send_json({'ok': ok, 'task': task, 'status': state.get('status'), 'error': error})
            except ValueError as e:
                self._send_json({'ok': False, 'error': str(e)}, status=400)
            return

        if path == '/api/run/cancel':
            self._send_json({'ok': RUN_MGR.cancel()})
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
    ok, msg = check_julia()
    print(f"Julia check: {'OK' if ok else 'FAIL'} {msg}")
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print(f'Server running at http://localhost:8080/gui/')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
