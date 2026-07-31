@echo off
REM DEX DASH - one-click launcher for Windows.
REM Runs the prebuilt game if a release build exists, otherwise starts the
REM project from source with Godot if it is on your PATH.

setlocal
cd /d "%~dp0"

set "GAME=build\dex-dash-win64\dex-dash.exe"

if exist "%GAME%" (
    echo Launching DEX DASH...
    start "" "%GAME%"
    exit /b 0
)

where godot >nul 2>nul
if %errorlevel%==0 (
    echo No build found - starting project from source with Godot...
    godot --path .
    exit /b %errorlevel%
)

echo.
echo ERROR: Could not find a game build and Godot is not on PATH.
echo.
echo   - Download the latest build from the GitHub Releases page, or
echo   - Install Godot 4.7.1 and add it to PATH, or
echo   - Run:  node tools\gen-all.js  then  godot --path .
echo.
pause
exit /b 1
