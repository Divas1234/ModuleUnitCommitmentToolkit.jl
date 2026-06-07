#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$DIR/.." && pwd)"

echo "=== Unit Commitment Dashboard ==="
echo "Starting server at http://localhost:8080/gui/"
echo "Press Ctrl+C to stop."
echo ""

cd "$PROJECT" && python3 gui/server.py
