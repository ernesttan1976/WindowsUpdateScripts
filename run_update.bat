@echo off
echo Running update script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0update.ps1"
echo.
echo Script execution completed. Press any key to close this window...
pause >nul