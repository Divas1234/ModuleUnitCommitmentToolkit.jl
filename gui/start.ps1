$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Resolve-Path (Join-Path $dir "..")

Write-Host "=== Unit Commitment Dashboard ==="
Write-Host "Starting server at http://localhost:8080/gui/"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

Set-Location $project
python gui/server.py

