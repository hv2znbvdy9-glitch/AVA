@echo off
title AVA SAFE AUDIT - Admin Starter
cd /d "%~dp0"

echo AVA SAFE AUDIT startet...
echo Modus: Read-only / keine Systemaenderungen
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AVA_SAFE_AUDIT_CHAT_MODE_v1.ps1" -OpenReport

echo.
echo Fertig. Taste druecken zum Schliessen.
pause >nul
