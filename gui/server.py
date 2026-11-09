#!/usr/bin/env python3
"""HTTP server: serves static files + config read/write API + Julia task runner."""
import json
import hmac
import ipaddress
import math
import os
import re
import shutil
import signal
import subprocess
import threading
import time
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
SCENARIO_COUNTS_RE = re.compile(r'^[1-9][0-9]*(,[1-9][0-9]*)*$')
MAX_REQUEST_BYTES = 1_048_576
RATE_LIMIT_WINDOW = 60.0
API_RATE_LIMIT = 120
RUN_RATE_LIMIT = 10
GUI_HOST = os.environ.get("MODULE_UC_GUI_HOST", "127.0.0.1")
GUI_PORT = int(os.environ.get("MODULE_UC_GUI_PORT", "8080"))
GUI_TOKEN = os.environ.get("MODULE_UC_GUI_TOKEN", "")
GUI_ALLOW_REMOTE = os.environ.get("MODULE_UC_GUI_ALLOW_REMOTE", "0").lower() in {"1", "true", "yes", "on"}
GUI_ALLOWED_ORIGINS = {
    origin.strip().rstrip("/")
    for origin in os.environ.get("MODULE_UC_GUI_ALLOWED_ORIGINS", "").split(",")
    if origin.strip()
}
RATE_STATE = {}
RATE_LOCK = threading.Lock()
TASK_OUTPUT_DIRS = {
    "benchmark": ("comparison", "benchmark_uc", "benders", "ccg"),
    "ccg": ("ccg",),
    "benders": ("benders",),
    "benders_fast": ("benders",),
    "boundary": (),
    "tests": (),
}


def is_loopback_host(host):
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def validate_server_config():
    if not 1 <= GUI_PORT <= 65535:
        raise RuntimeError("MODULE_UC_GUI_PORT must be between 1 and 65535")
    remote = not is_loopback_host(GUI_HOST)
    if remote and not GUI_ALLOW_REMOTE:
        raise RuntimeError("Remote GUI binding requires MODULE_UC_GUI_ALLOW_REMOTE=1")
    if remote and not GUI_TOKEN:
        raise RuntimeError("Remote GUI binding requires MODULE_UC_GUI_TOKEN")
    if remote and not GUI_ALLOWED_ORIGINS:
        raise RuntimeError("Remote GUI binding requires MODULE_UC_GUI_ALLOWED_ORIGINS")


def rate_limit_key(handler, bucket):
    address = handler.client_address[0] if handler.client_address else "unknown"
    return bucket, address


def allow_request(handler, bucket, limit):
    now = time.monotonic()
    key = rate_limit_key(handler, bucket)
    with RATE_LOCK:
        timestamps = [stamp for stamp in RATE_STATE.get(key, []) if now - stamp < RATE_LIMIT_WINDOW]
        if len(timestamps) >= limit:
            RATE_STATE[key] = timestamps
            return False
        timestamps.append(now)
        RATE_STATE[key] = timestamps
        return True


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
        self._result_meta = None
        self._run_started_at = None
        self._cancel_requested = False
        if self._timer:
            self._timer.cancel()
            self._timer = None

    def start(self, task, params=None):
        task, params = validate_run_request({"task": task, "params": params or {}})
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
            self._run_started_at = time.time()

        def _run():
            try:
                cmd, env = self._build_cmd(task, params)
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
                    if self.status == "completed":
                        self._result_meta = self._collect_result_metadata(task)
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
                "result_path": (self._result_meta or {}).get("result_path"),
                "summaries": (self._result_meta or {}).get("summaries", []),
            }

    def _collect_result_metadata(self, task):
        candidates = []
        summaries = []

        for rel in TASK_OUTPUT_DIRS.get(task, ()):
            root = ROOT / "output" / rel
            if not root.exists():
                continue
            for path in root.rglob("*"):
                if path.is_file() and path.suffix.lower() in (".log", ".csv", ".txt", ".md"):
                    candidates.append(path)

        comparison_root = ROOT / "output" / "comparison"
        if task == "benchmark" and comparison_root.exists():
            for summary_path in comparison_root.glob("*/summary.csv"):
                summaries.append({"path": str(summary_path), "mtime": summary_path.stat().st_mtime})
                candidates.append(summary_path)

        fresh_candidates = []
        if self._run_started_at:
            fresh_candidates = [p for p in candidates if p.stat().st_mtime >= self._run_started_at - 2]
            if fresh_candidates:
                candidates = fresh_candidates

        if not candidates:
            return {"result_path": None, "summaries": summaries}

        newest = max(candidates, key=lambda p: p.stat().st_mtime)
        log_candidates = [p for p in candidates if p.suffix.lower() == ".log"]
        if log_candidates:
            newest = max(log_candidates, key=lambda p: p.stat().st_mtime)

        summaries.sort(key=lambda item: item["mtime"], reverse=True)
        return {
            "result_path": str(newest),
            "summaries": summaries[:5],
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


def validate_config_updates(updates):
    if not isinstance(updates, dict):
        raise ValueError("Configuration updates must be a JSON object")
    known_keys = set(parse_toml_with_lines(CONFIG_PATH)["_key_lines"])
    for key, value in updates.items():
        if not isinstance(key, str) or key not in known_keys:
            raise ValueError(f"Unknown configuration key: {key}")
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            if isinstance(value, float) and not math.isfinite(value):
                raise ValueError(f"Invalid numeric value for {key}")
            continue
        if isinstance(value, str) and len(value) <= 256:
            continue
        raise ValueError(f"Invalid value for {key}")


def validate_run_request(body):
    if not isinstance(body, dict):
        raise ValueError("Run request must be a JSON object")
    task = body.get("task")
    if not isinstance(task, str) or task not in VALID_TASKS:
        raise ValueError(f"Unknown task '{task}'. Valid: {', '.join(VALID_TASKS)}")
    params = body.get("params", {})
    if not isinstance(params, dict):
        raise ValueError("params must be a JSON object")

    allowed = {
        "boundary": {"scenario_limit"},
        "benchmark": {"scenario_counts"},
        "ccg": {"scenario_limit"},
        "benders": {"scenario_limit"},
        "benders_fast": {"scenario_limit"},
        "tests": set(),
    }[task]
    unknown = set(params) - allowed
    if unknown:
        raise ValueError(f"Unsupported parameters for {task}: {sorted(unknown)}")

    if "scenario_limit" in params:
        limit = params["scenario_limit"]
        if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= 200:
            raise ValueError("scenario_limit must be an integer between 1 and 200")
    if "scenario_counts" in params:
        counts = params["scenario_counts"]
        if not isinstance(counts, str) or len(counts) > 128 or not SCENARIO_COUNTS_RE.fullmatch(counts):
            raise ValueError("scenario_counts must be comma-separated positive integers")
        if any(int(value) > 200 for value in counts.split(",")):
            raise ValueError("scenario_counts values must be between 1 and 200")
    return task, params


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.plot.ly; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'")
        super().end_headers()

    def _allowed_origins(self):
        if GUI_ALLOWED_ORIGINS:
            return GUI_ALLOWED_ORIGINS
        if is_loopback_host(GUI_HOST):
            return {
                f'http://localhost:{GUI_PORT}',
                f'http://127.0.0.1:{GUI_PORT}',
                f'http://[::1]:{GUI_PORT}',
            }
        return set()

    def _origin_allowed(self):
        origin = self.headers.get('Origin')
        return not origin or origin.rstrip('/') in self._allowed_origins()

    def _authorized(self):
        if not GUI_TOKEN and is_loopback_host(GUI_HOST):
            return True
        authorization = self.headers.get('Authorization', '')
        scheme, _, token = authorization.partition(' ')
        return scheme.lower() == 'bearer' and bool(token) and hmac.compare_digest(token, GUI_TOKEN)

    def _guard_api(self, mutating=False, expensive=False):
        if not allow_request(self, 'api', API_RATE_LIMIT):
            self._send_json({'ok': False, 'error': 'Rate limit exceeded'}, status=429)
            return False
        if not self._authorized():
            self._send_json({'ok': False, 'error': 'Authentication required'}, status=401)
            return False
        if mutating and not self._origin_allowed():
            self._send_json({'ok': False, 'error': 'Origin is not allowed'}, status=403)
            return False
        if expensive and not allow_request(self, 'run', RUN_RATE_LIMIT):
            self._send_json({'ok': False, 'error': 'Run request rate limit exceeded'}, status=429)
            return False
        return True

    def _read_json_body(self):
        content_length = self.headers.get('Content-Length')
        if content_length is None:
            raise ValueError('Content-Length is required')
        try:
            length = int(content_length)
        except ValueError as exc:
            raise ValueError('Invalid Content-Length') from exc
        if length < 0 or length > MAX_REQUEST_BYTES:
            raise ValueError('Request body is too large')
        raw = self.rfile.read(length)
        if len(raw) != length:
            raise ValueError('Incomplete request body')
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError as exc:
            raise ValueError('Invalid JSON body') from exc
        if not isinstance(body, dict):
            raise ValueError('JSON body must be an object')
        return body

    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        origin = self.headers.get('Origin', '').rstrip('/')
        if origin and origin in self._allowed_origins():
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Vary', 'Origin')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(json.dumps(data, separators=(',', ':')).encode())

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/') and not self._guard_api():
            return

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
        if self.path.startswith('/gui/'):
            super().do_GET()
            return
        self.send_error(404, 'Not found')

    def do_POST(self):
        path = urlparse(self.path).path
        if path not in ('/api/config', '/api/run', '/api/run/cancel'):
            self.send_error(404, 'Not found')
            return
        if not self._guard_api(mutating=True, expensive=path == '/api/run'):
            return
        if path == '/api/run/cancel':
            body = {}
        else:
            if self.headers.get('Content-Type', '').split(';', 1)[0].lower() != 'application/json':
                self._send_json({'ok': False, 'error': 'Content-Type must be application/json'}, status=415)
                return
            try:
                body = self._read_json_body()
            except ValueError as exc:
                self._send_json({'ok': False, 'error': str(exc)}, status=400)
                return

        if path == '/api/config':
            try:
                validate_config_updates(body)
                write_toml_values(CONFIG_PATH, body)
                self._send_json({'ok': True})
            except ValueError as e:
                self._send_json({'ok': False, 'error': str(e)}, status=400)
            return

        if path == '/api/run':
            try:
                task, params = validate_run_request(body)
                ok = RUN_MGR.start(task, params)
                state = RUN_MGR.get_state()
                error = 'Task already running' if not ok and state.get('status') == 'running' else None
                self._send_json({'ok': ok, 'task': task, 'status': state.get('status'), 'error': error})
            except ValueError as exc:
                self._send_json({'ok': False, 'error': str(exc)}, status=400)
            return

        if path == '/api/run/cancel':
            self._send_json({'ok': RUN_MGR.cancel()})
            return

    def do_OPTIONS(self):
        if not self._origin_allowed():
            self._send_json({'ok': False, 'error': 'Origin is not allowed'}, status=403)
            return
        self.send_response(204)
        origin = self.headers.get('Origin', '').rstrip('/')
        if origin:
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Vary', 'Origin')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
        self.end_headers()


if __name__ == '__main__':
    validate_server_config()
    ok, msg = check_julia()
    print(f"Julia check: {'OK' if ok else 'FAIL'} {msg}")
    # The dashboard exposes local config-write and process-launch endpoints.
    # Keep the default listener local unless deployment explicitly adds its own
    # authenticated front end.
    server = HTTPServer((GUI_HOST, GUI_PORT), Handler)
    print(f'Server running at http://{GUI_HOST}:{GUI_PORT}/gui/')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
