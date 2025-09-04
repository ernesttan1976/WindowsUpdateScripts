@echo off
REM Create scheduled task for GlobalProtect updates

schtasks /create /tn "GlobalProtect Auto Update" ^
/tr "powershell.exe -ExecutionPolicy Bypass -File C:\Users\Ernest\Scripts\update.ps1" ^
/sc daily /st 04:30 /ru SYSTEM /rl HIGHEST /f

echo Scheduled task created successfully
echo The script will run daily at 4:30 AM
pause