@echo off
title Extract Cursor Packs
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Extract-Packs.ps1"
pause
