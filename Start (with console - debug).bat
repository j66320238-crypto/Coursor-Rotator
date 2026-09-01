@echo off
title Cursor Rotator - debug console
cd /d "%TEMP%"
echo Starting Cursor Rotator with a visible console.
echo Close this window to stop the app.
echo.
start "" http://127.0.0.1:8777/
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -NoBrowser
pause
