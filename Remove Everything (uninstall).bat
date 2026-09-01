@echo off
title Cursor Rotator - Remove Everything
cd /d "%TEMP%"
echo.
echo  This puts Windows back the way it was:
echo    - your original mouse cursors are restored
echo    - the Start-with-Windows entry is removed
echo    - the app settings are deleted
echo.
echo  Your cursor packs are KEPT unless you answer Y below.
echo.
set /p DEL=Also delete every downloaded cursor pack? (Y/N):
if /i "%DEL%"=="Y" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -RemoveAll -DeletePacks
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorRotator.ps1" -RemoveAll
)
echo.
echo  Finished. You can delete this folder now if you want.
pause
