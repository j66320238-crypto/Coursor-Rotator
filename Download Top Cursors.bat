@echo off
title Download Top Cursor Packs
cd /d "%TEMP%"
echo ============================================================
echo   Downloading the best free cursor packs from GitHub
echo   (Bibata, GoogleDot, macOS - about 60 MB total)
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -DownloadAll -NoBrowser
echo.
pause
