@echo off
title Cursor Rotator - Update
cd /d "%TEMP%"
echo.
echo  Checking GitHub for a newer version of Cursor Rotator...
echo  Your cursor packs and settings are never touched.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -Update
pause
