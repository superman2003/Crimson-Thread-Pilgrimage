@echo off
cd /d "%~dp0"
if "%~1"=="" (
  python tools\apply_global_font.py apply
) else (
  python tools\apply_global_font.py apply --font "%~1"
)
echo.
pause
