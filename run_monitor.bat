@echo off
echo ========================================
echo System Update Monitor
echo ========================================
echo.
echo This script will continuously monitor your system for updates.
echo It checks every hour for:
echo   - Windows Defender virus definition updates
echo   - Windows system updates
echo.
echo If updates are found, it will automatically run the update script.
echo.
echo Press Ctrl+C to stop monitoring at any time.
echo.
echo Checking for administrator privileges...

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator privileges confirmed.
    echo.
    echo Starting update monitor...
    echo.
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0monitor_updates.ps1"
) else (
    echo This script requires administrator privileges.
    echo Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

