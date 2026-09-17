@echo off
setlocal

REM AVA 01610 Neuro-HH - local, non-admin, no network scan, no persistence.
REM Every run creates a new immutable evidence directory under AVA_EVENTS.

cd /d "%~dp0\.."

where node >nul 2>&1
if errorlevel 1 (
    echo [STOP] Node.js was not found in PATH.
    exit /b 1
)

echo [1/2] Running the isolated AVA Neuro-HH test suite...
call node test\neuro-hh.test.js
if errorlevel 1 (
    echo [STOP] Neuro-HH tests failed. No simulation evidence was created.
    exit /b 1
)

echo [2/2] Running the BAC-like coincidence protocol...
call node bin\cli.js --neuro-hh --protocol bac-coincidence --output "%CD%\AVA_EVENTS"
if errorlevel 1 (
    echo [STOP] Neuro-HH simulation failed.
    exit /b 1
)

echo [OK] AVA Neuro-HH completed. Evidence is under:
echo      %CD%\AVA_EVENTS
exit /b 0

