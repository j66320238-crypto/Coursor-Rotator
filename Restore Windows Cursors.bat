@echo off
title Restore Windows Cursors
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='HKCU:\Control Panel\Cursors'; $b='%~dp0Data\original-scheme.json'; if(Test-Path $b){$j=Get-Content $b -Raw|ConvertFrom-Json; $j.PSObject.Properties|Where-Object{$_.Name -ne '__Default'}|ForEach-Object{Set-ItemProperty $p -Name $_.Name -Value $_.Value -Type ExpandString -Force}}; Set-ItemProperty $p -Name '(default)' -Value 'Windows Default' -Force; Add-Type -Namespace W -Name U -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d);'; [W.U]::SystemParametersInfo(0x57,0,[IntPtr]::Zero,3) | Out-Null; Write-Host 'Windows default cursors restored.'"
timeout /t 3 >nul
