@echo off
setlocal enabledelayedexpansion
REM Batch script to open Cursor for multiple repositories
REM Enforce non-administrator execution

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ERROR: This script must NOT be run as administrator!
    echo Please run this script as a regular user.
    echo.
    pause
    exit /b 1
)
REM Define the list of repository paths
set REPOS=^
C:\Users\Ernest\Raid\Qualifly\qfly-end-db ^
C:\Users\Ernest\Raid\Qualifly\qfly-end-web-service ^
C:\Users\Ernest\Raid\Qualifly\qfly-end-training-service

echo Opening Cursor for the following repositories:
echo.

REM Loop through each repository and perform git operations
for %%r in (%REPOS%) do (
    echo.
    echo ========================================
    echo Processing: %%r
    echo ========================================
    
    REM Check if directory exists first
    if exist "%%r" (
        
          REM Open Cursor in this directory first
          echo Opening Cursor in: %%r
          start /B "" cursor "%%r"
        
        
        @REM REM Verify it's a git repo and do git operations
        @REM if exist ".git" (
        @REM     REM Get current branch name
        @REM     echo Getting current branch...
        @REM     for /f "tokens=*" %%b in ('git branch --show-current 2^>nul') do set currentBranch=%%b
        @REM     if not "!currentBranch!"=="" (
        @REM         echo Current branch: !currentBranch!
                
        @REM         REM Pull latest changes on current branch
        @REM         echo Pulling latest changes on current branch...
        @REM         git pull
        @REM         if %errorLevel% equ 0 (
        @REM             echo Successfully pulled latest changes
        @REM         ) else (
        @REM             echo WARNING: git pull failed
        @REM         )
        @REM     ) else (
        @REM         echo WARNING: No current branch found or git command failed
        @REM     )
        @REM ) else (
        @REM     echo WARNING: Not a git repository - skipping git operations
        @REM )
    ) else (
        echo ERROR: Failed to change to directory %%r
    )
    
    REM Add a small delay to prevent overwhelming the system
    timeout /t 2 /nobreak >nul
)

echo.
echo All repositories have been opened in Cursor.
pause
