@echo off
REM DEX DASH - one-click installer for Windows.
REM Downloads the latest release build from GitHub into build\dex-dash-win64\,
REM then start.bat can launch the game.

setlocal
cd /d "%~dp0"

set "DEST=build\dex-dash-win64"
set "BASE=https://github.com/Dex-Dete/dex-dash/releases/latest/download"

echo DEX DASH installer
echo Downloads the latest release build from GitHub.
echo.

where powershell >nul 2>nul
if errorlevel 1 goto :no_powershell

if not exist "%DEST%" mkdir "%DEST%"

echo Downloading dex-dash.exe ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%BASE%/dex-dash.exe' -OutFile '%DEST%\dex-dash.exe'"
if errorlevel 1 goto :download_failed

echo Downloading dex-dash.pck ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%BASE%/dex-dash.pck' -OutFile '%DEST%\dex-dash.pck'"
if errorlevel 1 goto :download_failed

set "EXE_SIZE=0"
for %%f in ("%DEST%\dex-dash.exe") do set "EXE_SIZE=%%~zf"
for %%f in ("%DEST%\dex-dash.pck") do set "PCK_SIZE=%%~zf"

if %EXE_SIZE% LSS 1000000 goto :bad_exe
if %PCK_SIZE% LSS 1000000 goto :bad_pck
goto :done

:no_powershell
echo ERROR: PowerShell was not found - cannot download the build.
goto :fail

:bad_exe
echo ERROR: Downloaded dex-dash.exe looks too small - download failed?
goto :fail

:bad_pck
echo ERROR: Downloaded dex-dash.pck looks too small - download failed?
goto :fail

:download_failed
echo ERROR: Download failed. Check your internet connection and try again.
goto :fail

:done
echo.
echo Install complete: %DEST% - exe %EXE_SIZE% bytes, pck %PCK_SIZE% bytes
echo Run start.bat to launch the game.
echo.
pause
exit /b 0

:fail
echo.
pause
exit /b 1
