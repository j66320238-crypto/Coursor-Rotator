@echo off
title Cursor Packs
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -List -Silent -NoBrowser
pause
