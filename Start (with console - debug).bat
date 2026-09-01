@echo off
title Cursor Rotator (debug)
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -NoBrowser
echo.
echo Cursor Rotator has exited. See Data\log.txt for details.
pause
