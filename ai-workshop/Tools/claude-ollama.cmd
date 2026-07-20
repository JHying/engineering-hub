@echo off
REM claude-ollama.cmd — double-clickable launcher for claude-ollama.ps1
REM Runs the PowerShell script in this same folder, then keeps the window
REM open so any error message or the interactive model prompt stays visible.

setlocal
set "SCRIPT_DIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%claude-ollama.ps1" %*

echo.
pause
endlocal
