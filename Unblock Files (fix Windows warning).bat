@echo off
title Cursor Rotator - remove the Windows security warning
cd /d "%TEMP%"
echo.
echo  Windows adds a "downloaded from the internet" mark to every file that comes
echo  out of a downloaded ZIP. That is why you saw:
echo.
echo      "The publisher could not be verified. Are you sure you want to run..."
echo.
echo  This removes that mark from the Cursor Rotator folder. Nothing else changes.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -Unblock
pause
