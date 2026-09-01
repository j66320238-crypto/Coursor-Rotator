@echo off
title Cursor Rotator - Custom pack builder
cd /d "%TEMP%"
start "" http://127.0.0.1:8777/
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CursorRotator.ps1" -NoBrowser
