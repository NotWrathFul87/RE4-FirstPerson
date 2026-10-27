@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop.ps1"
echo Press any key to close this window.
pause >nul
