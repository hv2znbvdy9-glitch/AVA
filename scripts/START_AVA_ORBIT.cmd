@echo off
setlocal
cd /d "%~dp0.."
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js fehlt. Bitte Node.js LTS von https://nodejs.org installieren.
  pause
  exit /b 1
)
echo AVA Orbit - ohne Administratorrechte
echo Browser nach dem Start oeffnen: http://127.0.0.1:4173
node src\orbit-server.js
set "AVA_EXIT=%ERRORLEVEL%"
if not "%AVA_EXIT%"=="0" pause
exit /b %AVA_EXIT%
