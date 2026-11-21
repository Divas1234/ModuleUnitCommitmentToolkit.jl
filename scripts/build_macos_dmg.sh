#!/usr/bin/env bash
set -euo pipefail

# Build a standalone macOS .app bundle and compressed .dmg installer for
# ModuleUnitCommitmentToolkit.jl (lightweight mode using host Julia/Python).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="ModuleUnitCommitmentToolkit"
BUNDLE_ID="io.github.moduleunitcommitmenttoolkit"
VERSION="$(python3 -c '
import tomllib, pathlib
data = tomllib.loads(pathlib.Path("'"$PROJECT_ROOT/Project.toml"'").read_text(encoding="utf-8"))
print(data.get("version", "0.1.0"))
')"
BUILD_STAMP="$(date +%Y%m%d_%H%M%S)"

DIST_DIR="$PROJECT_ROOT/Release"
STAGE_DIR="$DIST_DIR/dmg_stage"
APP_BUNDLE="$STAGE_DIR/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-macOS.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "=== Building ${APP_NAME} v${VERSION} macOS DMG ==="
rm -rf "$STAGE_DIR" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" \
         "$APP_BUNDLE/Contents/Resources/project"

# 1. Copy clean project payload into Contents/Resources/project
echo "[1/5] Copying clean project files..."
rsync -a \
  --exclude '.git' \
  --exclude '.DS_Store' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pkg' \
  --exclude '.vscode' \
  --exclude 'dist' \
  --exclude 'Release' \
  --exclude 'output' \
  --exclude '*.dmg' \
  "$PROJECT_ROOT/src" \
  "$PROJECT_ROOT/config" \
  "$PROJECT_ROOT/data" \
  "$PROJECT_ROOT/docs" \
  "$PROJECT_ROOT/examples" \
  "$PROJECT_ROOT/gui" \
  "$PROJECT_ROOT/scripts" \
  "$PROJECT_ROOT/test" \
  "$PROJECT_ROOT/tools" \
  "$PROJECT_ROOT/Project.toml" \
  "$PROJECT_ROOT/Manifest.toml" \
  "$PROJECT_ROOT/README.md" \
  "$PROJECT_ROOT/LICENSE" \
  "$APP_BUNDLE/Contents/Resources/project/"

printf '%s-%s\n' "$VERSION" "$BUILD_STAMP" > "$APP_BUNDLE/Contents/Resources/BUILD_STAMP"

# 2. Generate crisp macOS AppIcon.icns using Python stdlib + sips + iconutil
echo "[2/5] Generating macOS application icon (.icns)..."
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
BASE_PNG="$DIST_DIR/icon_1024.png"
rm -rf "$ICONSET_DIR" "$BASE_PNG"
mkdir -p "$ICONSET_DIR"

python3 - "$BASE_PNG" <<'PYEOF'
import math, struct, sys, zlib

out_path = sys.argv[1]
W = H = 1024

def clamp(v, lo=0, hi=255):
    return lo if v < lo else (hi if v > hi else int(v))

rows = []
cx, cy = W / 2.0, H / 2.0
radius = 210.0
margin = 64.0

for y in range(H):
    row = bytearray()
    row.append(0)  # PNG filter type 0
    ny = (y - cy) / (H / 2.0)
    for x in range(W):
        nx = (x - cx) / (W / 2.0)
        # Rounded-rect signed distance
        qx = abs(x - cx) - (W / 2.0 - margin - radius)
        qy = abs(y - cy) - (H / 2.0 - margin - radius)
        dx = max(qx, 0.0)
        dy = max(qy, 0.0)
        dist = math.hypot(dx, dy) + min(max(qx, qy), 0.0) - radius

        if dist > 1.5:
            row.extend((0, 0, 0, 0))
            continue

        alpha = 255 if dist < -1.5 else clamp((1.5 - dist) / 3.0 * 255)

        # Deep navy-slate gradient background
        t = (x * 0.4 + y * 0.6) / W
        r = 12 + 16 * t
        g = 24 + 30 * t
        b = 46 + 44 * t

        # Subtle inner glow
        glow = max(0.0, 1.0 - math.hypot(nx, ny) * 0.95)
        r += 10 * glow
        g += 38 * glow
        b += 45 * glow

        # Subtle grid lines
        if (x % 96 < 2 or y % 96 < 2) and abs(x - cx) < 380 and abs(y - cy) < 380:
            r += 14
            g += 28
            b += 42

        # Power dispatch / UC staircase + smooth wind wave
        # Emerald wave: y_wave around center
        if 150 <= x <= 874:
            u = (x - 150) / 724.0
            # Smooth renewable curve (cyan/emerald)
            y_wave = 520.0 - 150.0 * math.sin(u * math.pi * 2.0 - 0.5) - 50.0 * math.cos(u * math.pi * 4.0)
            dw = abs(y - y_wave)
            if dw < 18.0:
                blend = max(0.0, 1.0 - dw / 18.0)
                r = r * (1 - blend) + 16 * blend
                g = g * (1 - blend) + 215 * blend
                b = b * (1 - blend) + 160 * blend

            # Unit commitment step blocks (warm amber bars at bottom)
            step_idx = int(u * 6)
            step_heights = [0.22, 0.34, 0.48, 0.52, 0.38, 0.28]
            bar_top = 820.0 - step_heights[min(step_idx, 5)] * 420.0
            bar_local_x = (u * 6) - step_idx
            if 0.14 <= bar_local_x <= 0.86 and bar_top <= y <= 820.0:
                if y < bar_top + 10.0:
                    r, g, b = 250, 204, 21
                else:
                    r = r * 0.45 + 245 * 0.55
                    g = g * 0.45 + 158 * 0.55
                    b = b * 0.45 + 11 * 0.55

        # Crisp border highlight
        if -10.0 <= dist <= -2.0:
            r += 40
            g += 95
            b += 110

        row.extend((clamp(r), clamp(g), clamp(b), alpha))
    rows.append(bytes(row))

raw = b"".join(rows)

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
with open(out_path, "wb") as f:
    f.write(png)
PYEOF

for sz in 16 32 128 256 512; do
    sips -z $sz $sz "$BASE_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
    sz2=$((sz * 2))
    sips -z $sz2 $sz2 "$BASE_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR" "$BASE_PNG"

# 3. Create Info.plist
echo "[3/5] Writing Info.plist and macOS launcher..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 4. Create the native launcher executable
cat > "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ModuleUnitCommitmentToolkit"
MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$(cd "$MACOS_DIR/../Resources" && pwd)"
BUNDLED_PROJECT="$RESOURCES_DIR/project"
BUILD_STAMP_FILE="$RESOURCES_DIR/BUILD_STAMP"
BUILD_STAMP="$(cat "$BUILD_STAMP_FILE" 2>/dev/null || echo "0.1.0")"

# Enrich PATH for Finder-launched apps (juliaup, Homebrew, standard Python/Julia)
EXTRA_PATHS=(
  "$HOME/.juliaup/bin"
  "/opt/homebrew/bin"
  "/usr/local/bin"
  "/Library/Frameworks/Python.framework/Versions/Current/bin"
)
for japp in /Applications/Julia-*.app/Contents/Resources/julia/bin; do
  [ -d "$japp" ] && EXTRA_PATHS+=("$japp")
done
for p in "${EXTRA_PATHS[@]}"; do
  if [ -d "$p" ] && [[ ":$PATH:" != *":$p:"* ]]; then
    export PATH="$p:$PATH"
  fi
done

alert_error() {
  local msg="$1"
  /usr/bin/osascript -e "display dialog \"$msg\" with title \"$APP_NAME\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

PYTHON_BIN="$(command -v python3 || true)"
if [ -z "$PYTHON_BIN" ]; then
  alert_error "未找到 Python 3（python3）。请先安装 Python 3（例如通过 Homebrew: brew install python）后再启动。"
fi

# Writable user workspace & output directories (works even when launched directly from read-only DMG or App Translocation)
APP_SUPPORT="$HOME/Library/Application Support/${APP_NAME}"
WORKSPACE="$APP_SUPPORT/workspace"
OUTPUT_DIR="$HOME/Documents/${APP_NAME}_Output"
LOG_DIR="$OUTPUT_DIR/logs"
PID_FILE="$APP_SUPPORT/gui_server.pid"
PORT_FILE="$APP_SUPPORT/gui_server.port"

mkdir -p "$APP_SUPPORT" "$OUTPUT_DIR" "$LOG_DIR"

INSTALLED_STAMP=""
[ -f "$APP_SUPPORT/INSTALLED_STAMP" ] && INSTALLED_STAMP="$(cat "$APP_SUPPORT/INSTALLED_STAMP")"

if [ "$INSTALLED_STAMP" != "$BUILD_STAMP" ] || [ ! -f "$WORKSPACE/gui/server.py" ]; then
  mkdir -p "$WORKSPACE"
  # Preserve user-edited runtime_config.toml across app upgrades
  if [ -f "$WORKSPACE/config/runtime_config.toml" ]; then
    cp "$WORKSPACE/config/runtime_config.toml" "$APP_SUPPORT/runtime_config.toml.bak"
  fi
  rsync -a --delete --exclude 'output' "$BUNDLED_PROJECT/" "$WORKSPACE/"
  if [ -f "$APP_SUPPORT/runtime_config.toml.bak" ]; then
    mv "$APP_SUPPORT/runtime_config.toml.bak" "$WORKSPACE/config/runtime_config.toml"
  fi
  printf '%s\n' "$BUILD_STAMP" > "$APP_SUPPORT/INSTALLED_STAMP"
fi

# Link workspace/output -> ~/Documents/ModuleUnitCommitmentToolkit_Output
if [ ! -L "$WORKSPACE/output" ]; then
  rm -rf "$WORKSPACE/output"
  ln -s "$OUTPUT_DIR" "$WORKSPACE/output"
fi

# Reuse already-running GUI server if alive
if [ -f "$PID_FILE" ] && [ -f "$PORT_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  OLD_PORT="$(cat "$PORT_FILE" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null && [ -n "$OLD_PORT" ]; then
    open "http://127.0.0.1:${OLD_PORT}/gui/"
    exit 0
  fi
fi

# Pick a free localhost port in 8080..8099
PORT="$("$PYTHON_BIN" -c '
import socket
for p in range(8080, 8100):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex(("127.0.0.1", p)) != 0:
            print(p)
            break
')"
if [ -z "$PORT" ]; then
  alert_error "端口 8080–8099 均已被占用，请释放一个端口后重试。"
fi

SERVER_LOG="$LOG_DIR/gui_server.log"
export MODULE_UC_GUI_HOST="127.0.0.1"
export MODULE_UC_GUI_PORT="$PORT"
export MODULE_UC_OUTPUT_DIR="$OUTPUT_DIR"

cd "$WORKSPACE"
nohup "$PYTHON_BIN" "$WORKSPACE/gui/server.py" >> "$SERVER_LOG" 2>&1 </dev/null &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"
echo "$PORT" > "$PORT_FILE"

# Wait up to 8 seconds for server readiness
READY=0
for _ in $(seq 1 40); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    break
  fi
  if "$PYTHON_BIN" -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT}/gui/', timeout=1)" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 0.2
done

if [ "$READY" -ne 1 ]; then
  alert_error "GUI 服务启动失败，请查看日志：$SERVER_LOG"
fi

open "http://127.0.0.1:${PORT}/gui/"
exit 0
LAUNCHER
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Ad-hoc codesign so macOS accepts the local bundle structure cleanly
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

# 5. Prepare DMG staging folder (Applications symlink + README)
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/README_MACOS.txt" <<README
========================================================================
ModuleUnitCommitmentToolkit v${VERSION} (macOS)
========================================================================

【快速安装与使用 / Quick Start】
1. 将 ModuleUnitCommitmentToolkit.app 拖入右侧 Applications 文件夹
   （也可直接双击运行）。
2. 首次打开若 macOS 提示“无法验证开发者”，请右键点击应用 -> 选择“打开”
   -> 点击“仍要打开”。
3. 启动后会自动在后台运行本地 GUI 服务，并在浏览器打开：
   http://127.0.0.1:8080/gui/

【运行环境说明 / Requirements】
- 本安装包为轻量级封装，运行时调用本机已安装的 Python 3 与 Julia 环境。
- 首次运行优化求解前，若目标机器尚未安装 Julia 依赖，请在终端执行：
    cd "\$HOME/Library/Application Support/ModuleUnitCommitmentToolkit/workspace"
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
- 若使用 Gurobi 求解器，需本机已配置有效 Gurobi License；否则可切换 GLPK。

【结果与日志位置 / Outputs & Logs】
- 所有求解结果、图表与运行日志均保存在：
    ~/Documents/ModuleUnitCommitmentToolkit_Output/
- GUI 服务日志：
    ~/Documents/ModuleUnitCommitmentToolkit_Output/logs/gui_server.log

【停止后台 GUI 服务 / Stop Background Server】
- 在终端执行：
    kill "\$(cat "\$HOME/Library/Application Support/ModuleUnitCommitmentToolkit/gui_server.pid")"
README

echo "[4/5] Packing compressed DMG (${DMG_NAME})..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

echo "[5/5] Verifying DMG integrity..."
hdiutil verify "$DMG_PATH"

rm -rf "$STAGE_DIR"
echo ""
echo "=== Build Complete ==="
ls -lh "$DMG_PATH"
