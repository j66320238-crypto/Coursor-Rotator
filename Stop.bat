@echo off
title Stop Cursor Rotator
echo Stopping Cursor Rotator...

rem 1) polite shutdown through the local API (ports 8777-8781)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "1..5 | ForEach-Object { $p=8776+$_; try { Invoke-WebRequest -Uri ('http://127.0.0.1:{0}/api/exit' -f $p) -UseBasicParsing -TimeoutSec 2 | Out-Null } catch {} }"

timeout /t 2 >nul

rem 2) force kill anything still running the script
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*CursorRotator.ps1*' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }"

echo.
echo Cursor Rotator stopped. You can now move, replace or delete the folder.
timeout /t 3 >nul
