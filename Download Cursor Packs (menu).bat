@echo off
title Cursor Rotator - Download Cursor Packs
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Download-Cursors.ps1"
