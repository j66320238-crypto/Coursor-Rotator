# =====================================================================
#  Download-Cursors.ps1  -  standalone cursor pack downloader
#  Part of Cursor Rotator. Downloads free cursor packs from GitHub
#  straight into the Packs folder, unpacks them and you are done.
#
#  Examples:
#     .\Download-Cursors.ps1                  (interactive menu)
#     .\Download-Cursors.ps1 -All             (download everything)
#     .\Download-Cursors.ps1 -Tag RGB         (only RGB / rainbow packs)
#     .\Download-Cursors.ps1 -Tag Animated
#     .\Download-Cursors.ps1 -Id bibata-rainbow-modern,pokemon
#     .\Download-Cursors.ps1 -ListOnly
# =====================================================================
param(
    [switch]$All,
    [string]$Tag = '',
    [string[]]$Id = @(),
    [switch]$ListOnly,
    [switch]$Quiet
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$Main = Join-Path $Root 'CursorRotator.ps1'
$PacksDir = Join-Path $Root 'Packs'
if (-not [System.IO.Directory]::Exists($PacksDir)) { [System.IO.Directory]::CreateDirectory($PacksDir) | Out-Null }

try { Set-Location -LiteralPath $env:TEMP } catch { }

if (-not [System.IO.File]::Exists($Main)) {
    Write-Host "CursorRotator.ps1 not found next to this script. Keep both files in the same folder." -ForegroundColor Red
    if (-not $Quiet) { Read-Host 'Press Enter to close' }
    return
}

function Show-Header {
    Write-Host ''
    Write-Host '  ==================================================' -ForegroundColor Cyan
    Write-Host '   CURSOR PACK DOWNLOADER  -  free packs from GitHub' -ForegroundColor Cyan
    Write-Host '  ==================================================' -ForegroundColor Cyan
    Write-Host ''
}

# --- interactive menu when no switch was given -------------------------
if (-not $All -and -not $Tag -and $Id.Count -eq 0 -and -not $ListOnly) {
    Show-Header
    & $Main -Download tags -Silent
    Write-Host '  What do you want to download?'
    Write-Host ''
    Write-Host '   1  Everything (all packs, biggest download)'
    Write-Host '   2  RGB / rainbow packs only'
    Write-Host '   3  Animated packs only'
    Write-Host '   4  Anime / character packs only'
    Write-Host '   5  Minimal packs only (Bibata, GoogleDot, macOS...)'
    Write-Host '   6  Show the full list first'
    Write-Host '   0  Cancel'
    Write-Host ''
    $c = Read-Host '  Your choice'
    switch ($c) {
        '1' { $All = $true }
        '2' { $Tag = 'RGB' }
        '3' { $Tag = 'Animated' }
        '4' { $Tag = 'Anime' }
        '5' { $Tag = 'Minimal' }
        '6' { $ListOnly = $true }
        default { Write-Host '  Cancelled.'; return }
    }
}

Show-Header

if ($ListOnly) {
    & $Main -Download list -Tag $Tag -Silent
    if (-not $Quiet) { Read-Host '  Press Enter to close' }
    return
}

if ($Id.Count -gt 0) {
    foreach ($one in $Id) {
        Write-Host ("  Downloading {0} ..." -f $one)
        & $Main -Download $one -Silent -NoBrowser
    }
} else {
    & $Main -DownloadAll -Tag $Tag -Silent -NoBrowser
}

Write-Host ''
Write-Host '  Done. Start the app (Start.bat) and your new packs are in the rotation.' -ForegroundColor Green
Write-Host ''
if (-not $Quiet) { Read-Host '  Press Enter to close' }
