@echo off
REM AVA Laptop Setup Script for Windows - Run as Administrator
REM Right-click Command Prompt and select "Run as administrator"

echo.
echo ========================================
echo AVA Laptop Setup Started...
echo ========================================
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo WARNING: This script must be run as Administrator!
    echo Please right-click Command Prompt and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo [OK] Running with Administrator privileges
echo.

REM Navigate to repo
cd /d %~dp0
cd ..\..

echo Working directory: %cd%
echo.

REM Install dependencies
echo [*] Installing dependencies...
call npm install
if %errorLevel% neq 0 (
    echo ERROR: npm install failed
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Run tests
echo [*] Running AVA Tests...
call npm test
echo.

REM Run AVA CLI
echo [*] Running AVA CLI...
call npx ava "echo AVA is running on your Laptop - ALL SYSTEMS GO!"
echo.

REM Run Safe Local Node
echo [*] Running AVA Safe Local Node...
call npx ava --safe-local-node
echo.

echo.
echo ========================================
echo AVA Laptop Setup Complete!
echo ========================================
echo.
echo Next steps:
echo   1. AVA is ready to run on your laptop
echo   2. Use: npm test
echo   3. Use: npx ava "your-command"
echo.
pause
