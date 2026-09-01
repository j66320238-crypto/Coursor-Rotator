# Standalone auto-extractor: unzips everything in \Packs into \Cursors
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Root   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Packs  = Join-Path $Root 'Packs'
$Out    = Join-Path $Root 'Cursors'
foreach ($d in @($Packs,$Out)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory $d -Force | Out-Null } }

$archives = Get-ChildItem -LiteralPath $Packs -File -Recurse | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' }
if (-not $archives) { Write-Host "No archives found in $Packs" -ForegroundColor Yellow; return }
$tools = @("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe","$env:ProgramFiles\WinRAR\WinRAR.exe","${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe") | Where-Object { Test-Path -LiteralPath $_ }

foreach ($a in $archives) {
    $target = Join-Path $Out ([IO.Path]::GetFileNameWithoutExtension($a.Name))
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory $target -Force | Out-Null }
    Write-Host "Extracting $($a.Name) ..." -NoNewline
    $ok = $false
    if ($a.Extension -eq '.zip') {
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($a.FullName)
            foreach ($e in $z.Entries) {
                if (-not $e.Name) { continue }
                $dest = Join-Path $target $e.FullName
                $dd = Split-Path $dest -Parent
                if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory $dd -Force | Out-Null }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e,$dest,$true)
            }
            $z.Dispose(); $ok = $true
        } catch { }
    }
    if (-not $ok -and $tools) {
        $t = $tools[0]
        if ($t -like '*7z.exe') { & $t x "$($a.FullName)" "-o$target" -y | Out-Null } else { & $t x -ibck -y "$($a.FullName)" "$target\" | Out-Null }
        $ok = $true
    }
    if ($ok) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED (install 7-Zip for .rar/.7z)" -ForegroundColor Red }
}
$c = (Get-ChildItem -LiteralPath $Out -Recurse -File | Where-Object { $_.Extension -match '^\.(cur|ani)$' }).Count
Write-Host "`nDone. $c cursor files available in $Out" -ForegroundColor Cyan
