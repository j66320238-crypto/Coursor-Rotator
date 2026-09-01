<#
    Build-Release.ps1
    Creates MANIFEST.txt (file list + sizes + SHA-256) and packs a clean
    release zip into release\CursorRotator-<version>.zip
#>
param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rel  = Join-Path $root 'release'
if (-not (Test-Path $rel)) { New-Item -ItemType Directory -Path $rel | Out-Null }

# always embed the current UI first
& (Join-Path $PSScriptRoot 'Embed-Ui.ps1')

$skip = @('.git', '.github', 'release', 'Tools', 'node_modules')
$files = Get-ChildItem -Path $root -Recurse -File | Where-Object {
    $rp = $_.FullName.Substring($root.Length).TrimStart('\')
    $top = ($rp -split '\\')[0]
    ($skip -notcontains $top) -and ($_.Name -ne 'MANIFEST.txt') -and
    ($_.Extension -notin @('.zip', '.rar', '.7z', '.cur', '.ani'))
} | Sort-Object FullName

$lines = @()
$lines += "CURSOR ROTATOR $Version - PACKAGE MANIFEST"
$lines += "Built: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
$lines += ''
$lines += 'Compare this list with what you have if you suspect a file is missing or damaged.'
$lines += ''
$lines += ('{0,-44} {1,10}  {2}' -f 'FILE', 'BYTES', 'SHA-256')
$lines += ('-' * 80)
$total = 0
foreach ($f in $files) {
    $rp = $f.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
    $h  = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.Substring(0, 16).ToLower()
    $lines += ('{0,-44} {1,10}  {2}' -f $rp, $f.Length, $h)
    $total += $f.Length
}
$lines += ('-' * 80)
$lines += ('{0,-44} {1,10}  ({2} files)' -f 'TOTAL', $total, $files.Count)
$lines += ''
$lines += 'The Packs and Data folders start out empty by design - they fill up when you add zips'
$lines += 'or download packs from the store. Nothing is missing.'
[System.IO.File]::WriteAllLines((Join-Path $root 'MANIFEST.txt'), $lines)

$zip = Join-Path $rel "CursorRotator-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip }
$stage = Join-Path $env:TEMP ("cr-stage-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $stage 'CursorRotator') | Out-Null
foreach ($f in @($files) + @(Get-Item (Join-Path $root 'MANIFEST.txt'))) {
    $rp = $f.FullName.Substring($root.Length).TrimStart('\')
    $dest = Join-Path (Join-Path $stage 'CursorRotator') $rp
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item $f.FullName $dest
}
Compress-Archive -Path (Join-Path $stage 'CursorRotator') -DestinationPath $zip
Remove-Item -Recurse -Force $stage
Write-Host ("Release built: {0} ({1:N0} bytes)" -f $zip, (Get-Item $zip).Length) -ForegroundColor Green
