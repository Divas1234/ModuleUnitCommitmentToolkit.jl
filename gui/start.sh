#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$DIR/.." && pwd)"

echo "=== Unit Commitment Dashboard ==="
echo "Starting server at http://localhost:8080/gui/"
echo "Remote deployment requires MODULE_UC_GUI_ALLOW_REMOTE=1, MODULE_UC_GUI_TOKEN, and MODULE_UC_GUI_ALLOWED_ORIGINS."
echo "Press Ctrl+C to stop."
echo ""

cd "$PROJECT"
if command -v python3 >/dev/null 2>&1; then
  python3 gui/server.py
else
  python gui/server.py
fi
