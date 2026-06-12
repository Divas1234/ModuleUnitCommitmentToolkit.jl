@echo off
setlocal

set "DIR=%~dp0"
for %%I in ("%DIR%\..") do set "PROJECT=%%~fI"

echo === Unit Commitment Dashboard ===
echo Starting server at http://localhost:8080/gui/
echo Press Ctrl+C to stop.
echo.

cd /d "%PROJECT%" || exit /b 1
python gui\server.py

