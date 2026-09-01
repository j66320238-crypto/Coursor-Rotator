@echo off
title Unlock CursorRotator folder
echo ============================================================
echo  Unlocking the CursorRotator folder
echo ============================================================
echo.
echo [1/4] Asking the app to exit...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "1..5 | ForEach-Object { $p=8776+$_; try { Invoke-WebRequest -Uri ('http://127.0.0.1:{0}/api/exit' -f $p) -UseBasicParsing -TimeoutSec 2 | Out-Null } catch {} }"
timeout /t 2 >nul

echo [2/4] Killing any leftover Cursor Rotator process...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*CursorRotator.ps1*' } | ForEach-Object { Write-Host ('   killing PID ' + $_.ProcessId); try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }"

echo [3/4] Closing Explorer windows that have this folder open...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$t='%~dp0'.TrimEnd('\'); try { $sh=New-Object -ComObject Shell.Application; @($sh.Windows()) | ForEach-Object { try { $p=$_.Document.Folder.Self.Path; if ($p -and $p -like ($t + '*')) { $_.Quit() } } catch {} } } catch {}"

echo [4/4] Done.
echo.
echo The folder is free now. You can replace / delete / move it.
echo Tip: also close Notepad if you opened Data\log.txt.
echo.
pause
