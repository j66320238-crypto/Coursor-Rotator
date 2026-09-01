@echo off
title Cursor Rotator
rem run from TEMP so this folder never gets locked by the app
start "" /d "%TEMP%" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CursorRotator.ps1"
exit
