@echo off
setlocal enabledelayedexpansion
title Dotfiles Installer

if /I "%~1"=="--cli" (
    shift
    goto :cli_mode
)

where powershell.exe >nul 2>&1
if %ERRORLEVEL%==0 (
    echo Launching Dotfiles GUI Setup Wizard...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0install-gui.ps1"
    if %ERRORLEVEL%==0 exit /b 0
    echo [WARN] GUI installer exited with code %ERRORLEVEL%. Falling back to CLI mode...
)

:cli_mode
echo ==================================================
echo  Starting Dotfiles Installation (CLI)...
echo ==================================================

set "GIT_BASH="
if exist "C:\Program Files\Git\bin\bash.exe" set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
if not defined GIT_BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined GIT_BASH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"

if not defined GIT_BASH (
    for /f "delims=" %%I in ('where git.exe 2^>nul') do (
        set "GIT_DIR=%%~dpI.."
        if exist "!GIT_DIR!\bin\bash.exe" set "GIT_BASH=!GIT_DIR!\bin\bash.exe"
        if exist "!GIT_DIR!\usr\bin\bash.exe" set "GIT_BASH=!GIT_DIR!\usr\bin\bash.exe"
    )
)

if not defined GIT_BASH (
    echo [ERROR] Git Bash was not found on your system!
    echo Please install Git for Windows: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

set "PAUSE_ON_EXIT=1"
"!GIT_BASH!" "%~dp0install.sh" %1 %2 %3 %4 %5
