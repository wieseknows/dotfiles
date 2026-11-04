@echo off
setlocal enabledelayedexpansion
title Dotfiles Installer
echo ==================================================
echo  Starting Dotfiles Installation...
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

"!GIT_BASH!" "%~dp0install.sh"
