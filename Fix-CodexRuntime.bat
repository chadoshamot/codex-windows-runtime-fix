@echo off
setlocal

title Codex Windows Runtime Repair

echo.
echo ================================================
echo       Codex Windows Runtime Repair
echo ================================================
echo.

REM Locate the PowerShell script next to this BAT file.
set "SCRIPT=%~dp0Fix-CodexRuntime.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: Fix-CodexRuntime.ps1 was not found.
    echo.
    pause
    exit /b 1
)

REM -------------------------------------------------
REM Check administrator privileges.
REM -------------------------------------------------

net session >nul 2>&1

if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    echo.

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"

    exit /b
)

REM -------------------------------------------------
REM Run repair script.
REM -------------------------------------------------

powershell.exe ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -File "%SCRIPT%"

set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" (
    echo.
    echo ================================================
    echo                 REPAIR FAILED
    echo ================================================
    echo.
    echo You can copy the error shown above when opening
    echo a GitHub issue. Check the output for personal
    echo information before posting it publicly.
    echo.
    pause
    exit /b %RESULT%
)

echo.
echo Repair completed successfully.
timeout /t 2 /nobreak >nul

exit /b 0