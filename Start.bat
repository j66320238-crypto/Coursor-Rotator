@echo off
title Cursor Rotator
cd /d "%TEMP%"
echo Starting Cursor Rotator...
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CursorRotator.ps1" -Silent -NoBrowser
rem give the local control panel a moment to come up, then open it in the browser
ping -n 4 127.0.0.1 >nul
start "" http://127.0.0.1:8777/
exit
