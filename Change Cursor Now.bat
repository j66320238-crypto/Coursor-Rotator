@echo off
title Change Cursor Now
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -Random -Silent -NoBrowser
timeout /t 2 >nul
