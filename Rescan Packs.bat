@echo off
title Rescan Cursor Packs
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -Rescan -NoBrowser
pause
