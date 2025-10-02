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
REM Check if repos.txt file exists
set REPOS_FILE=%~dp0repos.txt
if not exist "%REPOS_FILE%" (
    echo ERROR: repos.txt file not found at: %REPOS_FILE%
    echo Please create a repos.txt file with one repository path per line.
    echo.
    pause
    exit /b 1
)

echo Opening Cursor for repositories listed in: %REPOS_FILE%
echo.

REM Loop through each repository path from the file
for /f "usebackq delims=" %%r in ("%REPOS_FILE%") do (
    REM Skip empty lines
    if "%%r"=="" continue
    
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
