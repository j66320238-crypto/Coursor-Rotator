@echo off
title Cursor Rotator - RGB and Animated packs
cd /d "%TEMP%"
echo Downloading RGB / rainbow packs ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Download-Cursors.ps1" -Tag RGB -Quiet
echo.
echo Downloading animated packs ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Download-Cursors.ps1" -Tag Animated -Quiet
echo.
pause
