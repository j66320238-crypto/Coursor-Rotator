# ============================================================
#  Cursor Rotator 2.0  -  Random Windows Cursor Scheme Changer
#  Works on Windows PowerShell 5.1 and PowerShell 7+
# ============================================================
[CmdletBinding()]
param(
    [int]$Port = 8777,
    [switch]$Silent,
    [switch]$NoBrowser,
    # ---- command line mode (no UI, does the job and exits) ----
    [string]$Apply = '',      # apply a pack by name
    [switch]$Random,          # apply a random enabled pack
    [switch]$Restore,         # restore Windows default cursors
    [switch]$List,            # list all detected packs
    [switch]$Rescan,          # extract + rescan only
    [int]$Every = 0,          # set rotation interval in SECONDS and exit
    [switch]$DownloadAll,     # download every pack from the built-in store
    [string]$Download = '',   # download one store pack by id (or 'list')
    [switch]$Setup7Zip,       # download portable 7-Zip only
    [string]$Tag = '',        # filter store downloads by tag, e.g. -DownloadAll -Tag RGB
    [switch]$RemoveAll,       # restore Windows cursors, clear settings and autorun
    [switch]$DeletePacks,     # with -RemoveAll: also delete every downloaded pack
    [switch]$Unblock          # clear the Windows "downloaded from the internet" flag and exit
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------- Paths ----------
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$PacksDir   = Join-Path $Root 'Packs'
$DataDir    = Join-Path $Root 'Data'
$CustomDir  = Join-Path $PacksDir '_My Custom Packs'   # created by the pack builder
$ConfigFile = Join-Path $DataDir 'config.json'
$BackupFile = Join-Path $DataDir 'original-scheme.json'
$LogFile    = Join-Path $DataDir 'log.txt'

# Run from TEMP so Windows never reports "folder in use" for the app folder itself
try {
    Set-Location -LiteralPath $env:TEMP
    [Environment]::CurrentDirectory = $env:TEMP
} catch { }

foreach ($d in @($PacksDir, $DataDir)) {
    if (-not [System.IO.Directory]::Exists($d)) { [System.IO.Directory]::CreateDirectory($d) | Out-Null }
}

$Script:LastError = ''
function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    try {
        $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Msg
        [System.IO.File]::AppendAllText($LogFile, $line + [Environment]::NewLine)
        if (-not $Silent) {
            if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
            elseif ($Level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
            else { Write-Host $line }
        }
        if ($Level -eq 'ERROR') { $Script:LastError = $Msg }
    } catch { }
}
function Log-Err {
    param($E, [string]$Where)
    $m = "$Where : $($E.Exception.Message)"
    Write-Log $m 'ERROR'
    try { Write-Log ("   at " + ($E.ScriptStackTrace -replace "`r?`n", ' | ')) 'ERROR' } catch { }
}

# ---------- Win32 ----------
if (-not ('CR.Native' -as [type])) {
    $src = @"
using System;
using System.Runtime.InteropServices;
namespace CR {
  public static class Native {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    public static void RefreshCursors() { SystemParametersInfo(0x0057, 0, IntPtr.Zero, 3); }
  }
}
"@
    try { Add-Type -TypeDefinition $src } catch { Write-Log "Add-Type failed: $($_.Exception.Message)" 'WARN' }
}
try { Add-Type -AssemblyName System.Windows.Forms } catch { }
try { Add-Type -AssemblyName System.Drawing } catch { }
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch { }

# ---------- Roles ----------
$Script:Roles = @(
    @{ Key = 'Arrow';       Label = 'Normal Select';         Default = '%SystemRoot%\cursors\aero_arrow.cur' }
    @{ Key = 'Help';        Label = 'Help Select';           Default = '%SystemRoot%\cursors\aero_helpsel.cur' }
    @{ Key = 'AppStarting'; Label = 'Working In Background'; Default = '%SystemRoot%\cursors\aero_working.ani' }
    @{ Key = 'Wait';        Label = 'Busy / Loading';        Default = '%SystemRoot%\cursors\aero_busy.ani' }
    @{ Key = 'Crosshair';   Label = 'Precision Select';      Default = '' }
    @{ Key = 'IBeam';       Label = 'Text Select';           Default = '' }
    @{ Key = 'NWPen';       Label = 'Handwriting';           Default = '%SystemRoot%\cursors\aero_pen.cur' }
    @{ Key = 'No';          Label = 'Unavailable';           Default = '%SystemRoot%\cursors\aero_unavail.cur' }
    @{ Key = 'SizeNS';      Label = 'Vertical Resize';       Default = '%SystemRoot%\cursors\aero_ns.cur' }
    @{ Key = 'SizeWE';      Label = 'Horizontal Resize';     Default = '%SystemRoot%\cursors\aero_ew.cur' }
    @{ Key = 'SizeNWSE';    Label = 'Diagonal Resize 1';     Default = '%SystemRoot%\cursors\aero_nwse.cur' }
    @{ Key = 'SizeNESW';    Label = 'Diagonal Resize 2';     Default = '%SystemRoot%\cursors\aero_nesw.cur' }
    @{ Key = 'SizeAll';     Label = 'Move';                  Default = '%SystemRoot%\cursors\aero_move.cur' }
    @{ Key = 'UpArrow';     Label = 'Alternate Select';      Default = '%SystemRoot%\cursors\aero_up.cur' }
    @{ Key = 'Hand';        Label = 'Link Select';           Default = '%SystemRoot%\cursors\aero_link.cur' }
    @{ Key = 'Pin';         Label = 'Location Select';       Default = '%SystemRoot%\cursors\aero_pin.cur' }
    @{ Key = 'Person';      Label = 'Person Select';         Default = '%SystemRoot%\cursors\aero_person.cur' }
)
$Script:RoleKeys = @($Script:Roles | ForEach-Object { $_.Key })

# exact filename tokens (lowercase, symbols removed)
$Script:ExactTokens = @{
    'arrow'='Arrow';'normal'='Arrow';'normalselect'='Arrow';'pointer'='Arrow';'ptr'='Arrow';'default'='Arrow';'select'='Arrow';'ar'='Arrow';'std'='Arrow';'standard'='Arrow'
    'help'='Help';'helpselect'='Help';'question'='Help';'aerohelpsel'='Help'
    'work'='AppStarting';'working'='AppStarting';'appstarting'='AppStarting';'background'='AppStarting';'wrk'='AppStarting';'loading'='AppStarting';'workinginbackground'='AppStarting';'aeroworking'='AppStarting'
    'busy'='Wait';'wait'='Wait';'hourglass'='Wait';'bs'='Wait';'aerobusy'='Wait'
    'cross'='Crosshair';'crosshair'='Crosshair';'precision'='Crosshair';'cr'='Crosshair';'precisionselect'='Crosshair'
    'beam'='IBeam';'ibeam'='IBeam';'text'='IBeam';'textselect'='IBeam';'tx'='IBeam'
    'pen'='NWPen';'nwpen'='NWPen';'handwriting'='NWPen';'write'='NWPen';'aeropen'='NWPen'
    'no'='No';'unavailable'='No';'unavailiable'='No';'unavail'='No';'forbidden'='No';'denied'='No';'aerounavail'='No'
    'ns'='SizeNS';'sizens'='SizeNS';'vertical'='SizeNS';'vert'='SizeNS';'updown'='SizeNS';'size4'='SizeNS';'verticalresize'='SizeNS';'aerons'='SizeNS'
    'we'='SizeWE';'ew'='SizeWE';'sizewe'='SizeWE';'horizontal'='SizeWE';'horz'='SizeWE';'leftright'='SizeWE';'size3'='SizeWE';'horizontalresize'='SizeWE';'aeroew'='SizeWE'
    'nwse'='SizeNWSE';'sizenwse'='SizeNWSE';'size1'='SizeNWSE';'diagonal1'='SizeNWSE';'diag1'='SizeNWSE';'dgn1'='SizeNWSE';'dng1'='SizeNWSE';'diagonalresize1'='SizeNWSE';'aeronwse'='SizeNWSE'
    'nesw'='SizeNESW';'sizenesw'='SizeNESW';'size2'='SizeNESW';'diagonal2'='SizeNESW';'diag2'='SizeNESW';'dgn2'='SizeNESW';'dng2'='SizeNESW';'diagonalresize2'='SizeNESW';'aeronesw'='SizeNESW'
    'move'='SizeAll';'sizeall'='SizeAll';'mv'='SizeAll';'omni'='SizeAll';'pan'='SizeAll';'aeromove'='SizeAll'
    'up'='UpArrow';'uparrow'='UpArrow';'alternate'='UpArrow';'alt'='UpArrow';'alternateselect'='UpArrow';'aeroup'='UpArrow'
    'link'='Hand';'hand'='Hand';'linkselect'='Hand';'lk'='Hand';'click'='Hand';'aerolink'='Hand'
    'pin'='Pin';'location'='Pin';'locationselect'='Pin';'aeropin'='Pin'
    'person'='Person';'user'='Person';'personselect'='Person';'aeroperson'='Person'
    # extra spellings seen in community packs
    'point'='Arrow';'pointerarrow'='Arrow';'idle'='Arrow';'main'='Arrow';'normalcursor'='Arrow';'left'='Arrow';'leftptr'='Arrow';'defaultcursor'='Arrow'
    'grab'='Hand';'grabbing'='Hand';'pointinghand'='Hand';'handpoint'='Hand';'pointinghandcursor'='Hand';'openhand'='Hand';'linkhand'='Hand';'hyperlink'='Hand'
    'load'='Wait';'loadingcircle'='Wait';'waiting'='Wait';'watch'='Wait';'spinner'='Wait';'busycursor'='Wait'
    'workingbackground'='AppStarting';'appstart'='AppStarting';'startworking'='AppStarting';'progress'='AppStarting'
    'caret'='IBeam';'textcursor'='IBeam';'edit'='IBeam';'insert'='IBeam';'xterm'='IBeam'
    'nodrop'='No';'notallowed'='No';'blocked'='No';'circle'='No';'stop'='No';'crossedcircle'='No'
    'sizeud'='SizeNS';'updownarrow'='SizeNS';'vresize'='SizeNS';'nsresize'='SizeNS';'topbottom'='SizeNS';'sbvdoublearrow'='SizeNS'
    'sizelr'='SizeWE';'leftrightarrow'='SizeWE';'hresize'='SizeWE';'weresize'='SizeWE';'sbhdoublearrow'='SizeWE'
    'nwsesize'='SizeNWSE';'sizefdiag'='SizeNWSE';'topleftbottomright'='SizeNWSE';'diagonalresize'='SizeNWSE';'diagonal'='SizeNWSE'
    'neswsize'='SizeNESW';'sizebdiag'='SizeNESW';'toprightbottomleft'='SizeNESW'
    'allscroll'='SizeAll';'fleur'='SizeAll';'movecursor'='SizeAll';'drag'='SizeAll';'sizeallcursor'='SizeAll'
    'altselect'='UpArrow';'upalternate'='UpArrow';'arrowup'='UpArrow';'centerptr'='UpArrow'
    'locationpin'='Pin';'place'='Pin';'marker'='Pin';'geo'='Pin'
    'people'='Person';'contact'='Person';'profile'='Person'
    'handwritingpen'='NWPen';'pencil'='NWPen';'draw'='NWPen';'ink'='NWPen'
    'crosshairs'='Crosshair';'target'='Crosshair';'aim'='Crosshair';'plus'='Crosshair'
    'helpcursor'='Help';'questionmark'='Help';'whatsthis'='Help';'info'='Help'
}
$Script:RoleRules = [ordered]@{
    'NWPen'       = @('handwriting','handwrite','pen')
    'Help'        = @('help','question','whatsthis')
    'AppStarting' = @('appstarting','working','background','startup','loading','wrk')
    'Wait'        = @('busy','wait','hourglass','spinner','progress')
    'Crosshair'   = @('precision','crosshair','cross','prec')
    'IBeam'       = @('ibeam','beam','text','caret')
    'No'          = @('unavailable','unavailiable','unavail','forbid','denied','blocked','notallowed')
    'SizeNWSE'    = @('nwse','size1','diagonal1','diag1','resize1','dgn1','dng1')
    'SizeNESW'    = @('nesw','size2','diagonal2','diag2','resize2','dgn2','dng2')
    'SizeNS'      = @('sizens','vertical','vert','updown','north','size4')
    'SizeWE'      = @('sizewe','sizeew','horizontal','horz','leftright','east','size3')
    'SizeAll'     = @('sizeall','move','allsize','omni','pan')
    'UpArrow'     = @('alternate','uparrow','altselect')
    'Hand'        = @('linkselect','link','hand','click')
    'Pin'         = @('pin','location')
    'Person'      = @('person','people','user')
    'Arrow'       = @('normal','arrow','pointer','default','select','standard','ptr')
}

function Get-RoleFromName {
    param([string]$FileName)
    if ([string]::IsNullOrWhiteSpace($FileName)) { return $null }
    $low  = $FileName.ToLowerInvariant()
    $norm = ($low -replace '[^a-z0-9]', '')
    if ($Script:ExactTokens.ContainsKey($norm)) { return $Script:ExactTokens[$norm] }

    # strip common prefixes / size suffixes and try again
    $stripped = $norm -replace '^(cursor|cur|pointer|ptr|aero|win11|win10|windows)', ''
    $stripped = $stripped -replace '(small|regular|large|extralarge|xl|xs|sm|md|lg|128|96|72|64|48|32|24|16)$', ''
    if ($stripped -and $Script:ExactTokens.ContainsKey($stripped)) { return $Script:ExactTokens[$stripped] }

    # word-level match: "Kuro precision.ani" -> words: kuro, precision
    $words = @($low -split '[^a-z0-9]+' | Where-Object { $_ })
    for ($i = $words.Count - 1; $i -ge 0; $i--) {
        $w = $words[$i]
        if ($Script:ExactTokens.ContainsKey($w)) { return $Script:ExactTokens[$w] }
    }
    # two-word combos, right to left: "diagonal 1" -> diagonal1
    for ($i = $words.Count - 2; $i -ge 0; $i--) {
        $w = $words[$i] + $words[$i+1]
        if ($Script:ExactTokens.ContainsKey($w)) { return $Script:ExactTokens[$w] }
    }

    if ($norm -match 'diag|dgn|dng') {
        if ($norm -match '1') { return 'SizeNWSE' }
        if ($norm -match '2') { return 'SizeNESW' }
    }
    if ($norm -match 'resize|size') {
        if ($norm -match 'vert|updown|ns\b') { return 'SizeNS' }
        if ($norm -match 'horiz|horz|leftright') { return 'SizeWE' }
        if ($norm -match 'all|omni') { return 'SizeAll' }
    }
    foreach ($role in $Script:RoleRules.Keys) {
        foreach ($kw in $Script:RoleRules[$role]) {
            if ($norm.Contains($kw)) { return $role }
        }
    }
    return $null
}

# ---------- INF parsing (most accurate mapping) ----------
function Parse-InfMapping {
    param([string]$Folder)
    $map = @{}
    try {
        $infs = @([System.IO.Directory]::GetFiles($Folder, '*.inf'))
        if ($infs.Count -eq 0) { return $map }
        $text = [System.IO.File]::ReadAllText($infs[0])
        $lines = $text -split "`r?`n"

        # 1) [Strings] : var = "File.cur"
        $vars = @{}
        foreach ($l in $lines) {
            if ($l -match '^\s*([\w\-]+)\s*=\s*"?([^"`;]+?\.(?:cur|ani))"?\s*$') {
                $vars[$Matches[1].ToLowerInvariant()] = $Matches[2].Trim()
            }
        }
        # 2) [Wreg] : HKCU,"Control Panel\Cursors",Arrow,0x...,"...%var%"
        foreach ($l in $lines) {
            if ($l -match 'Control Panel\\Cursors"\s*,\s*([A-Za-z]+)\s*,[^,]*,\s*"(.+)"\s*$') {
                $regName = $Matches[1]
                $value   = $Matches[2]
                if ($Script:RoleKeys -notcontains $regName) {
                    if ($regName -ieq 'precisionhair') { $regName = 'Crosshair' } else { continue }
                }
                $file = $null
                if ($value -match '%([\w\-]+)%\s*$') {
                    $v = $Matches[1].ToLowerInvariant()
                    if ($vars.ContainsKey($v)) { $file = $vars[$v] }
                } elseif ($value -match '([^\\\/%]+\.(?:cur|ani))\s*$') {
                    $file = $Matches[1]
                }
                if ($file) {
                    $full = Join-Path $Folder ([System.IO.Path]::GetFileName($file))
                    if ([System.IO.File]::Exists($full)) { $map[$regName] = $full }
                }
            }
        }
        # 3) fallback: plain "pointer = file.cur" style keys
        if ($map.Count -eq 0) {
            $alias = @{ 'pointer'='Arrow';'help'='Help';'work'='AppStarting';'appstarting'='AppStarting';'busy'='Wait';'wait'='Wait';
                        'cross'='Crosshair';'crosshair'='Crosshair';'text'='IBeam';'ibeam'='IBeam';'handwriting'='NWPen';'nwpen'='NWPen';
                        'unavailable'='No';'no'='No';'vert'='SizeNS';'sizens'='SizeNS';'horz'='SizeWE';'sizewe'='SizeWE';
                        'dgn1'='SizeNWSE';'sizenwse'='SizeNWSE';'dgn2'='SizeNESW';'sizenesw'='SizeNESW';'move'='SizeAll';'sizeall'='SizeAll';
                        'alternate'='UpArrow';'uparrow'='UpArrow';'link'='Hand';'hand'='Hand';'pin'='Pin';'person'='Person' }
            foreach ($k in $vars.Keys) {
                if ($alias.ContainsKey($k)) {
                    $full = Join-Path $Folder ([System.IO.Path]::GetFileName($vars[$k]))
                    if ([System.IO.File]::Exists($full)) { $map[$alias[$k]] = $full }
                }
            }
        }
    } catch { Write-Log "INF parse skipped in $Folder : $($_.Exception.Message)" 'WARN' }
    return $map
}

# ---------- Scheme discovery (pure .NET IO - safe with [ ] & # in names) ----------
$Script:Diag = [ordered]@{ folders = 0; cursorFiles = 0; skipped = 0; note = '' }

function Get-CursorFiles {
    param([string]$Dir)
    $out = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($f in [System.IO.Directory]::GetFiles($Dir)) {
            $e = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
            if ($e -eq '.cur' -or $e -eq '.ani') { $out.Add($f) }
        }
    } catch { }
    return $out
}

function Get-AllDirectories {
    param([string]$Base)
    $res = New-Object System.Collections.Generic.List[string]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Base)
    $guard = 0
    while ($stack.Count -gt 0 -and $guard -lt 20000) {
        $guard++
        $d = $stack.Pop()
        $res.Add($d)
        try { foreach ($s in [System.IO.Directory]::GetDirectories($d)) { $stack.Push($s) } } catch { }
    }
    return $res
}

function Get-PackTitle {
    # a friendly name: scheme name from install.inf if the pack ships one
    param([string]$Folder, [string]$Fallback)
    try {
        $infs = @([System.IO.Directory]::GetFiles($Folder, '*.inf'))
        if ($infs.Count -eq 0) { return $Fallback }
        foreach ($l in ([System.IO.File]::ReadAllText($infs[0]) -split "`r?`n")) {
            if ($l -match '^\s*SCHEME_NAME\s*=\s*"?([^"]+?)"?\s*$') { return $Matches[1].Trim() }
        }
    } catch { }
    return $Fallback
}

function Get-Schemes {
    $schemes = New-Object System.Collections.Generic.List[object]
    $Script:Diag = [ordered]@{ folders = 0; cursorFiles = 0; skipped = 0; note = ''; ignored = (New-Object System.Collections.Generic.List[string]) }
    $roots = New-Object System.Collections.Generic.List[string]
    $roots.Add($PacksDir)

    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($r in $roots) {
        if ([System.IO.Directory]::Exists($r)) { foreach ($x in (Get-AllDirectories -Base $r)) { $dirs.Add($x) } }
    }
    $Script:Diag.folders = $dirs.Count
    foreach ($d in $dirs) {
        $files = Get-CursorFiles -Dir $d
        # tell the user about stray files instead of failing on them
        try {
            foreach ($f in [System.IO.Directory]::GetFiles($d)) {
                $e = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
                if ($e -eq '.cur' -or $e -eq '.ani' -or $e -eq '.inf' -or $e -eq '.zip' -or $e -eq '.7z' -or $e -eq '.rar') { continue }
                $nm = [System.IO.Path]::GetFileName($f)
                if ($nm -eq '.extracted.txt' -or $nm -eq 'pack.txt' -or $nm -eq '_PUT-YOUR-ZIP-FILES-HERE.txt') { continue }
                $Script:Diag.skipped++
                if ($Script:Diag.ignored.Count -lt 25) {
                    $rel2 = $f
                    if ($f.StartsWith($PacksDir, [StringComparison]::OrdinalIgnoreCase)) { $rel2 = $f.Substring($PacksDir.Length).Trim([char]92, [char]47) }
                    $Script:Diag.ignored.Add([string]$rel2)
                }
            }
        } catch { }
        if ($files.Count -eq 0) { continue }
        $Script:Diag.cursorFiles += $files.Count
        if ($files.Count -lt 1) { continue }

        $rel = $d
        foreach ($r in $roots) {
            if ($d.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) {
                if ($d.Length -gt $r.Length) { $rel = $d.Substring($r.Length).Trim([char]92, [char]47) } else { $rel = 'Root' }
                break
            }
        }
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'Root' }

        $map = Parse-InfMapping -Folder $d
        $sorted = @($files | Sort-Object)
        foreach ($file in $sorted) {
            $role = Get-RoleFromName -FileName ([System.IO.Path]::GetFileNameWithoutExtension($file))
            if ($role -and -not $map.ContainsKey($role)) { $map[$role] = $file }
        }
        if (-not $map.ContainsKey('Arrow')) {
            $c = @($sorted | Where-Object { $_.ToLowerInvariant().EndsWith('.cur') })
            if ($c.Count -gt 0) { $map['Arrow'] = $c[0] }
        }
        $covered = 0
        foreach ($k in $Script:RoleKeys) { if ($map.ContainsKey($k)) { $covered++ } }

        $aniN = 0
        foreach ($f9 in $sorted) { if (([string]$f9).ToLowerInvariant().EndsWith('.ani')) { $aniN++ } }
        $schemes.Add([pscustomobject]@{
            name     = $rel
            path     = $d
            files    = [object[]]$sorted
            map      = $map
            coverage = $covered
            total    = $Script:RoleKeys.Count
            aniCount = [int]$aniN
            title    = [string](Get-PackTitle -Folder $d -Fallback ([System.IO.Path]::GetFileName($d)))
        })
    }
    return , ([object[]]$schemes.ToArray())
}



# ---------- Global hotkeys (Ctrl+Alt+C = change now, Ctrl+Alt+P = pause/resume) ----------
if (-not ('CR.HotKeys' -as [type])) {
    $hsrc = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace CR {
  public class HotKeys : NativeWindow {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public static int Last = 0;
    public HotKeys() { CreateHandle(new CreateParams()); }
    public bool Add(int id, uint mods, uint key) { return RegisterHotKey(this.Handle, id, mods, key); }
    public void RemoveAll() { for (int i = 1; i <= 4; i++) { try { UnregisterHotKey(this.Handle, i); } catch {} } }
    protected override void WndProc(ref Message m) { if (m.Msg == 0x0312) { Last = (int)m.WParam; } base.WndProc(ref m); }
  }
}
"@
    try { Add-Type -TypeDefinition $hsrc -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -ErrorAction Stop }
    catch { try { Add-Type -TypeDefinition $hsrc -ReferencedAssemblies 'System.Windows.Forms' -ErrorAction Stop } catch { Write-Log 'Hotkeys unavailable on this system.' 'WARN' } }
}

# ---------- Cursor preview: turn .cur / .ani into browser-renderable .ico ----------
$Script:PreviewCache = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$Script:SevenZipTried = $false

function ConvertTo-IcoBytes {
    # a .cur is an ICO file with type=2 + hotspots; patch it to type=1 so browsers render it
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -lt 22) { return $null }
    $out = New-Object byte[] $Bytes.Length
    [Array]::Copy($Bytes, $out, $Bytes.Length)
    $type = [BitConverter]::ToUInt16($out, 2)
    if ($type -ne 1 -and $type -ne 2) { return $null }
    $out[2] = 1; $out[3] = 0                       # idType = 1 (icon)
    $count = [BitConverter]::ToUInt16($out, 4)
    if ($count -lt 1 -or $count -gt 64) { return $null }
    for ($i = 0; $i -lt $count; $i++) {
        $e = 6 + ($i * 16)
        if ($e + 16 -gt $out.Length) { break }
        $out[$e + 4] = 1; $out[$e + 5] = 0          # wPlanes  (was xHotspot)
        $out[$e + 6] = 0; $out[$e + 7] = 0          # wBitCount(was yHotspot) - 0 = take from DIB
    }
    return $out
}

function Get-AniInfo {
    # Parse a RIFF/ACON animated cursor: all icon frames, the frame order and per-step timing.
    param([byte[]]$Bytes)
    $res = @{ frames = (New-Object System.Collections.Generic.List[object]); rates = (New-Object System.Collections.Generic.List[int]); seq = (New-Object System.Collections.Generic.List[int]); defRate = 100 }
    if ($null -eq $Bytes -or $Bytes.Length -lt 16) { return $res }
    if ([Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -ne 'RIFF') { return $res }
    $steps = 0
    $pos = 12
    $guard = 0
    while ($pos + 8 -le $Bytes.Length -and $guard -lt 20000) {
        $guard++
        $id   = [Text.Encoding]::ASCII.GetString($Bytes, $pos, 4)
        $size = [BitConverter]::ToInt32($Bytes, $pos + 4)
        if ($size -lt 0) { break }
        if ($id -eq 'LIST') { $pos += 12; continue }
        if ($id -eq 'anih' -and $size -ge 36) {
            $steps = [BitConverter]::ToInt32($Bytes, $pos + 8 + 8)          # nSteps
            $jif   = [BitConverter]::ToInt32($Bytes, $pos + 8 + 28)         # iDispRate in 1/60 s
            if ($jif -gt 0) { $res.defRate = [int]([math]::Round($jif * 1000.0 / 60.0)) }
        }
        elseif ($id -eq 'rate') {
            $n = [int]($size / 4)
            for ($i = 0; $i -lt $n; $i++) {
                $j = [BitConverter]::ToInt32($Bytes, $pos + 8 + ($i * 4))
                $res.rates.Add([int][math]::Max(20, [math]::Round($j * 1000.0 / 60.0)))
            }
        }
        elseif ($id -eq 'seq ') {
            $n = [int]($size / 4)
            for ($i = 0; $i -lt $n; $i++) { $res.seq.Add([BitConverter]::ToInt32($Bytes, $pos + 8 + ($i * 4))) }
        }
        elseif ($id -eq 'icon') {
            $len = [Math]::Min($size, $Bytes.Length - ($pos + 8))
            if ($len -gt 0) {
                $frame = New-Object byte[] $len
                [Array]::Copy($Bytes, $pos + 8, $frame, 0, $len)
                $res.frames.Add($frame)
            }
        }
        $pos += 8 + $size + ($size % 2)
    }
    if ($res.seq.Count -eq 0) { for ($i = 0; $i -lt $res.frames.Count; $i++) { $res.seq.Add($i) } }
    if ($res.rates.Count -eq 0) { foreach ($x in $res.seq) { $res.rates.Add([int]$res.defRate) } }
    return $res
}

function Get-AniFirstFrame {
    param([byte[]]$Bytes)
    $info = Get-AniInfo -Bytes $Bytes
    if ($info.frames.Count -eq 0) { return $null }
    return $info.frames[0]
}

function Get-AniFrameBytes {
    # ICO bytes of one frame of an animated cursor (used by /file?p=...&frame=N)
    param([string]$Path, [int]$Index)
    try {
        $key = "$Path|$Index"
        if ($Script:PreviewCache.ContainsKey($key)) { return $Script:PreviewCache[$key] }
        $info = Get-AniInfo -Bytes ([System.IO.File]::ReadAllBytes($Path))
        if ($info.frames.Count -eq 0) { return $null }
        if ($Index -lt 0) { $Index = 0 }
        if ($Index -ge $info.frames.Count) { $Index = $info.frames.Count - 1 }
        $ico = ConvertTo-IcoBytes -Bytes $info.frames[$Index]
        if ($null -ne $ico -and $Script:PreviewCache.Count -lt 6000) { $Script:PreviewCache[$key] = $ico }
        return $ico
    } catch { return $null }
}

function Get-AniMeta {
    # small JSON friendly description of the animation
    param([string]$Path)
    try {
        $info = Get-AniInfo -Bytes ([System.IO.File]::ReadAllBytes($Path))
        $seq = @($info.seq | Where-Object { $_ -ge 0 -and $_ -lt $info.frames.Count })
        if ($seq.Count -eq 0) { $seq = @(0) }
        $rates = @()
        for ($i = 0; $i -lt $seq.Count; $i++) {
            $r = if ($i -lt $info.rates.Count) { $info.rates[$i] } else { $info.defRate }
            $rates += [int][math]::Max(20, $r)
        }
        return [pscustomobject]@{ ok = $true; frames = [int]$info.frames.Count; seq = [int[]]$seq; rates = [int[]]$rates }
    } catch { return [pscustomobject]@{ ok = $false; frames = 0; seq = @(0); rates = @(100) } }
}

function Get-AniFirstFrameOld {
    # .ani = RIFF/ACON container; pull the first "icon" chunk (which is a .cur/.ico)
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -lt 16) { return $null }
    if ([Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -ne 'RIFF') { return $null }
    $pos = 12
    while ($pos + 8 -le $Bytes.Length) {
        $id   = [Text.Encoding]::ASCII.GetString($Bytes, $pos, 4)
        $size = [BitConverter]::ToInt32($Bytes, $pos + 4)
        if ($size -lt 0) { break }
        if ($id -eq 'LIST') {
            $pos += 12                                  # step into the list body
            continue
        }
        if ($id -eq 'icon') {
            $len = [Math]::Min($size, $Bytes.Length - ($pos + 8))
            if ($len -le 0) { return $null }
            $frame = New-Object byte[] $len
            [Array]::Copy($Bytes, $pos + 8, $frame, 0, $len)
            return $frame
        }
        $pos += 8 + $size + ($size % 2)                 # chunks are word aligned
    }
    return $null
}

function Get-CursorPreviewBytes {
    param([string]$Path)
    try {
        if ($Script:PreviewCache.ContainsKey($Path)) { return $Script:PreviewCache[$Path] }
        $raw = [System.IO.File]::ReadAllBytes($Path)
        $src = $raw
        if ($Path.ToLowerInvariant().EndsWith('.ani')) {
            $f = Get-AniFirstFrame -Bytes $raw
            if ($null -eq $f) { return $null }
            $src = $f
        }
        $ico = ConvertTo-IcoBytes -Bytes $src
        if ($null -ne $ico -and $Script:PreviewCache.Count -lt 4000) { $Script:PreviewCache[$Path] = $ico }
        return $ico
    } catch { return $null }
}

# ---------- Config ----------
function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [hashtable]) { if ($Obj.ContainsKey($Name)) { return $Obj[$Name] } else { return $null } }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}


function Get-DefaultConfig {
    [pscustomobject]@{
        enabled = $true
        intervalSeconds = 1800          # rotation interval in seconds (min 5)
        randomOrder = $true
        applyOnStart = $true
        avoidRepeat = $true
        notifications = $true
        hotkeys = $true
        fillMissing = $true             # missing cursor jobs borrow from the same pack
        disabledSchemes = @()           # packs switched OFF in the UI
        overrides = New-Object psobject # per pack: role -> file path
        lastScheme = ''
    }
}
function Get-IntervalSeconds {
    param($Cfg)
    $v = Get-Prop $Cfg 'intervalSeconds'
    if (-not $v) {
        $m = Get-Prop $Cfg 'intervalMinutes'      # migrate old config
        if ($m) { $v = [double]$m * 60 } else { $v = 1800 }
        Add-Member -InputObject $Cfg -NotePropertyName 'intervalSeconds' -NotePropertyValue $v -Force
    }
    $v = [double]$v
    if ($v -lt 5) { $v = 5 }
    return $v
}
function Load-Config {
    try {
        if ([System.IO.File]::Exists($ConfigFile)) {
            $raw = [System.IO.File]::ReadAllText($ConfigFile)
            if ($raw.Trim()) {
                $c = $raw | ConvertFrom-Json
                $d = Get-DefaultConfig
                foreach ($p in $d.PSObject.Properties) {
                    if (-not $c.PSObject.Properties.Match($p.Name).Count) {
                        Add-Member -InputObject $c -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
                    }
                }
                return $c
            }
        }
    } catch { Log-Err $_ 'Load-Config' }
    return Get-DefaultConfig
}
function Save-Config {
    param($Cfg)
    try { [System.IO.File]::WriteAllText($ConfigFile, ($Cfg | ConvertTo-Json -Depth 10)) }
    catch { Log-Err $_ 'Save-Config' }
}
# ---------- Backup / Restore ----------
function Backup-OriginalScheme {
    try {
        if ([System.IO.File]::Exists($BackupFile)) { return }
        $o = [ordered]@{}
        $k = Get-ItemProperty -Path 'HKCU:\Control Panel\Cursors' -ErrorAction SilentlyContinue
        foreach ($r in $Script:Roles) {
            $v = if ($k) { $k.PSObject.Properties[$r.Key] } else { $null }
            $o[$r.Key] = if ($v) { [string]$v.Value } else { $r.Default }
        }
        [System.IO.File]::WriteAllText($BackupFile, ($o | ConvertTo-Json -Depth 4))
        Write-Log 'Original cursor scheme backed up.'
    } catch { Log-Err $_ 'Backup-OriginalScheme' }
}
function Restore-OriginalScheme {
    try {
        $vals = @{}
        if ([System.IO.File]::Exists($BackupFile)) {
            $b = [System.IO.File]::ReadAllText($BackupFile) | ConvertFrom-Json
            foreach ($r in $Script:Roles) {
                $v = Get-Prop $b $r.Key
                $vals[$r.Key] = if ($v) { [string]$v } else { $r.Default }
            }
        } else { foreach ($r in $Script:Roles) { $vals[$r.Key] = $r.Default } }
        foreach ($r in $Script:Roles) {
            Set-ItemProperty -Path 'HKCU:\Control Panel\Cursors' -Name $r.Key -Value $vals[$r.Key] -Type ExpandString -Force -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path 'HKCU:\Control Panel\Cursors' -Name '(default)' -Value 'Windows Default' -Force -ErrorAction SilentlyContinue
        try { [CR.Native]::RefreshCursors() } catch { }
        Write-Log 'Restored original Windows cursors.'
        return $true
    } catch { Log-Err $_ 'Restore-OriginalScheme'; return $false }
}

# ---------- Archive extraction (7-Zip first, WinRAR only as last resort) ----------
$ToolsDir = Join-Path $Root 'Tools'
$SevenZipDir = Join-Path $ToolsDir '7zip'

function Get-Extractor {
    # returns @{ path=...; kind='7z'|'7zr'|'rar'; label=... } or $null
    $cands = @(
        @{ p = (Join-Path $SevenZipDir '7z.exe');  k = '7z';  l = 'Portable 7-Zip (in Tools folder)' }
        @{ p = "$env:ProgramFiles\7-Zip\7z.exe";   k = '7z';  l = 'Installed 7-Zip' }
        @{ p = "${env:ProgramFiles(x86)}\7-Zip\7z.exe"; k = '7z'; l = 'Installed 7-Zip (x86)' }
        @{ p = (Join-Path $SevenZipDir '7za.exe'); k = '7z';  l = 'Portable 7za' }
        @{ p = (Join-Path $SevenZipDir '7zr.exe'); k = '7zr'; l = 'Portable 7zr (.7z only)' }
    )
    foreach ($c in $cands) { if ($c.p -and [System.IO.File]::Exists($c.p)) { return @{ path = $c.p; kind = $c.k; label = $c.l } } }
    # WinRAR is the very last resort (its trial nag can block silent extraction)
    foreach ($w in @("$env:ProgramFiles\WinRAR\WinRAR.exe", "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe")) {
        if ([System.IO.File]::Exists($w)) { return @{ path = $w; kind = 'rar'; label = 'WinRAR (fallback)' } }
    }
    return $null
}

function Install-SevenZip {
    # downloads 7-Zip and unpacks it WITHOUT installing anything (no admin, no WinRAR needed)
    try {
        if (-not [System.IO.Directory]::Exists($SevenZipDir)) { [System.IO.Directory]::CreateDirectory($SevenZipDir) | Out-Null }
        $exe = Join-Path $SevenZipDir '7z.exe'
        if ([System.IO.File]::Exists($exe)) { return "Portable 7-Zip already present" }

        # 1) MSI administrative extract -> gives 7z.exe + 7z.dll (full rar/7z/zip support)
        $msi = Join-Path $DataDir '7zip.msi'
        $urls = @('https://www.7-zip.org/a/7z2501-x64.msi', 'https://www.7-zip.org/a/7z2409-x64.msi', 'https://www.7-zip.org/a/7z2301-x64.msi')
        foreach ($u in $urls) {
            try {
                Write-Log "Downloading 7-Zip from $u"
                Invoke-WebRequest -Uri $u -OutFile $msi -UseBasicParsing -TimeoutSec 300
                if ([System.IO.File]::Exists($msi) -and (New-Object System.IO.FileInfo($msi)).Length -gt 200000) { break }
            } catch { Write-Log "7-Zip download failed from $u : $($_.Exception.Message)" 'WARN' }
        }
        if ([System.IO.File]::Exists($msi)) {
            $stage = Join-Path $ToolsDir '_7zstage'
            try {
                Start-Process 'msiexec.exe' -ArgumentList @('/a', "`"$msi`"", '/qn', "TARGETDIR=`"$stage`"") -Wait -WindowStyle Hidden
            } catch { Write-Log "msiexec failed: $($_.Exception.Message)" 'WARN' }
            if ([System.IO.Directory]::Exists($stage)) {
                foreach ($f in [System.IO.Directory]::GetFiles($stage, '*', [System.IO.SearchOption]::AllDirectories)) {
                    $n = [System.IO.Path]::GetFileName($f).ToLowerInvariant()
                    if ($n -eq '7z.exe' -or $n -eq '7z.dll' -or $n -eq '7za.exe' -or $n -eq '7-zip.dll') {
                        try { [System.IO.File]::Copy($f, (Join-Path $SevenZipDir ([System.IO.Path]::GetFileName($f))), $true) } catch { }
                    }
                }
                try { [System.IO.Directory]::Delete($stage, $true) } catch { }
            }
            try { [System.IO.File]::Delete($msi) } catch { }
        }
        if ([System.IO.File]::Exists($exe)) { Write-Log 'Portable 7-Zip ready.'; return 'Portable 7-Zip installed (no system install, no admin)' }

        # 2) fallback: 7zr.exe standalone (.7z only)
        try {
            $zr = Join-Path $SevenZipDir '7zr.exe'
            Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile $zr -UseBasicParsing -TimeoutSec 180
            if ([System.IO.File]::Exists($zr)) { Write-Log 'Downloaded 7zr.exe (.7z support).'; return 'Downloaded 7zr.exe (.7z archives only)' }
        } catch { Write-Log "7zr download failed: $($_.Exception.Message)" 'WARN' }

        return 'Could not set up 7-Zip - check your internet connection'
    } catch { Log-Err $_ 'Install-SevenZip'; return "7-Zip setup failed: $($_.Exception.Message)" }
}

function Expand-OneArchive {
    param([string]$Archive, [string]$Target)
    $ext = [System.IO.Path]::GetExtension($Archive).ToLowerInvariant()
    if (-not [System.IO.Directory]::Exists($Target)) { [System.IO.Directory]::CreateDirectory($Target) | Out-Null }

    # 1) .zip -> built in .NET unzip, no external tool at all
    if ($ext -eq '.zip') {
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($Archive)
            try {
                foreach ($e in $z.Entries) {
                    if ([string]::IsNullOrEmpty($e.Name)) { continue }
                    $safe = $e.FullName -replace '\.\.[\\/]', ''
                    $dest = Join-Path $Target $safe
                    $dd = [System.IO.Path]::GetDirectoryName($dest)
                    if (-not [System.IO.Directory]::Exists($dd)) { [System.IO.Directory]::CreateDirectory($dd) | Out-Null }
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
                }
            } finally { $z.Dispose() }
            return $true
        } catch { Write-Log "Built-in unzip issue ($([System.IO.Path]::GetFileName($Archive))): $($_.Exception.Message)" 'WARN' }
    }

    # 2) 7-Zip (auto-setup portable copy if missing)
    $tool = Get-Extractor
    if (($null -eq $tool -or $tool.kind -eq 'rar') -and -not $Script:SevenZipTried) {
        $Script:SevenZipTried = $true      # only try the auto setup once per run
        $msg = Install-SevenZip
        Write-Log "7-Zip setup: $msg"
        $t2 = Get-Extractor
        if ($t2 -and $t2.kind -ne 'rar') { $tool = $t2 }
    }
    if ($tool) {
        try {
            if ($tool.kind -eq 'rar') {
                Write-Log 'Using WinRAR as fallback (7-Zip not available).' 'WARN'
                & $tool.path x -ibck -y $Archive "$Target\" | Out-Null
            } else {
                & $tool.path x $Archive "-o$Target" -y -bso0 -bsp0 | Out-Null
            }
            $any = @([System.IO.Directory]::GetFiles($Target, '*', [System.IO.SearchOption]::AllDirectories)).Count
            if ($any -gt 0) { return $true }
        } catch { Write-Log "Extractor failed: $($_.Exception.Message)" 'WARN' }
    }
    return $false
}

function Expand-AllArchives {
    param([switch]$Force)
    $report = New-Object System.Collections.Generic.List[string]
    try {
        $files = @()
        try { $files = [System.IO.Directory]::GetFiles($PacksDir, '*', [System.IO.SearchOption]::AllDirectories) } catch { }
        foreach ($a in $files) {
            $ext = [System.IO.Path]::GetExtension($a).ToLowerInvariant()
            if ($ext -ne '.zip' -and $ext -ne '.rar' -and $ext -ne '.7z') { continue }
            $base   = [System.IO.Path]::GetFileNameWithoutExtension($a)
            $target = Join-Path ([System.IO.Path]::GetDirectoryName($a)) $base   # folder next to the zip
            $stamp  = Join-Path $target '.extracted.txt'
            $fi     = New-Object System.IO.FileInfo($a)
            $sig    = ('{0}|{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks)
            if (-not $Force -and [System.IO.Directory]::Exists($target) -and [System.IO.File]::Exists($stamp)) {
                $old = ''
                try { $old = ([System.IO.File]::ReadAllText($stamp) -split "`r?`n")[0] } catch { }
                if ($old -eq $sig) { continue }          # same zip, already extracted -> skip
            }
            if (Expand-OneArchive -Archive $a -Target $target) {
                [System.IO.File]::WriteAllText($stamp, $sig + [Environment]::NewLine + 'Extracted by Cursor Rotator on ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + [Environment]::NewLine + 'Delete this file to force a re-extract.')
                $report.Add("Extracted once: $base")
                Write-Log "Extracted $base -> $target"
            } else {
                try {
                    if ([System.IO.Directory]::Exists($target) -and @([System.IO.Directory]::GetFileSystemEntries($target)).Count -eq 0) {
                        [System.IO.Directory]::Delete($target)      # leave no empty junk folder behind
                    }
                } catch { }
                $report.Add("FAILED - needs 7-Zip: $base$ext")
                Write-Log "Extract failed: $base$ext (set up 7-Zip from the Diagnostics tab)" 'WARN'
            }
        }
    } catch { Log-Err $_ 'Expand-AllArchives' }
    return , ([object[]]$report.ToArray())
}

# ---------- Apply ----------
# ---------- Smart fill: never mix a theme with Windows default cursors ----------
$Script:FillFrom = [ordered]@{
    'Help'        = @('Arrow')
    'AppStarting' = @('Wait','Arrow')
    'Wait'        = @('AppStarting','Arrow')
    'Crosshair'   = @('Arrow')
    'IBeam'       = @('Arrow')
    'NWPen'       = @('Crosshair','Arrow')
    'No'          = @('Arrow')
    'SizeNS'      = @('SizeWE','SizeAll','Arrow')
    'SizeWE'      = @('SizeNS','SizeAll','Arrow')
    'SizeNWSE'    = @('SizeNESW','SizeAll','Arrow')
    'SizeNESW'    = @('SizeNWSE','SizeAll','Arrow')
    'SizeAll'     = @('Arrow')
    'UpArrow'     = @('Arrow')
    'Hand'        = @('Arrow')
    'Pin'         = @('Hand','Arrow')
    'Person'      = @('Hand','Arrow')
}

function Get-FilledMap {
    param($Scheme, $Cfg)
    $out = @{}
    foreach ($k in $Scheme.map.Keys) { $out[$k] = $Scheme.map[$k] }
    $fill = Get-Prop $Cfg 'fillMissing'
    if ($null -eq $fill) { $fill = $true }
    if (-not $fill) { return $out }
    foreach ($r in $Script:Roles) {
        if ($out.ContainsKey($r.Key)) { continue }
        $srcList = $Script:FillFrom[$r.Key]
        if (-not $srcList) { continue }
        foreach ($src in $srcList) {
            if ($out.ContainsKey($src)) { $out[$r.Key] = $out[$src]; break }
        }
    }
    return $out
}

function Apply-Scheme {
    param($Scheme, $Cfg)
    if ($null -eq $Scheme) { return $false }
    try {
        $ov = Get-Prop (Get-Prop $Cfg 'overrides') $Scheme.name
        $eff = Get-FilledMap -Scheme $Scheme -Cfg $Cfg
        foreach ($r in $Script:Roles) {
            $val = $null
            $o = Get-Prop $ov $r.Key
            if ($o -and [System.IO.File]::Exists([string]$o)) { $val = [string]$o }
            if (-not $val -and $eff.ContainsKey($r.Key)) { $val = $eff[$r.Key] }
            if (-not $val) { $val = $r.Default }
            Set-ItemProperty -Path 'HKCU:\Control Panel\Cursors' -Name $r.Key -Value $val -Type ExpandString -Force -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path 'HKCU:\Control Panel\Cursors' -Name '(default)' -Value ([string]$Scheme.name) -Force -ErrorAction SilentlyContinue
        try { [CR.Native]::RefreshCursors() } catch { }
        Write-Log "Applied scheme: $($Scheme.name)"
        return $true
    } catch { Log-Err $_ 'Apply-Scheme'; return $false }
}

function Get-ActiveSchemes {
    param($All, $Cfg)
    $off = @(Get-Prop $Cfg 'disabledSchemes')
    $m = @($All)
    if ($off.Count -gt 0) { $m = @($m | Where-Object { $off -notcontains $_.name }) }
    # never rotate into a folder that only holds one or two stray cursors
    $good = @($m | Where-Object { $_.coverage -ge 6 })
    if ($good.Count -gt 0) { return $good }
    return $m
}
function Pick-NextScheme {
    param($Cfg)
    $act = Get-ActiveSchemes -All $Script:Schemes -Cfg $Cfg
    if ($act.Count -eq 0) { return $null }
    if ($act.Count -eq 1) { return $act[0] }
    if ($Cfg.randomOrder) {
        $pool = $act
        if ($Cfg.avoidRepeat -and $Cfg.lastScheme) {
            $p2 = @($pool | Where-Object { $_.name -ne $Cfg.lastScheme })
            if ($p2.Count -gt 0) { $pool = $p2 }
        }
        return $pool[(Get-Random -Minimum 0 -Maximum $pool.Count)]
    }
    $names = @($act | ForEach-Object { $_.name })
    $i = [array]::IndexOf($names, [string]$Cfg.lastScheme)
    return $act[(($i + 1) % $names.Count)]
}

# ---------- Autorun ----------
function Get-StartupShortcutPath { Join-Path ([Environment]::GetFolderPath('Startup')) 'CursorRotator.lnk' }
function Test-Autorun { try { return [System.IO.File]::Exists((Get-StartupShortcutPath)) } catch { return $false } }
$Script:ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { Join-Path $Root 'CursorRotator.ps1' }
function Set-Autorun {
    param([bool]$Enable)
    try {
        $lnk = Get-StartupShortcutPath
        if ($Enable) {
            $ws = New-Object -ComObject WScript.Shell
            $s = $ws.CreateShortcut($lnk)
            $s.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
            $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script:ScriptPath`" -Silent -NoBrowser"
            $s.WorkingDirectory = $env:TEMP
            $s.WindowStyle = 7
            $s.Save()
            Write-Log 'Autorun enabled.'
        } else {
            if ([System.IO.File]::Exists($lnk)) { [System.IO.File]::Delete($lnk) }
            Write-Log 'Autorun disabled.'
        }
        return $true
    } catch { Log-Err $_ 'Set-Autorun'; return $false }
}

# ---------- Cursor Store (free packs, direct download) ----------
$Script:Store = @(
    @{ id='bibata-modern-ice'; name='Bibata Modern Ice'; author='ful1e5'; desc='White, rounded, super smooth. Most popular open-source pack.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice-Windows.zip'; size='10 MB'; tags=@('Light','Minimal','Popular') }
    @{ id='bibata-modern-classic'; name='Bibata Modern Classic'; author='ful1e5'; desc='Black rounded edition of Bibata.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic-Windows.zip'; size='11 MB'; tags=@('Dark','Minimal','Popular') }
    @{ id='bibata-modern-amber'; name='Bibata Modern Amber'; author='ful1e5'; desc='Warm amber / yellow accented Bibata.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Amber-Windows.zip'; size='11 MB'; tags=@('Colorful','Minimal') }
    @{ id='bibata-original-ice'; name='Bibata Original Ice'; author='ful1e5'; desc='Sharp-edge white Bibata.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Original-Ice-Windows.zip'; size='10 MB'; tags=@('Light','Minimal') }
    @{ id='bibata-original-classic'; name='Bibata Original Classic'; author='ful1e5'; desc='Sharp-edge black Bibata.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Original-Classic-Windows.zip'; size='11 MB'; tags=@('Dark','Minimal') }
    @{ id='bibata-original-amber'; name='Bibata Original Amber'; author='ful1e5'; desc='Sharp-edge amber Bibata.'; url='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Original-Amber-Windows.zip'; size='11 MB'; tags=@('Colorful','Minimal') }
    @{ id='bibata-rainbow-modern'; name='Bibata Rainbow Modern (RGB)'; author='ful1e5'; desc='RGB rainbow colour-cycling cursors, rounded shape. Every cursor is animated.'; url='https://github.com/ful1e5/Bibata_Cursor_Rainbow/releases/download/v1.1.2/Bibata-Rainbow-Modern-Windows.zip'; size='0.4 MB'; tags=@('RGB','Animated','Colorful','Game') }
    @{ id='bibata-rainbow-original'; name='Bibata Rainbow Original (RGB)'; author='ful1e5'; desc='RGB rainbow colour-cycling cursors, sharp shape. Every cursor is animated.'; url='https://github.com/ful1e5/Bibata_Cursor_Rainbow/releases/download/v1.1.2/Bibata-Rainbow-Original-Windows.zip'; size='0.4 MB'; tags=@('RGB','Animated','Colorful','Game') }
    @{ id='bibata-extra-modern'; name='Bibata Extra Modern (4 colours)'; author='ful1e5'; desc='Bundle: DarkRed + DodgerBlue + Pink + Turquoise, rounded. 4 packs in one download.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/BibataExtra-Modern-Windows.zip'; size='1 MB'; tags=@('Colorful','Bundle','Minimal') }
    @{ id='bibata-extra-original'; name='Bibata Extra Original (4 colours)'; author='ful1e5'; desc='Bundle: DarkRed + DodgerBlue + Pink + Turquoise, sharp. 4 packs in one download.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/BibataExtra-Original-Windows.zip'; size='1 MB'; tags=@('Colorful','Bundle','Minimal') }
    @{ id='bibata-pink'; name='Bibata Modern Pink'; author='ful1e5'; desc='Pink accented Bibata.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/Bibata-Modern-Pink-Windows.zip'; size='0.3 MB'; tags=@('Colorful','Minimal') }
    @{ id='bibata-dodgerblue'; name='Bibata Modern Dodger Blue'; author='ful1e5'; desc='Bright blue accented Bibata.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/Bibata-Modern-DodgerBlue-Windows.zip'; size='0.3 MB'; tags=@('Colorful','Minimal') }
    @{ id='bibata-turquoise'; name='Bibata Modern Turquoise'; author='ful1e5'; desc='Turquoise accented Bibata.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/Bibata-Modern-Turquoise-Windows.zip'; size='0.3 MB'; tags=@('Colorful','Minimal') }
    @{ id='bibata-darkred'; name='Bibata Modern Dark Red'; author='ful1e5'; desc='Dark red accented Bibata.'; url='https://github.com/ful1e5/Bibata_Extra_Cursor/releases/download/v1.0.1/Bibata-Modern-DarkRed-Windows.zip'; size='0.3 MB'; tags=@('Colorful','Dark') }
    @{ id='googledot-blue'; name='GoogleDot Blue'; author='ful1e5'; desc='Minimal Google-style dot cursor, blue.'; url='https://github.com/ful1e5/Google_Cursor/releases/download/v2.0.0/GoogleDot-Blue-Windows.zip'; size='0.9 MB'; tags=@('Minimal','Colorful') }
    @{ id='googledot-black'; name='GoogleDot Black'; author='ful1e5'; desc='Minimal Google-style dot cursor, black.'; url='https://github.com/ful1e5/Google_Cursor/releases/download/v2.0.0/GoogleDot-Black-Windows.zip'; size='0.9 MB'; tags=@('Minimal','Dark') }
    @{ id='googledot-white'; name='GoogleDot White'; author='ful1e5'; desc='Minimal Google-style dot cursor, white.'; url='https://github.com/ful1e5/Google_Cursor/releases/download/v2.0.0/GoogleDot-White-Windows.zip'; size='0.9 MB'; tags=@('Minimal','Light') }
    @{ id='googledot-red'; name='GoogleDot Red'; author='ful1e5'; desc='Minimal Google-style dot cursor, red.'; url='https://github.com/ful1e5/Google_Cursor/releases/download/v2.0.0/GoogleDot-Red-Windows.zip'; size='0.8 MB'; tags=@('Minimal','Colorful') }
    @{ id='macos-black'; name='macOS Cursors (Black)'; author='ful1e5'; desc='Clean Apple-style cursor set, black.'; url='https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS-Windows.zip'; size='2.7 MB'; tags=@('macOS','Dark','Minimal') }
    @{ id='macos-white'; name='macOS Cursors (White)'; author='ful1e5'; desc='Clean Apple-style cursor set, white.'; url='https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS-White-Windows.zip'; size='2.6 MB'; tags=@('macOS','Light','Minimal') }
    @{ id='notwaita-black'; name='Notwaita Black'; author='ful1e5'; desc='Adwaita-inspired modern set, black. Includes animated busy cursors.'; url='https://github.com/ful1e5/notwaita-cursor/releases/download/v1.0.0-alpha1/Notwaita-Black-Windows.zip'; size='13 MB'; tags=@('Dark','Animated','Minimal') }
    @{ id='notwaita-gray'; name='Notwaita Gray'; author='ful1e5'; desc='Adwaita-inspired modern set, gray.'; url='https://github.com/ful1e5/notwaita-cursor/releases/download/v1.0.0-alpha1/Notwaita-Gray-Windows.zip'; size='14 MB'; tags=@('Dark','Animated','Minimal') }
    @{ id='notwaita-white'; name='Notwaita White'; author='ful1e5'; desc='Adwaita-inspired modern set, white.'; url='https://github.com/ful1e5/notwaita-cursor/releases/download/v1.0.0-alpha1/Notwaita-White-Windows.zip'; size='11 MB'; tags=@('Light','Animated','Minimal') }
    @{ id='pokemon'; name='Pokemon Cursors'; author='ful1e5'; desc='Pokeball themed fun cursor set, animated loading rings. 4 sizes included.'; url='https://github.com/ful1e5/pokemon-cursor/releases/download/v2.0.0/Pokemon-Windows.zip'; size='0.3 MB'; tags=@('Game','Animated','Colorful','Fun') }
    @{ id='marathon'; name='Marathon (Bold + Regular)'; author='Woysful'; desc='Sci-fi styled cursor set with lots of animated states. Two weights included.'; url='https://github.com/Woysful/Marathon-cursor/releases/download/v1.2.1/marathon_windows.zip'; size='0.2 MB'; tags=@('Game','Animated','Dark','Bundle') }
    @{ id='modern-v2-dark'; name='Modern Cursors v2 - Dark'; author='VA5H-One'; desc='Windows 11 style refreshed cursors, dark theme.'; url='https://github.com/VA5H-One/Modern-Cursors-v2/releases/download/2.1/Modern.Cursors.v2.-.Dark.zip'; size='0.4 MB'; tags=@('Dark','Windows11','Minimal') }
    @{ id='modern-v2-light'; name='Modern Cursors v2 - Light'; author='VA5H-One'; desc='Windows 11 style refreshed cursors, light theme.'; url='https://github.com/VA5H-One/Modern-Cursors-v2/releases/download/2.1/Modern.Cursors.v2.-.Light.zip'; size='0.4 MB'; tags=@('Light','Windows11','Minimal') }
    @{ id='anime-neuro-sama'; name='Neuro-sama (Anime)'; author='ctrlcat0xx'; desc='Neuro-sama themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/neuro_sama.zip'; size='36 KB'; tags=@('Anime','Animated','Fun','Colorful') }
    @{ id='anime-ellen-joe'; name='Ellen Joe (Anime)'; author='ctrlcat0xx'; desc='Ellen Joe themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/ellen_joe.zip'; size='44 KB'; tags=@('Anime','Animated','Fun','Game') }
    @{ id='anime-kuro'; name='Kuro (Anime)'; author='ctrlcat0xx'; desc='Kuro themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/kuro.zip'; size='38 KB'; tags=@('Anime','Animated','Fun') }
    @{ id='anime-noelle'; name='Noelle (Anime)'; author='ctrlcat0xx'; desc='Noelle themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/noelle.zip'; size='34 KB'; tags=@('Anime','Animated','Fun','Game') }
    @{ id='anime-shiori'; name='Shiori Novella (Anime)'; author='ctrlcat0xx'; desc='Shiori Novella themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/shiori_novella.zip'; size='28 KB'; tags=@('Anime','Animated','Fun') }
    @{ id='anime-wanderer'; name='Wanderer (Anime)'; author='ctrlcat0xx'; desc='Wanderer themed animated character cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v2/wanderer.zip'; size='52 KB'; tags=@('Anime','Animated','Fun','Game') }
    @{ id='capitaine'; name='Capitaine Cursors (16 themes)'; author='sainnhe'; desc='Hand-drawn x-cursor classic. One download gives 16 themes: default, Gruvbox, Nord, light and dark variants.'; url='https://github.com/sainnhe/capitaine-cursors/releases/download/r5/Windows.zip'; size='3.2 MB'; tags=@('Bundle','Minimal','Light','Dark','Popular') }
    @{ id='dota2-all'; name='Dota 2 Cursors (24 themes)'; author='0443n'; desc='Every Dota 2 in-game cursor pack in one download: The International 2015-2019, Diretide, Emerald Sea and more.'; url='https://github.com/0443n/dota2-cursors/releases/download/v1.3/dota2-cursors-windows-all.zip'; size='2.6 MB'; tags=@('Game','Animated','Bundle','Colorful') }
    @{ id='dota2-default'; name='Dota 2 Default'; author='0443n'; desc='The classic Dota 2 pointer set, animated.'; url='https://github.com/0443n/dota2-cursors/releases/download/v1.3/dota2-default.zip'; size='88 KB'; tags=@('Game','Animated','Dark') }
    @{ id='dota2-ti2019'; name='Dota 2 The International 2019'; author='0443n'; desc='TI9 themed animated cursors.'; url='https://github.com/0443n/dota2-cursors/releases/download/v1.3/dota2-the-international-2019.zip'; size='116 KB'; tags=@('Game','Animated','Colorful') }
    @{ id='dota2-emerald-sea'; name='Dota 2 Emerald Sea'; author='0443n'; desc='Green Emerald Sea themed animated cursors.'; url='https://github.com/0443n/dota2-cursors/releases/download/v1.3/dota2-emerald-sea.zip'; size='101 KB'; tags=@('Game','Animated','Colorful') }
    @{ id='dota2-crystal-maiden'; name='Dota 2 Crystal Maiden'; author='0443n'; desc='Icy Crystal Maiden animated cursors.'; url='https://github.com/0443n/dota2-cursors/releases/download/v1.3/dota2-dac-2015-crystal-maiden.zip'; size='133 KB'; tags=@('Game','Animated','Light') }
    @{ id='anime-frieren'; name='Frieren'; author='ctrlcat0xx'; desc='Frieren themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/frieren.zip'; size='35 KB'; tags=@('Anime','Animated','Fun') }
    @{ id='anime-frieren-winter'; name='Frieren Winter'; author='ctrlcat0xx'; desc='Winter edition Frieren animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/frieren_winter.zip'; size='35 KB'; tags=@('Anime','Animated','Light') }
    @{ id='anime-nezuko'; name='Nezuko'; author='ctrlcat0xx'; desc='Nezuko themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/nezuko_cursor.zip'; size='37 KB'; tags=@('Anime','Animated','Colorful') }
    @{ id='anime-furina'; name='Furina'; author='ctrlcat0xx'; desc='Furina themed animated cursors, large detailed set.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/furina_2_0.zip'; size='326 KB'; tags=@('Anime','Animated','Game','Colorful') }
    @{ id='anime-camellya'; name='Camellya'; author='ctrlcat0xx'; desc='Camellya themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/camellya.zip'; size='95 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-cantarella'; name='Cantarella'; author='ctrlcat0xx'; desc='Cantarella themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/cantarella.zip'; size='52 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-changli'; name='Changli'; author='ctrlcat0xx'; desc='Changli themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/changli.zip'; size='50 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-shorekeeper'; name='Shorekeeper'; author='ctrlcat0xx'; desc='Shorekeeper themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/shorekeeper.zip'; size='52 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-carlotta'; name='Carlotta'; author='ctrlcat0xx'; desc='Carlotta themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/carlotta.zip'; size='45 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-arlechinno'; name='Arlecchino'; author='ctrlcat0xx'; desc='Arlecchino themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/arlechinno.zip'; size='40 KB'; tags=@('Anime','Animated','Dark','Game') }
    @{ id='anime-zani'; name='Zani'; author='ctrlcat0xx'; desc='Zani themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/zani.zip'; size='44 KB'; tags=@('Anime','Animated','Game') }
    @{ id='anime-mauvika'; name='Mauvika'; author='ctrlcat0xx'; desc='Mauvika themed animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/mauvika.zip'; size='49 KB'; tags=@('Anime','Animated','Game') }
    @{ id='cyberpunk'; name='Cyberpunk'; author='ctrlcat0xx'; desc='Neon cyberpunk animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/cyberpunk.zip'; size='20 KB'; tags=@('Animated','Colorful','Game','Dark') }
    @{ id='cinnamon'; name='Cinnamon'; author='ctrlcat0xx'; desc='Soft pastel animated cursor set.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/cinnamon_cursors.zip'; size='27 KB'; tags=@('Animated','Colorful','Fun','Light') }
    @{ id='felyne'; name='Felyne (No Weapon)'; author='ctrlcat0xx'; desc='Monster Hunter Felyne animated cursors.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/felyne_normal_no_weapon.zip'; size='17 KB'; tags=@('Game','Animated','Fun') }
    @{ id='win11-dark-ani'; name='Windows 11 Dark (animated)'; author='ctrlcat0xx'; desc='Windows 11 look with animated busy cursors, dark.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/windows_11_dark.zip'; size='29 KB'; tags=@('Windows11','Dark','Animated','Minimal') }
    @{ id='win11-light-ani'; name='Windows 11 Light (animated)'; author='ctrlcat0xx'; desc='Windows 11 look with animated busy cursors, light.'; url='https://github.com/ctrlcat0xx/cursors/releases/download/v1/windows_11_light.zip'; size='28 KB'; tags=@('Windows11','Light','Animated','Minimal') }
)

function Download-StoreItem {
    param([string]$Id)
    $item = $Script:Store | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $item) { return 'Pack not found in store' }
    $dest = Join-Path $PacksDir ("$($item.id).zip")
    try {
        Write-Log "Downloading $($item.name) ..."
        if ([System.IO.File]::Exists($dest)) { [System.IO.File]::Delete($dest) }
        try {
            Invoke-WebRequest -Uri $item.url -OutFile $dest -UseBasicParsing -TimeoutSec 300
        } catch {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add('User-Agent', 'CursorRotator')
            $wc.DownloadFile($item.url, $dest)
        }
        if (-not [System.IO.File]::Exists($dest) -or (New-Object System.IO.FileInfo($dest)).Length -lt 1024) {
            return "Download failed for $($item.name)"
        }
        $target = Join-Path $PacksDir $item.id
        if (Expand-OneArchive -Archive $dest -Target $target) {
            $fi2 = New-Object System.IO.FileInfo($dest)
            [System.IO.File]::WriteAllText((Join-Path $target '.extracted.txt'), ('{0}|{1}' -f $fi2.Length, $fi2.LastWriteTimeUtc.Ticks))
            Write-Log "Installed $($item.name)"
            return "Installed: $($item.name)"
        }
        return "Downloaded but could not extract $($item.name)"
    } catch {
        Log-Err $_ 'Download-StoreItem'
        return "Download failed: $($_.Exception.Message)"
    }
}

function Get-StoreTagList {
    $set = New-Object System.Collections.Generic.List[string]
    foreach ($i in $Script:Store) { foreach ($t in $i.tags) { if ($set -notcontains $t) { $set.Add([string]$t) } } }
    return , ([object[]](@($set) | Sort-Object))
}

function Get-PackTags {
    param([string]$Name, [int]$AniCount = 0)
    $t = New-Object System.Collections.Generic.List[string]
    if ($AniCount -gt 0) { $t.Add('Animated') } else { $t.Add('Static') }
    $l = $Name.ToLowerInvariant()
    if ($l -match 'rainbow|rgb') { $t.Add('RGB') }
    if ($l -match 'dark|black|classic|noir') { $t.Add('Dark') }
    if ($l -match 'white|light|ice') { $t.Add('Light') }
    if ($l -match 'red|blue|pink|amber|green|turquoise|purple|orange|yellow|colou?r') { $t.Add('Colorful') }
    if ($l -match 'anime|neuro|noelle|kuro|shiori|wanderer|ellen') { $t.Add('Anime') }
    if ($l -match 'pokemon|marathon|game|valorant|genshin') { $t.Add('Game') }
    if ($l -match 'macos|apple') { $t.Add('macOS') }
    if ($l -match 'googledot|dot|minimal|bibata|notwaita') { $t.Add('Minimal') }
    return , ([object[]]$t.ToArray())
}

function Get-StoreByTag {
    param([string]$Tag)
    if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag -eq 'all') { return , ([object[]]$Script:Store) }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($i in $Script:Store) {
        foreach ($t in $i.tags) { if ([string]$t -ieq $Tag) { $out.Add($i); break } }
    }
    return , ([object[]]$out.ToArray())
}

function Test-StoreInstalled {
    param([string]$Id)
    return [System.IO.Directory]::Exists((Join-Path $PacksDir $Id))
}

function Download-StoreMany {
    param([string[]]$Ids)
    $okN = 0; $failN = 0; $skipN = 0
    $msgs = New-Object System.Collections.Generic.List[string]
    foreach ($id in $Ids) {
        $id = ([string]$id).Trim()
        if (-not $id) { continue }
        if (Test-StoreInstalled -Id $id) { $skipN++; continue }
        $r = Download-StoreItem -Id $id
        if ($r -like 'Installed*') { $okN++ } else { $failN++; $msgs.Add($r) }
    }
    $txt = "Downloaded $okN pack(s)"
    if ($skipN -gt 0) { $txt += ", $skipN already installed" }
    if ($failN -gt 0) { $txt += ", $failN failed" }
    return $txt
}

# ---------- Pack management: rename / delete / build / import ----------
function Get-SafeName {
    param([string]$Name)
    $n = [string]$Name
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $n = $n.Replace([string]$c, '') }
    $n = $n.Trim().Trim('.')
    if ([string]::IsNullOrWhiteSpace($n)) { $n = 'pack' }
    if ($n.Length -gt 80) { $n = $n.Substring(0, 80) }
    return $n
}

function Test-InsidePacks {
    param([string]$Path)
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $base = [System.IO.Path]::GetFullPath($PacksDir)
        return $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and $full.Length -gt $base.Length
    } catch { return $false }
}

function Get-PackFolder {
    param([string]$Name)                       # relative scheme name, e.g. "bibata\Bibata-Modern-Ice-Windows"
    $p = Join-Path $PacksDir $Name
    if (-not (Test-InsidePacks $p)) { return $null }
    if (-not [System.IO.Directory]::Exists($p)) { return $null }
    return $p
}

function Update-ConfigForRename {
    param([string]$Old, [string]$New)
    $off = New-Object System.Collections.Generic.List[string]
    foreach ($x in @(Get-Prop $Script:Cfg 'disabledSchemes')) {
        if (-not $x) { continue }
        $v = [string]$x
        if ($v -eq $Old) { $v = $New } elseif ($v.StartsWith($Old + [char]92)) { $v = $New + $v.Substring($Old.Length) }
        $off.Add($v)
    }
    Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]$off.ToArray()) -Force
    $ov = Get-Prop $Script:Cfg 'overrides'
    if ($ov) {
        foreach ($pr in @($ov.PSObject.Properties)) {
            $n = [string]$pr.Name
            if ($n -eq $Old -or $n.StartsWith($Old + [char]92)) {
                $newName = $New + $n.Substring($Old.Length)
                Add-Member -InputObject $ov -NotePropertyName $newName -NotePropertyValue $pr.Value -Force
                $ov.PSObject.Properties.Remove($n)
            }
        }
    }
    if ([string]$Script:Cfg.lastScheme -eq $Old) { $Script:Cfg.lastScheme = $New }
    Save-Config $Script:Cfg
}

function Rename-Pack {
    param([string]$Name, [string]$NewName)
    try {
        $src = Get-PackFolder -Name $Name
        if (-not $src) { return 'Pack not found' }
        $parent = [System.IO.Path]::GetDirectoryName($src)
        $safe = Get-SafeName $NewName
        $dst = Join-Path $parent $safe
        if ([System.IO.Directory]::Exists($dst)) { return "A pack called '$safe' already exists" }
        [System.IO.Directory]::Move($src, $dst)
        $newRel = $dst.Substring($PacksDir.Length).Trim([char]92, [char]47)
        Update-ConfigForRename -Old $Name -New $newRel
        Write-Log "Renamed pack '$Name' -> '$newRel'"
        return "Renamed to: $safe"
    } catch { Log-Err $_ 'Rename-Pack'; return "Rename failed: $($_.Exception.Message)" }
}

function Remove-Pack {
    param([string]$Name, [bool]$WithArchive = $true)
    try {
        $dir = Get-PackFolder -Name $Name
        if (-not $dir) { return 'Pack not found' }
        [System.IO.Directory]::Delete($dir, $true)
        $deleted = 1
        if ($WithArchive) {
            $leaf = [System.IO.Path]::GetFileName($dir)
            $parent = [System.IO.Path]::GetDirectoryName($dir)
            foreach ($ext in @('.zip', '.7z', '.rar')) {
                $a = Join-Path $parent ($leaf + $ext)
                if ([System.IO.File]::Exists($a) -and (Test-InsidePacks $a)) { [System.IO.File]::Delete($a); $deleted++ }
            }
        }
        # forget it in the config too
        $off = @(Get-Prop $Script:Cfg 'disabledSchemes') | Where-Object { $_ -and ([string]$_ -ne $Name) }
        Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]@($off)) -Force
        $ov = Get-Prop $Script:Cfg 'overrides'
        if ($ov -and $ov.PSObject.Properties[$Name]) { $ov.PSObject.Properties.Remove($Name) }
        Save-Config $Script:Cfg
        Write-Log "Deleted pack '$Name' ($deleted item(s))"
        return "Deleted: $Name"
    } catch { Log-Err $_ 'Remove-Pack'; return "Delete failed: $($_.Exception.Message)" }
}

function New-CustomPack {
    # $Map is a hashtable  RoleKey -> source cursor file
    param([string]$Name, $Map)
    try {
        $safe = Get-SafeName $Name
        if (-not [System.IO.Directory]::Exists($CustomDir)) { [System.IO.Directory]::CreateDirectory($CustomDir) | Out-Null }
        $dir = Join-Path $CustomDir $safe
        if ([System.IO.Directory]::Exists($dir)) { return "A custom pack called '$safe' already exists - pick another name" }
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        $n = 0
        foreach ($r in $Script:Roles) {
            $src = $null
            if ($Map -is [hashtable]) { if ($Map.ContainsKey($r.Key)) { $src = [string]$Map[$r.Key] } }
            else { $src = [string](Get-Prop $Map $r.Key) }
            if (-not $src) { continue }
            if (-not [System.IO.File]::Exists($src)) { continue }
            if (-not (Test-InsidePacks $src)) { continue }
            $ext = [System.IO.Path]::GetExtension($src).ToLowerInvariant()
            if ($ext -ne '.cur' -and $ext -ne '.ani') { continue }
            [System.IO.File]::Copy($src, (Join-Path $dir ($r.Key + $ext)), $true)
            $n++
        }
        if ($n -eq 0) { [System.IO.Directory]::Delete($dir, $true); return 'Nothing was selected, so no pack was created' }
        [System.IO.File]::WriteAllText((Join-Path $dir 'pack.txt'),
            ("Custom pack '{0}' built with Cursor Rotator on {1}. {2} cursor(s)." -f $safe, (Get-Date -Format 'yyyy-MM-dd HH:mm'), $n))
        Write-Log "Created custom pack '$safe' with $n cursor(s)"
        return "Created custom pack '$safe' with $n cursor(s)"
    } catch { Log-Err $_ 'New-CustomPack'; return "Could not create pack: $($_.Exception.Message)" }
}

function Save-UploadedFile {
    # returns a status string; $Data is base64
    param([string]$FileName, [string]$Folder, [string]$Data)
    try {
        $bytes = [Convert]::FromBase64String($Data)
        if ($bytes.Length -lt 8) { return 'File is empty' }
        if ($bytes.Length -gt 300MB) { return 'File is too large (limit 300 MB)' }
        $leaf = Get-SafeName ([System.IO.Path]::GetFileName($FileName))
        $ext  = [System.IO.Path]::GetExtension($leaf).ToLowerInvariant()
        if ($ext -eq '.zip' -or $ext -eq '.7z' -or $ext -eq '.rar') {
            $dest = Join-Path $PacksDir $leaf
            [System.IO.File]::WriteAllBytes($dest, $bytes)
            $target = Join-Path $PacksDir ([System.IO.Path]::GetFileNameWithoutExtension($leaf))
            if (Expand-OneArchive -Archive $dest -Target $target) {
                $fi = New-Object System.IO.FileInfo($dest)
                [System.IO.File]::WriteAllText((Join-Path $target '.extracted.txt'), ('{0}|{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks))
                return "Added: $leaf"
            }
            return "Saved $leaf but could not unpack it - install 7-Zip from the Diagnostics tab and press Rescan"
        }
        if ($ext -eq '.cur' -or $ext -eq '.ani' -or $ext -eq '.inf') {
            $folderName = Get-SafeName $(if ($Folder) { $Folder } else { 'My cursors' })
            $dir = Join-Path $PacksDir $folderName
            if (-not [System.IO.Directory]::Exists($dir)) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
            [System.IO.File]::WriteAllBytes((Join-Path $dir $leaf), $bytes)
            return "Added: $folderName\$leaf"
        }
        return "Ignored '$leaf' - only .zip, .7z, .rar, .cur, .ani and .inf are accepted"
    } catch { Log-Err $_ 'Save-UploadedFile'; return "Upload failed: $($_.Exception.Message)" }
}

function Invoke-RemoveEverything {
    # the big red button: put Windows back the way it was
    param([bool]$DeletePacks = $false)
    $done = New-Object System.Collections.Generic.List[string]
    try { Restore-OriginalScheme | Out-Null; $done.Add('original cursors restored') } catch { }
    try { Set-Autorun -Enable $false | Out-Null; $done.Add('autorun removed') } catch { }
    try {
        foreach ($f in @($ConfigFile, $BackupFile)) { if ([System.IO.File]::Exists($f)) { [System.IO.File]::Delete($f) } }
        $done.Add('settings cleared')
    } catch { }
    if ($DeletePacks) {
        try {
            $n = 0
            foreach ($d in [System.IO.Directory]::GetDirectories($PacksDir)) { [System.IO.Directory]::Delete($d, $true); $n++ }
            foreach ($f in [System.IO.Directory]::GetFiles($PacksDir)) {
                if ([System.IO.Path]::GetFileName($f) -ne '_PUT-YOUR-ZIP-FILES-HERE.txt') { [System.IO.File]::Delete($f); $n++ }
            }
            $done.Add("$n pack item(s) deleted")
        } catch { Log-Err $_ 'Invoke-RemoveEverything/packs' }
    }
    $Script:Cfg = Get-DefaultConfig
    $Script:Schemes = Get-Schemes
    Write-Log ('Remove everything: ' + ($done -join ', '))
    return ('Done - ' + ($done -join ', '))
}

# ============================================================
#  STARTUP
# ============================================================
function Clear-DownloadFlag {
    # Windows marks every file that came out of a downloaded zip with a hidden
    # "Zone.Identifier" stream, which triggers "The publisher could not be verified".
    # Clearing it for our own folder makes that prompt disappear for good.
    param([string]$Folder = $Root, [switch]$Deep)
    $n = 0
    if ($null -eq $Script:HasUnblock) { $Script:HasUnblock = [bool](Get-Command Unblock-File -ErrorAction SilentlyContinue) }
    if (-not $Script:HasUnblock) { return 0 }
    try {
        $targets = New-Object System.Collections.Generic.List[string]
        foreach ($f in [System.IO.Directory]::GetFiles($Folder)) { $targets.Add($f) }
        foreach ($sub in @('docs', 'tools')) {
            $d = Join-Path $Folder $sub
            if ([System.IO.Directory]::Exists($d)) { foreach ($f in [System.IO.Directory]::GetFiles($d)) { $targets.Add($f) } }
        }
        if ($Deep) {
            foreach ($d in (Get-AllDirectories -Base $Folder)) {
                foreach ($f in [System.IO.Directory]::GetFiles($d)) { $targets.Add($f) }
            }
        }
        foreach ($f in $targets) {
            try { Unblock-File -LiteralPath $f -ErrorAction SilentlyContinue; $n++ } catch { }
        }
    } catch { }
    return $n
}

Write-Log '--- Cursor Rotator starting ---'
try { $unb = Clear-DownloadFlag; if ($unb -gt 0) { Write-Log "Checked $unb file(s) for the Windows 'downloaded from internet' flag." } } catch { }
Backup-OriginalScheme
$Script:Cfg = Load-Config
$Script:ExtractReport = Expand-AllArchives
$Script:Schemes = Get-Schemes
Write-Log ("Scan: {0} scheme(s), {1} folder(s), {2} cursor file(s)." -f @($Script:Schemes).Count, $Script:Diag.folders, $Script:Diag.cursorFiles)

# ---------- command line one-shot mode ----------
if ($List) {
    Write-Host ''
    Write-Host ('{0,-4} {1,-10} {2}' -f '#', 'Mapped', 'Pack name')
    $i = 0
    foreach ($s2 in $Script:Schemes) {
        $i++
        $off = @(Get-Prop $Script:Cfg 'disabledSchemes') -contains $s2.name
        Write-Host ('{0,-4} {1,-10} {2}{3}' -f $i, ("$($s2.coverage)/$($s2.total)"), $s2.name, $(if ($off) { '   [OFF]' } else { '' }))
    }
    Write-Host ''
    return
}
if ($Every -gt 0) {
    if ($Every -lt 5) { $Every = 5 }
    Add-Member -InputObject $Script:Cfg -NotePropertyName 'intervalSeconds' -NotePropertyValue ([double]$Every) -Force
    Save-Config $Script:Cfg
    Write-Host "Rotation interval set to $Every second(s)."
    return
}
if ($Unblock) {
    $n = Clear-DownloadFlag -Deep
    Write-Host ''
    Write-Host ("  Unblocked {0} file(s) in:" -f $n) -ForegroundColor Green
    Write-Host ("  {0}" -f $Root)
    Write-Host ''
    Write-Host '  Windows will not ask "The publisher could not be verified" for this folder any more.'
    Write-Host ''
    return
}
if ($Setup7Zip) { Write-Host (Install-SevenZip); return }
if ($Download -eq 'tags') {
    Write-Host ''
    Write-Host 'Store categories (use with -Tag):'
    $tl = Get-StoreTagList
    foreach ($t in $tl) {
        $bt = Get-StoreByTag -Tag $t
        Write-Host ('  {0,-12} {1} pack(s)' -f $t, @($bt).Count)
    }
    Write-Host ''
    return
}
if ($Download -eq 'list') {
    $sel = Get-StoreByTag -Tag $Tag
    Write-Host ''
    if ($Tag) { Write-Host ("Store packs tagged '{0}':" -f $Tag) } else { Write-Host 'All store packs:' }
    Write-Host ('{0,-24} {1,-32} {2,-9} {3,-10} {4}' -f 'ID', 'Name', 'Size', 'Installed', 'Tags')
    foreach ($i in $sel) {
        $ins = if ([System.IO.Directory]::Exists((Join-Path $PacksDir $i.id))) { 'yes' } else { 'no' }
        Write-Host ('{0,-24} {1,-32} {2,-9} {3,-10} {4}' -f $i.id, $i.name, $i.size, $ins, ($i.tags -join ', '))
    }
    Write-Host ''
    Write-Host ("{0} pack(s). Tip: -Download tags   |   -DownloadAll -Tag RGB" -f @($sel).Count)
    Write-Host ''
    return
}
if ($Download) {
    Write-Host (Download-StoreItem -Id $Download)
    $Script:Schemes = Get-Schemes
    Write-Host ("Now {0} pack(s) available." -f @($Script:Schemes).Count)
    return
}
if ($DownloadAll) {
    $n = 0
    $sel = Get-StoreByTag -Tag $Tag
    if ($Tag) { Write-Host ("Downloading store packs tagged '{0}' ({1} found)..." -f $Tag, @($sel).Count) -ForegroundColor Cyan }
    foreach ($i in $sel) {
        if ([System.IO.Directory]::Exists((Join-Path $PacksDir $i.id))) { Write-Host ("Skip (already there): {0}" -f $i.name); continue }
        Write-Host ("Downloading {0} ({1}) ..." -f $i.name, $i.size) -NoNewline
        $r = Download-StoreItem -Id $i.id
        if ($r -like 'Installed*') { Write-Host ' OK' -ForegroundColor Green; $n++ } else { Write-Host (' -> ' + $r) -ForegroundColor Yellow }
    }
    $Script:Schemes = Get-Schemes
    Write-Host ''
    Write-Host ("Done. {0} new pack(s) downloaded. Total packs now: {1}" -f $n, @($Script:Schemes).Count) -ForegroundColor Cyan
    return
}
if ($RemoveAll) {
    Write-Host ''
    Write-Host '  REMOVE EVERYTHING' -ForegroundColor Yellow
    Write-Host '  This restores your original Windows cursors, removes the autorun entry'
    Write-Host '  and deletes the app settings.'
    if ($DeletePacks) { Write-Host '  Every downloaded cursor pack will also be deleted.' -ForegroundColor Red }
    Write-Host ''
    $ans = Read-Host '  Type YES to continue'
    if ($ans -ne 'YES') { Write-Host '  Cancelled.'; return }
    Write-Host (Invoke-RemoveEverything -DeletePacks ([bool]$DeletePacks))
    Write-Host '  You can now delete the app folder if you want. Nothing is left behind.' -ForegroundColor Green
    return
}
if ($Restore) { Restore-OriginalScheme | Out-Null; Write-Host 'Windows default cursors restored.'; return }
if ($Apply) {
    $hit = $Script:Schemes | Where-Object { $_.name -eq $Apply } | Select-Object -First 1
    if (-not $hit) { $hit = $Script:Schemes | Where-Object { $_.name -like "*$Apply*" } | Select-Object -First 1 }
    if ($hit) {
        Apply-Scheme -Scheme $hit -Cfg $Script:Cfg | Out-Null
        $Script:Cfg.lastScheme = $hit.name; Save-Config $Script:Cfg
        Write-Host "Applied: $($hit.name)"
    } else { Write-Host "Pack not found: $Apply" }
    return
}

$Script:Status = 'Ready'
$Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
$Script:ShouldExit = $false

function Do-Rotate {
    $s = Pick-NextScheme -Cfg $Script:Cfg
    if ($null -eq $s) { $Script:Status = 'No cursor packs found'; return $null }
    if (Apply-Scheme -Scheme $s -Cfg $Script:Cfg) {
        $Script:Cfg.lastScheme = $s.name
        Save-Config $Script:Cfg
        $Script:Status = "Applied: $($s.name)"
        $Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
        return $s.name
    }
    return $null
}
if ($Random) { $n = Do-Rotate; Write-Host $(if ($n) { "Applied: $n" } else { 'No packs available' }); return }
if ($Rescan) {
    $Script:ExtractReport = Expand-AllArchives -Force
    $Script:Schemes = Get-Schemes
    Write-Host ("Rescan done: {0} pack(s), {1} cursor file(s)." -f @($Script:Schemes).Count, $Script:Diag.cursorFiles)
    return
}
if ($Script:Cfg.applyOnStart -and $Script:Cfg.enabled) { Do-Rotate | Out-Null }

# ============================================================
#  HTTP SERVER
# ============================================================
$Script:Html = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cursor Rotator - Control Panel</title>
<style>
  :root{
    --bg:#0b0e14; --panel:#141922; --panel2:#1b2230; --line:#28313f; --line2:#333e4f;
    --text:#e8eef6; --muted:#8fa0b4; --acc:#5b9dff; --acc2:#22c55e; --warn:#f59e0b; --danger:#ef4444;
  }
  *{box-sizing:border-box}
  body{margin:0;font-family:"Segoe UI",system-ui,Arial,sans-serif;background:var(--bg);color:var(--text)}
  header{position:sticky;top:0;z-index:20;background:rgba(13,17,24,.96);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:12px 20px;display:flex;align-items:center;gap:12px;flex-wrap:wrap}
  h1{font-size:17px;margin:0;letter-spacing:.3px;white-space:nowrap}
  .dot{width:10px;height:10px;border-radius:50%;background:var(--acc2);box-shadow:0 0 10px var(--acc2)}
  .dot.off{background:var(--warn);box-shadow:0 0 10px var(--warn)}
  .spacer{flex:1}
  .wrap{padding:20px;max-width:1280px;margin:0 auto}
  .grid{display:grid;grid-template-columns:330px 1fr;gap:18px;align-items:start}
  @media(max-width:920px){.grid{grid-template-columns:1fr}}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px;margin-bottom:16px}
  .card h2{font-size:12px;text-transform:uppercase;letter-spacing:1.2px;color:var(--muted);margin:0 0 12px}
  label{display:block;font-size:13px;color:var(--muted);margin:10px 0 4px}
  input[type=number],input[type=text],select{width:100%;background:var(--panel2);border:1px solid var(--line2);color:var(--text);border-radius:9px;padding:9px 10px;font-size:14px;outline:none}
  input:focus,select:focus{border-color:var(--acc)}
  .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
  .btn{background:var(--panel2);border:1px solid var(--line2);color:var(--text);padding:9px 13px;border-radius:9px;cursor:pointer;font-size:13px;transition:.13s;white-space:nowrap}
  .btn:hover{border-color:var(--acc)}
  .btn:disabled{opacity:.5;cursor:not-allowed}
  .btn.p{background:var(--acc);border-color:var(--acc);color:#04121f;font-weight:600}
  .btn.g{background:var(--acc2);border-color:var(--acc2);color:#04120a;font-weight:600}
  .btn.d{background:transparent;border-color:var(--danger);color:#ff9c9c}
  .btn.sm{padding:6px 10px;font-size:12px}
  .sw{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:9px 0;border-bottom:1px dashed var(--line)}
  .sw:last-child{border-bottom:none}
  .sw span{font-size:13px}
  .toggle{position:relative;width:44px;height:24px;flex:0 0 44px;margin:0}
  .toggle input{opacity:0;width:0;height:0}
  .slider{position:absolute;inset:0;background:#3a4453;border-radius:99px;cursor:pointer;transition:.2s}
  .slider:before{content:"";position:absolute;height:18px;width:18px;left:3px;top:3px;background:#fff;border-radius:50%;transition:.2s}
  .toggle input:checked + .slider{background:var(--acc2)}
  .toggle input:checked + .slider:before{transform:translateX(20px)}
  .tabs{display:flex;gap:8px;align-items:center;margin-bottom:14px;flex-wrap:wrap}
  .tab{background:transparent;border:1px solid var(--line);color:var(--muted);padding:8px 14px;border-radius:9px;cursor:pointer;font-size:13px}
  .tab.on{background:var(--panel2);color:var(--text);border-color:var(--acc)}
  .cnt{background:var(--acc);color:#04121f;border-radius:99px;padding:1px 7px;font-size:11px;font-weight:700;margin-left:6px}
  .schemes{display:grid;grid-template-columns:repeat(auto-fill,minmax(268px,1fr));gap:12px}
  .sc{background:var(--panel2);border:1px solid var(--line);border-radius:12px;padding:12px;transition:.13s;position:relative}
  .sc:hover{border-color:var(--line2)}
  .sc.active{border-color:var(--acc2);box-shadow:0 0 0 1px var(--acc2) inset}
  .sc.off{opacity:.5}
  .sc .nm{font-size:13px;font-weight:600;word-break:break-word;line-height:1.35}
  .sc .mt{font-size:11px;color:var(--muted);margin:6px 0 8px}
  .prev{display:flex;gap:6px;flex-wrap:wrap;min-height:44px;margin:8px 0}
  .pv{width:42px;height:42px;background:#0c1017;border:1px solid var(--line);border-radius:8px;display:flex;align-items:center;justify-content:center;position:relative}
  .pv img{max-width:30px;max-height:30px;image-rendering:auto}
  .pv b{position:absolute;bottom:-1px;right:1px;font-size:8px;color:var(--muted);font-weight:600}
  .mapimg{width:36px;height:36px;background:#0c1017;border:1px solid var(--line);border-radius:8px;display:flex;align-items:center;justify-content:center}
  .mapimg img{max-width:28px;max-height:28px}
  .chip{font-size:10px;padding:2px 7px;border-radius:99px;border:1px solid var(--line2);color:var(--muted)}
  .bar{height:5px;border-radius:99px;background:#2a3342;overflow:hidden;margin:6px 0}
  .bar i{display:block;height:100%;background:linear-gradient(90deg,var(--acc),var(--acc2))}
  table{width:100%;border-collapse:collapse;font-size:13px}
  td,th{padding:7px 6px;border-bottom:1px solid var(--line);text-align:left;vertical-align:middle}
  th{color:var(--muted);font-weight:500;font-size:12px}
  .pill{background:var(--panel2);border:1px solid var(--line);border-radius:99px;padding:6px 12px;font-size:12px;white-space:nowrap}
  .status{font-size:12px;color:var(--muted);line-height:1.7}
  dialog{background:var(--panel);color:var(--text);border:1px solid var(--line2);border-radius:14px;max-width:900px;width:95%;padding:0}
  dialog::backdrop{background:rgba(0,0,0,.65)}
  .dh{padding:14px 18px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:10px}
  .db{padding:8px 18px 14px;max-height:62vh;overflow:auto}
  .df{padding:12px 18px;border-top:1px solid var(--line);display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap}
  .toast{position:fixed;right:18px;bottom:18px;z-index:50;background:var(--panel2);border:1px solid var(--acc);padding:11px 16px;border-radius:10px;font-size:13px;opacity:0;transform:translateY(10px);transition:.25s;pointer-events:none;max-width:420px}
  .toast.on{opacity:1;transform:none}
  .empty{text-align:center;color:var(--muted);padding:36px 10px;font-size:14px;line-height:1.9}
  code{background:#080b11;padding:2px 6px;border-radius:5px;color:#9fd1ff;font-size:12px}
  pre{background:#080b11;border:1px solid var(--line);border-radius:9px;padding:10px;font-size:12px;overflow:auto;max-height:240px;color:#a8b6c6}
  .st{display:flex;gap:12px;align-items:center;background:var(--panel2);border:1px solid var(--line);border-radius:12px;padding:12px;margin-bottom:10px}
  .st .info{flex:1;min-width:0}
  .ok{color:var(--acc2);font-size:12px;font-weight:600}
  .qk{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
  .qk button{background:var(--panel2);border:1px solid var(--line2);color:var(--muted);border-radius:8px;padding:5px 10px;font-size:12px;cursor:pointer}
  .qk button:hover{color:var(--text);border-color:var(--acc)}

.badge{display:inline-block;font-size:9px;font-weight:800;letter-spacing:.5px;padding:2px 6px;border-radius:999px;
  background:#243045;color:#9fb3d0;border:1px solid #33415c}
.badge.on{background:#123524;color:#4ade80;border-color:#1c5138}
.badge.offb{background:#3a1d24;color:#fb7185;border-color:#5c2a34}
.badge.anim{background:#2a1f45;color:#c4b5fd;border-color:#4c3a80}
.badge.rgb{background:linear-gradient(90deg,#ef4444,#f59e0b,#22c55e,#3b82f6,#a855f7);color:#fff;border:none;text-shadow:0 1px 2px rgba(0,0,0,.5)}
.badge.anime{background:#3d1f33;color:#f9a8d4;border-color:#6b3355}
.badge.dark{background:#1b2130;color:#94a3b8;border-color:#2f3a4d}
.badge.light{background:#e2e8f0;color:#1f2937;border-color:#cbd5e1}
.chiprow{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:6px}
.fchip{cursor:pointer;font-size:11px;padding:5px 10px;border-radius:999px;background:#182031;color:#9fb3d0;
  border:1px solid #2b3648}
.fchip:hover{background:#1e293b;color:#e2e8f0}
.fchip.on{background:#2563eb;color:#fff;border-color:#2563eb}
.fchip b{opacity:.75;font-weight:700}
.selbox{width:17px;height:17px;accent-color:#2563eb;cursor:pointer;flex:none;margin-right:4px}
.dlprog{margin:0 0 12px;padding:10px;border:1px solid #2b3648;border-radius:10px;background:#141c2b}
.dlprog .bar{height:8px;background:#1e293b;border-radius:999px;overflow:hidden;margin-bottom:6px}
.dlprog .bar i{display:block;height:100%;background:linear-gradient(90deg,#22c55e,#3b82f6);transition:width .3s}

/* --- v1.0 --- */
.drop{border:2px dashed #33415c;border-radius:14px;padding:16px;text-align:center;background:#121a27;margin-bottom:14px;transition:.15s}
.drop.hot{border-color:#5b9dff;background:#16233a}
.drop h3{margin:0 0 4px;font-size:14px}
.drop p{margin:0 0 10px;font-size:12px;color:#8fa0b4}
.uprog{height:8px;background:#1e293b;border-radius:999px;overflow:hidden;margin-top:10px;display:none}
.uprog i{display:block;height:100%;width:0;background:linear-gradient(90deg,#22c55e,#3b82f6);transition:width .25s}
.menu{position:relative;display:inline-block}
.menu>.mbtn{background:#1b2230;border:1px solid #333e4f;color:#cbd5e1;border-radius:9px;padding:6px 10px;font-size:13px;cursor:pointer}
.menu>.mbtn:hover{border-color:#5b9dff}
.mlist{position:absolute;right:0;top:110%;z-index:40;background:#161d2a;border:1px solid #33415c;border-radius:10px;
  min-width:190px;padding:5px;display:none;box-shadow:0 12px 30px rgba(0,0,0,.5)}
.mlist.on{display:block}
.mlist button{display:block;width:100%;text-align:left;background:none;border:none;color:#e2e8f0;padding:8px 10px;font-size:13px;border-radius:7px;cursor:pointer}
.mlist button:hover{background:#22304a}
.mlist button.dgr{color:#fca5a5}
.mlist button.dgr:hover{background:#3b1d24}
.pv.ani{outline:1px solid rgba(139,92,246,.55)}
.pv .lbl{position:absolute;bottom:-2px;right:-2px;font-size:8px;background:#7c3aed;color:#fff;border-radius:4px;padding:0 3px}
.builder{display:grid;grid-template-columns:150px 44px 1fr 84px;gap:8px;align-items:center;padding:6px 0;border-bottom:1px dashed #28313f}
.builder:last-child{border-bottom:none}
.builder .rl{font-size:12px;color:#cbd5e1}
.builder .pvbox{width:40px;height:40px;display:flex;align-items:center;justify-content:center;background:#0f1520;border:1px solid #28313f;border-radius:8px}
.builder .pvbox img{max-width:32px;max-height:32px;image-rendering:pixelated}
.builder select{font-size:12px;padding:6px 8px}
.danger{border-color:#5c2a34 !important;background:#180f13 !important}
.danger h2{color:#fca5a5}
.hint{font-size:11px;color:#8fa0b4}
.pvwrap{position:relative}
</style>
</head>
<body>
<header>
  <div class="dot" id="dot"></div>
  <h1>Cursor Rotator</h1>
  <span class="pill" id="nextPill">Next: --</span>
  <span class="pill" id="curPill">Current: --</span>
  <div class="spacer"></div>
  <button class="btn g" onclick="api('/api/random')">Change Now</button>
  <button class="btn" onclick="api('/api/rescan')">Rescan</button>
  <button class="btn d" onclick="api('/api/restore')">Restore Windows Default</button>
</header>

<div class="wrap">
<div class="grid">
  <!-- LEFT -->
  <div>
    <div class="card">
      <h2>Rotation</h2>
      <div class="sw"><span>Auto rotation</span>
        <label class="toggle"><input type="checkbox" id="enabled" onchange="save()"><span class="slider"></span></label></div>

      <label>Change cursor every</label>
      <div class="row">
        <input type="number" id="ivVal" min="1" step="1" value="30" style="flex:1" onchange="save()">
        <select id="ivUnit" style="width:118px" onchange="save()">
          <option value="1">Seconds</option>
          <option value="60">Minutes</option>
          <option value="3600">Hours</option>
        </select>
      </div>
      <div class="qk">
        <button onclick="quick(10)">10s</button>
        <button onclick="quick(30)">30s</button>
        <button onclick="quick(60)">1m</button>
        <button onclick="quick(300)">5m</button>
        <button onclick="quick(900)">15m</button>
        <button onclick="quick(1800)">30m</button>
        <button onclick="quick(3600)">1h</button>
        <button onclick="quick(21600)">6h</button>
        <button onclick="quick(86400)">1 day</button>
      </div>
      <p class="status" style="margin:8px 0 0">Minimum 5 seconds.</p>

      <div class="sw" style="margin-top:8px"><span>Random order</span>
        <label class="toggle"><input type="checkbox" id="randomOrder" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span>Never repeat same pack twice</span>
        <label class="toggle"><input type="checkbox" id="avoidRepeat" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span title="If a pack has no Location/Person/Handwriting cursor, the app borrows the pack's own arrow instead of leaving a Windows cursor behind">Fill missing cursors from the same pack</span>
        <label class="toggle"><input type="checkbox" id="fillMissing" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span>Change on app start</span>
        <label class="toggle"><input type="checkbox" id="applyOnStart" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span>Tray notifications</span>
        <label class="toggle"><input type="checkbox" id="notifications" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span>Global hotkeys<br><span style="font-size:11px;color:var(--muted)">Ctrl+Alt+C change · Ctrl+Alt+P pause</span></span>
        <label class="toggle"><input type="checkbox" id="hotkeys" onchange="save()"><span class="slider"></span></label></div>
      <div class="sw"><span>Start with Windows</span>
        <label class="toggle"><input type="checkbox" id="autorun" onchange="save()"><span class="slider"></span></label></div>
      <p class="status" style="margin-top:10px">Changes save automatically.</p>
    </div>

    <div class="card">
      <h2>Folders &amp; App</h2>
      <p class="status" style="margin:0 0 8px">Zips go in <b>Packs</b>. Each zip is unpacked <b>once</b> into a folder with the same name, right next to it.</p>
      <div class="row">
        <button class="btn sm" onclick="fetch('/api/openfolder?which=packs')">Open Packs folder</button>
        <button class="btn sm" onclick="fetch('/api/openfolder?which=logs')">Open Logs</button>
      </div>
      <div class="row" style="margin-top:8px">
        <button class="btn sm" onclick="load()">Refresh</button>
        <button class="btn sm" onclick="fetch('/api/openfolder?which=custom')">Open my custom packs</button>
        <button class="btn sm d" onclick="quitApp()">Exit App</button>
      </div>
      <p class="status" id="statusLine" style="margin-top:10px"></p>
    </div>

    <div class="card">
      <h2>Make your own pack</h2>
      <p class="status" style="margin:0 0 10px">Mix cursors from any packs you have — take the arrow from one theme,
      the loading spinner from another — and save it as your own named pack.</p>
      <button class="btn p" style="width:100%" onclick="openBuilder()">Create custom pack</button>
    </div>

    <div class="card danger">
      <h2>Danger zone</h2>
      <p class="status" style="margin:0 0 10px">Puts Windows back exactly as it was: original cursors, no autorun,
      no settings. Optionally deletes every downloaded pack too.</p>
      <label style="display:flex;align-items:center;gap:8px;font-size:12px;color:#cbd5e1;margin:0 0 10px">
        <input type="checkbox" id="rmPacks" style="width:auto"> Also delete all cursor packs in the Packs folder
      </label>
      <button class="btn d" style="width:100%" onclick="removeEverything()">Remove everything</button>
    </div>
  </div>

  <!-- RIGHT -->
  <div>
    <div class="card">
      <div class="tabs">
        <button class="tab on" id="tab-packs" onclick="showTab('packs')">My Packs <span class="cnt" id="cntPacks">0</span></button>
        <button class="tab" id="tab-store" onclick="showTab('store')">Download Store</button>
        <button class="tab" id="tab-diag" onclick="showTab('diag')">Diagnostics</button>
      </div>

      <div id="pane-packs">
        <div class="drop" id="drop"
             ondragover="event.preventDefault();this.classList.add('hot')"
             ondragleave="this.classList.remove('hot')"
             ondrop="dropFiles(event)">
          <h3>Add your own cursors</h3>
          <p>Drag a <b>.zip / .7z / .rar</b> here, or single <b>.cur / .ani</b> files, or pick a whole unzipped folder.
             Everything lands in <b>Packs</b> and is unpacked for you.</p>
          <div class="row" style="justify-content:center">
            <button class="btn p sm" onclick="document.getElementById('fZip').click()">Upload ZIP / archive</button>
            <button class="btn sm" onclick="document.getElementById('fCur').click()">Upload .cur / .ani files</button>
            <button class="btn sm" onclick="document.getElementById('fDir').click()">Upload an unzipped folder</button>
          </div>
          <input type="file" id="fZip" accept=".zip,.7z,.rar" multiple style="display:none" onchange="pickFiles(this.files)">
          <input type="file" id="fCur" accept=".cur,.ani,.inf" multiple style="display:none" onchange="pickFiles(this.files)">
          <input type="file" id="fDir" webkitdirectory directory multiple style="display:none" onchange="pickFiles(this.files)">
          <div class="uprog" id="uprog"><i id="ubar"></i></div>
          <p class="hint" id="utxt" style="margin-top:6px"></p>
        </div>
        <div class="row" style="margin-bottom:12px">
          <input type="text" id="search" placeholder="Search packs..." style="flex:1;min-width:160px" oninput="renderPacks()">
          <select id="filter" style="width:170px" onchange="renderPacks()">
            <option value="all">All packs</option>
            <option value="on">Only ON (in rotation)</option>
            <option value="off">Only OFF (skipped)</option>
            <option value="animated">Only animated (.ani)</option>
            <option value="static">Only static</option>
            <option value="rgb">Only RGB / rainbow</option>
          </select>
          <button class="btn sm" onclick="api('/api/toggleall?on=1')">All ON</button>
          <button class="btn sm" onclick="api('/api/toggleall?on=0')">All OFF</button>
          <button class="btn sm" onclick="api('/api/toggleweak')" title="Turn OFF packs that are missing most cursors">Turn OFF incomplete</button>
          <label class="hint" style="display:flex;align-items:center;gap:6px;margin:0">
            <input type="checkbox" id="animOn" checked style="width:auto" onchange="toggleAnim()"> Play animations</label>
        </div>
        <div class="row" style="margin-bottom:12px">
          <span class="status">Many packs ship Small/Regular/Large/Extra Large copies — keep only the size you like:</span>
          <button class="btn sm" onclick="api('/api/keepsize?size=Small')">Only Small</button>
          <button class="btn sm" onclick="api('/api/keepsize?size=Regular')">Only Regular</button>
          <button class="btn sm" onclick="api('/api/keepsize?size=Large')">Only Large</button>
          <button class="btn sm" onclick="api('/api/keepsize?size=Extra Large')">Only Extra Large</button>
        </div>
        <div id="packList"></div>
      </div>

      <div id="pane-store" style="display:none"></div>
      <div id="pane-diag" style="display:none"></div>
    </div>
  </div>
</div>
</div>

<dialog id="dlg">
  <div class="dh">
    <b id="dlgTitle">Customize</b>
    <div class="spacer"></div>
    <label style="margin:0;display:flex;align-items:center;gap:6px;font-size:12px">
      <input type="checkbox" id="mixAll" style="width:auto" onchange="fillMapTable()"> Allow files from other packs
    </label>
    <button class="btn sm" onclick="document.getElementById('dlg').close()">Close</button>
  </div>
  <div class="db">
    <p class="status">Choose exactly which cursor file is used for each job — loading, location, text, link, resize and more. "Windows default" leaves that one untouched.</p>
    <table id="mapTable"></table>
  </div>
  <div class="df">
    <button class="btn" onclick="autoDetect()">Reset to auto detect</button>
    <button class="btn p" onclick="saveMapping(false)">Save</button>
    <button class="btn g" onclick="saveMapping(true)">Save &amp; Apply</button>
  </div>
</dialog>

<dialog id="bdlg">
  <div class="dh">
    <b>Create your own cursor pack</b>
    <div class="spacer"></div>
    <button class="btn sm" onclick="document.getElementById('bdlg').close()">Close</button>
  </div>
  <div class="db">
    <p class="status">Pick a pack to start from, then swap any single cursor for one from another pack.
    Your mix is saved as a normal pack inside <b>Packs\_My Custom Packs</b> and joins the rotation.</p>
    <div class="row" style="margin:10px 0">
      <input type="text" id="bName" placeholder="Name your pack, e.g. My RGB mix" style="flex:1;min-width:200px">
      <select id="bBase" style="width:260px" onchange="builderFillFromBase()"><option value="">Start from a pack...</option></select>
      <button class="btn sm" onclick="builderClear()">Clear all</button>
    </div>
    <input type="text" id="bFilter" placeholder="Filter the file lists (pack name or file name)..." oninput="renderBuilder()" style="margin-bottom:8px">
    <div id="bRows"></div>
  </div>
  <div class="df">
    <span class="status" id="bCount">0 cursors chosen</span>
    <div class="spacer"></div>
    <button class="btn p" onclick="createPack()">Create pack</button>
  </div>
</dialog>


<div class="toast" id="toast"></div>

<script>
let S = null, dlgScheme = null, tick = 0, curTab = 'packs', busy = false;
let storeQ = '', storeTag = 'all';
const storeSel = new Set();

function toast(m){const t=document.getElementById('toast');t.textContent=m;t.classList.add('on');clearTimeout(t._t);t._t=setTimeout(()=>t.classList.remove('on'),2600);}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function leaf(p){return String(p||'').split(/[\\/]/).pop();}

async function req(url, opts){
  const r = await fetch(url, Object.assign({cache:'no-store'}, opts||{}));
  const j = await r.json();
  if(!j || !j.schemes) throw new Error((j && j.status) || ('HTTP '+r.status));
  return j;
}
async function load(){
  try{ S = await req('/api/state'); render(); }
  catch(e){ toast('Cannot reach the app - start it with Start.bat  ('+e.message+')'); }
}
async function api(url, opts){
  if(busy) return; busy = true;
  try{ S = await req(url, opts); render(); toast(S.status || 'Done'); }
  catch(e){ toast('Failed: '+e.message); }
  finally{ busy = false; }
}
async function quitApp(){
  if(!confirm('Exit Cursor Rotator? Rotation stops until you start it again.')) return;
  try{ await fetch('/api/exit'); }catch(e){}
  document.body.innerHTML = '<div class="empty" style="padding-top:80px">Cursor Rotator closed.<br>Start it again with <code>Start.bat</code>.</div>';
}

/* ---------- settings ---------- */
function quick(sec){
  const u = sec % 3600 === 0 ? 3600 : (sec % 60 === 0 ? 60 : 1);
  document.getElementById('ivUnit').value = u;
  document.getElementById('ivVal').value = sec / u;
  save();
}
function collect(){
  const unit = parseFloat(document.getElementById('ivUnit').value) || 1;
  const val  = parseFloat(document.getElementById('ivVal').value) || 30;
  return {
    enabled: document.getElementById('enabled').checked,
    randomOrder: document.getElementById('randomOrder').checked,
    avoidRepeat: document.getElementById('avoidRepeat').checked,
    fillMissing: document.getElementById('fillMissing').checked,
    applyOnStart: document.getElementById('applyOnStart').checked,
    notifications: document.getElementById('notifications').checked,
    hotkeys: document.getElementById('hotkeys').checked,
    intervalSeconds: Math.max(5, Math.round(val * unit))
  };
}
async function save(){
  if(busy) return; busy = true;
  try{
    S = await req('/api/save', {method:'POST', body: JSON.stringify(collect())});
    const want = document.getElementById('autorun').checked;
    if(want !== S.autorun){ S = await req('/api/autorun?on=' + (want ? 1 : 0)); }
    render(); toast('Saved');
  }catch(e){ toast('Save failed: '+e.message); }
  finally{ busy = false; }
}

/* ---------- render ---------- */
function render(){
  if(!S) return;
  const c = S.config || {};
  ['enabled','randomOrder','avoidRepeat','fillMissing','applyOnStart','notifications','hotkeys'].forEach(k=>{
    const el = document.getElementById(k); if(el) el.checked = !!c[k];
  });
  document.getElementById('autorun').checked = !!S.autorun;

  const secs = Number(S.intervalSeconds || 1800);
  const uEl = document.getElementById('ivUnit'), vEl = document.getElementById('ivVal');
  if(document.activeElement !== vEl && document.activeElement !== uEl){
    if(secs % 3600 === 0){ uEl.value = 3600; vEl.value = secs/3600; }
    else if(secs % 60 === 0){ uEl.value = 60; vEl.value = secs/60; }
    else { uEl.value = 1; vEl.value = secs; }
  }
  document.getElementById('dot').className = 'dot' + (c.enabled ? '' : ' off');
  document.getElementById('curPill').textContent = 'Current: ' + (c.lastScheme ? leaf(c.lastScheme) : 'none');
  document.getElementById('statusLine').textContent = S.status || '';
  document.getElementById('cntPacks').textContent = S.schemes.length;
  tick = S.nextInSec || 0; paintNext();
  renderPacks(); renderStore(); renderDiag();
}
function paintNext(){
  const c = S && S.config, el = document.getElementById('nextPill');
  if(!c || !c.enabled){ el.textContent = 'Rotation paused'; return; }
  const h = Math.floor(tick/3600), m = Math.floor((tick%3600)/60), s = tick%60;
  el.textContent = 'Next in ' + (h ? h+'h '+m+'m' : (m ? m+'m '+s+'s' : s+'s'));
}
function renderPacks(){
  const box = document.getElementById('packList');
  if(!S.schemes.length){
    box.innerHTML = '<div class="empty">No cursor packs detected yet.<br>'
      + '1. Put <b>.zip</b> packs in the <b>Packs</b> folder → click <b>Rescan</b> (each zip unpacks once, into a folder of the same name)<br>'
      + '2. Or get ready-made ones from the <b>Download Store</b><br><br>'
      + '<button class="btn p" onclick="api(\'/api/autofix\')">Fix it for me (re-extract + download starter packs)</button> '
      + '<button class="btn" onclick="showTab(\'store\')">Open Store</button></div>';
    return;
  }
  const q = (document.getElementById('search').value || '').toLowerCase();
  const f = document.getElementById('filter').value;
  const list = S.schemes.filter(s =>
      (!q || s.name.toLowerCase().includes(q)) &&
      (f === 'all' || (f === 'on' && s.enabled) || (f === 'off' && !s.enabled)
        || (f === 'animated' && s.animated) || (f === 'static' && !s.animated)
        || (f === 'rgb' && /rainbow|rgb/i.test(s.name))));
  const onCount = S.schemes.filter(s=>s.enabled).length;
  if(!list.length){ box.innerHTML = '<div class="empty">No pack matches this filter.</div>'; return; }
  const groups = {};
  list.forEach(s => { (groups[s.group || 'Other'] = groups[s.group || 'Other'] || []).push(s); });
  box.innerHTML = '<p class="status" style="margin:0 0 10px">' + onCount + ' of ' + S.schemes.length
   + ' packs are ON and will be used in rotation.'
   + (S.schemes.filter(s=>s.animated).length ? '  ' + S.schemes.filter(s=>s.animated).length + ' of them are animated - the previews below really move.' : '')
   + '</p>'
   + Object.keys(groups).map(g => groupBlock(g, groups[g])).join('');
  stopAnims(); startAnims();
}
function groupBlock(g, list){
  const anyOn = list.some(s => s.enabled);
  return '<div style="margin-bottom:16px">'
    + '<div class="row" style="margin-bottom:8px">'
    +   '<b style="font-size:13px">' + esc(g) + '</b>'
    +   '<span class="chip">' + list.length + ' pack' + (list.length>1?'s':'') + '</span>'
    +   '<div class="spacer"></div>'
    +   '<button class="btn sm" onclick="api(\'/api/togglegroup?on=' + (anyOn?0:1) + '&group=' + encodeURIComponent(g) + '\')">'
    +     (anyOn ? 'Turn group OFF' : 'Turn group ON') + '</button>'
    + '</div>'
    + '<div class="schemes">' + list.map(s => {
    const pct = Math.round(s.coverage / s.total * 100);
    const PV = [['Arrow','Normal','A'],['Wait','Busy / loading','L'],['AppStarting','Working in background','W'],
                ['IBeam','Text select','T'],['Hand','Link select','H'],['Pin','Location','P'],['SizeAll','Move','M']];
    const prev = PV.map(([k,lbl,tag]) => {
      const p = (s.overrides && s.overrides[k]) || s.map[k];
      if(!p) return '';
      const isAni = /\.ani$/i.test(p);
      return '<div class="pv' + (isAni ? ' ani' : '') + '" title="' + lbl + ' — ' + esc(leaf(p)) + (isAni ? ' (animated)' : '') + '">'
        + '<img loading="lazy"' + (isAni ? ' data-ani="' + esc(p) + '"' : '') + ' src="/file?p='
        + encodeURIComponent(p) + '" onerror="this.parentNode.style.opacity=.25"><b>' + tag + '</b>'
        + (isAni ? '<span class="lbl">A</span>' : '') + '</div>';
    }).join('');
    const nm = s.name.replace(/'/g, "\\'");
    const mid = (s.name.replace(/[^a-z0-9]/gi, '') || 'x').slice(-14) + (s.files.length);
    const badges = (s.animated ? '<span class="badge anim" title="' + s.aniCount + ' animated .ani cursor(s) in this pack">ANIMATED</span>' : '')
      + (/rainbow|rgb/i.test(s.name) ? '<span class="badge rgb" title="Colour cycling RGB pack">RGB</span>' : '')
      + (/anime|neuro|noelle|kuro|shiori|wanderer|ellen/i.test(s.name) ? '<span class="badge anime">ANIME</span>' : '');
    return '<div class="sc' + (S.config.lastScheme === s.name ? ' active' : '') + (s.enabled ? '' : ' off') + '">'
      + '<div class="row" style="justify-content:space-between;align-items:flex-start">'
      +   '<div class="nm" title="' + esc(s.name) + '">' + esc(s.title || leaf(s.name)) + '</div>'
      +   '<label class="toggle" title="ON = this pack is used in random rotation. OFF = never used."><input type="checkbox" ' + (s.enabled ? 'checked' : '')
      +     ' onchange="api(\'/api/toggle?on=\'+(this.checked?1:0)+\'&name=' + encodeURIComponent(s.name) + '\')"><span class="slider"></span></label>'
      + '</div>'
      + '<div class="row" style="gap:4px;margin:4px 0 0">'
      +   '<span class="badge ' + (s.enabled ? 'on' : 'offb') + '">' + (s.enabled ? 'ON - in rotation' : 'OFF - never used') + '</span>'
      +   badges + (s.weak ? '<span class="badge offb" title="Only ' + s.coverage + ' of ' + s.total + ' cursor jobs found - looks incomplete">INCOMPLETE</span>' : '') + '</div>'
      + '<div class="mt">' + (s.size && s.size !== 'Standard' ? '<span class="chip">' + esc(s.size) + '</span> ' : '') + esc(s.name) + '</div>'
      + '<div class="prev">' + prev + '</div>'
      + '<div class="bar"><i style="width:' + pct + '%"></i></div>'
      + '<div class="mt">' + s.coverage + '/' + s.total + ' cursor jobs detected'
      +   (s.filled > 0 ? ' <span class="chip" title="Borrowed from this pack\'s own cursors, so nothing falls back to a Windows cursor">+' + s.filled + ' filled</span>' : '')
      +   ' · ' + s.files.length + ' files'
      +   (Object.keys(s.overrides||{}).length ? ' · <span class="chip">custom</span>' : '') + '</div>'
      + '<div class="row"><button class="btn g sm" onclick="apply(\'' + nm + '\')">Apply</button>'
      + '<button class="btn sm" onclick="openMap(\'' + nm + '\')">Assign cursors</button>'
      + '<div class="spacer"></div>'
      + '<div class="menu"><button class="mbtn" onclick="toggleMenu(\'m' + mid + '\', event)" title="More">&#8942;</button>'
      +   '<div class="mlist" id="m' + mid + '">'
      +     '<button onclick="apply(\'' + nm + '\')">Apply now</button>'
      +     '<button onclick="renamePack(\'' + nm + '\')">Rename pack</button>'
      +     '<button onclick="openMap(\'' + nm + '\')">Assign cursors</button>'
      +     '<button onclick="openBuilderFrom(\'' + nm + '\')">Use as base for a custom pack</button>'
      +     '<button class="dgr" onclick="deletePack(\'' + nm + '\')">Delete pack from disk</button>'
      +   '</div></div>'
      + '</div>'
      + '</div>';
  }).join('') + '</div></div>';
}
function apply(n){ api('/api/apply?scheme=' + encodeURIComponent(n)); }

function showTab(t){
  curTab = t;
  ['packs','store','diag'].forEach(x => {
    document.getElementById('pane-'+x).style.display = (x === t ? '' : 'none');
    document.getElementById('tab-'+x).className = 'tab' + (x === t ? ' on' : '');
  });
}
function renderStore(){
  const p = document.getElementById('pane-store');
  if(!S.store || !S.store.length){ p.innerHTML = '<div class="empty">Store unavailable.</div>'; return; }
  const tags = S.storeTags || [];
  const q = storeQ.toLowerCase();
  const list = S.store.filter(i =>
      (storeTag === 'all'
        || (storeTag === '__new' && !i.installed)
        || (storeTag === '__installed' && i.installed)
        || (i.tags || []).some(t => t.toLowerCase() === storeTag.toLowerCase()))
      && (!q || (i.name + ' ' + i.desc + ' ' + (i.tags||[]).join(' ')).toLowerCase().includes(q)));
  const notInst = S.store.filter(i => !i.installed).length;
  const chip = (id, label, n) => '<button class="fchip' + (storeTag === id ? ' on' : '') + '" onclick="setStoreTag(\'' + id + '\')">'
      + label + (n === undefined ? '' : ' <b>' + n + '</b>') + '</button>';
  let html = '<p class="status" style="margin:0 0 10px">Free open-source cursor packs straight from GitHub. One click = download + unzip + ready to rotate. '
      + S.store.length + ' packs available, ' + (S.store.length - notInst) + ' already installed.</p>'
    + '<div class="row" style="margin-bottom:8px">'
    +   '<input type="text" id="storeSearch" placeholder="Search store (rgb, anime, dark, macos...)" style="flex:1;min-width:180px" '
    +     'value="' + esc(storeQ) + '" oninput="storeQ=this.value;renderStore();document.getElementById(\'storeSearch\').focus()">'
    + '</div>'
    + '<div class="chiprow">' + chip('all','All', S.store.length)
    +   chip('__new','Not installed', notInst) + chip('__installed','Installed', S.store.length - notInst)
    +   tags.map(t => chip(t, t, S.store.filter(i => (i.tags||[]).indexOf(t) >= 0).length)).join('')
    + '</div>'
    + '<div class="row" style="margin:10px 0 12px;gap:6px">'
    +   '<button class="btn sm" onclick="storeSelectShown(1)">Select all shown (' + list.length + ')</button>'
    +   '<button class="btn sm" onclick="storeSelectShown(0)">Clear selection</button>'
    +   '<div class="spacer"></div>'
    +   '<button class="btn p" onclick="dlSelected()">Download selected (' + storeSel.size + ')</button>'
    +   '<button class="btn g" onclick="dlList(' + JSON.stringify(list.filter(i=>!i.installed).map(i=>i.id)).replace(/"/g,'&quot;') + ')">Download all shown</button>'
    + '</div>'
    + '<div id="dlProg" class="dlprog" style="display:none"><div class="bar"><i id="dlBar" style="width:0%"></i></div><div class="status" id="dlTxt"></div></div>';
  if(!list.length){ p.innerHTML = html + '<div class="empty">No store pack matches this filter.</div>'; return; }
  html += list.map(i => {
    const tg = (i.tags || []).map(t => '<span class="badge ' + tagCls(t) + '">' + esc(t) + '</span>').join('');
    return '<div class="st">'
      + '<input type="checkbox" class="selbox" ' + (storeSel.has(i.id) ? 'checked' : '') + (i.installed ? ' disabled' : '')
      +   ' onchange="storePick(\'' + i.id + '\', this.checked)">'
      + '<div class="info"><div style="font-size:13px;font-weight:600">' + esc(i.name)
      +   ' <span class="chip">' + esc(i.size) + '</span></div>'
      + '<div class="row" style="gap:4px;margin:3px 0">' + tg + '</div>'
      + '<div class="status">' + esc(i.desc) + ' &middot; by ' + esc(i.author) + '</div></div>'
      + (i.installed ? '<span class="ok">Installed</span>'
                     : '<button class="btn g sm" onclick="dl(\'' + i.id + '\',this)">Download</button>') + '</div>';
  }).join('');
  p.innerHTML = html;
}
function tagCls(t){
  const l = (t||'').toLowerCase();
  if(l === 'rgb') return 'rgb';
  if(l === 'animated') return 'anim';
  if(l === 'anime') return 'anime';
  if(l === 'dark') return 'dark';
  if(l === 'light') return 'light';
  return '';
}
function setStoreTag(t){ storeTag = t; renderStore(); }
function storePick(id, on){ if(on) storeSel.add(id); else storeSel.delete(id); renderStore(); }
function storeSelectShown(on){
  if(!on){ storeSel.clear(); renderStore(); return; }
  const q = storeQ.toLowerCase();
  S.store.filter(i => !i.installed
      && (storeTag === 'all' || (storeTag === '__new') || (storeTag === '__installed' && i.installed)
          || (i.tags||[]).some(t => t.toLowerCase() === storeTag.toLowerCase()))
      && (!q || (i.name + ' ' + i.desc + ' ' + (i.tags||[]).join(' ')).toLowerCase().includes(q)))
    .forEach(i => storeSel.add(i.id));
  renderStore();
}
async function dl(id, btn){
  if(btn){ btn.disabled = true; btn.textContent = 'Downloading...'; }
  toast('Downloading, please wait...');
  try{ S = await req('/api/download?id=' + encodeURIComponent(id)); render(); showTab('store'); toast(S.status); }
  catch(e){ toast('Download failed: ' + e.message); if(btn){ btn.disabled = false; btn.textContent = 'Download'; } }
}
async function dlSelected(){
  const ids = Array.from(storeSel);
  if(!ids.length){ toast('Tick the packs you want first (checkbox on the left)'); return; }
  await dlList(ids);
}
async function dlList(ids){
  ids = (ids || []).filter(x => x);
  if(!ids.length){ toast('Nothing to download - everything here is installed already'); return; }
  const box = document.getElementById('dlProg'), bar = document.getElementById('dlBar'), txt = document.getElementById('dlTxt');
  if(box){ box.style.display = ''; }
  let done = 0;
  for(const id of ids){
    const it = S.store.find(x => x.id === id) || {name:id};
    if(txt) txt.textContent = 'Downloading ' + it.name + '  (' + (done+1) + ' of ' + ids.length + ') ...';
    try{ S = await req('/api/download?id=' + encodeURIComponent(id)); }catch(e){}
    done++;
    if(bar) bar.style.width = Math.round(done / ids.length * 100) + '%';
  }
  storeSel.clear();
  render(); showTab('store');
  if(box) setTimeout(() => { box.style.display = 'none'; if(bar) bar.style.width = '0%'; }, 1500);
  toast(done + ' pack(s) processed. Check My Packs.');
}
async function downloadAll(){ await dlList(S.store.filter(i => !i.installed).map(i => i.id)); }
async function setup7z(btn){
  if(btn){ btn.disabled = true; btn.textContent = 'Setting up 7-Zip...'; }
  toast('Downloading 7-Zip, please wait...');
  try{ S = await req('/api/install7zip'); render(); showTab('diag'); toast(S.status); }
  catch(e){ toast('Setup failed: ' + e.message); }
  finally{ if(btn){ btn.disabled = false; btn.textContent = 'Download portable 7-Zip'; } }
}
function renderDiag(){
  const d = S.diag || {};
  document.getElementById('pane-diag').innerHTML =
      '<table><tr><th style="width:230px">Check</th><th>Value</th></tr>'
    + '<tr><td>Packs folder (zips + unpacked folders)</td><td><code>' + esc(S.packsDir) + '</code></td></tr>'
    + '<tr><td>Unpacking</td><td>Each zip is extracted once into <code>Packs\\&lt;zip name&gt;\\</code> and skipped afterwards</td></tr>'
    + '<tr><td>Folders scanned</td><td>' + (d.folders||0) + '</td></tr>'
    + '<tr><td>.cur / .ani files found</td><td>' + (d.cursorFiles||0) + '</td></tr>'
    + '<tr><td>Packs detected</td><td>' + S.schemes.length + ' (' + S.schemes.filter(s=>s.animated).length + ' animated)</td></tr>'
    + '<tr><td>Custom packs folder</td><td><code>' + esc(S.customDir || '') + '</code></td></tr>'
    + '<tr><td>Files ignored (not cursors)</td><td>' + (d.skipped || 0)
    +   ((d.ignored && d.ignored.length) ? '<br><span class="hint">' + d.ignored.map(esc).join('<br>') + '</span>' : '')
    +   '<br><span class="hint">These are simply skipped - readme files, images and so on never cause an error.</span></td></tr>'
    + '<tr><td>Archive extractor</td><td>' + esc(S.extractor || '') + '</td></tr>'
    + '<tr><td>Last error</td><td>' + esc(d.lastError || 'none') + '</td></tr></table>'
    + '<p class="status" style="margin-top:10px">.zip files never need any tool. For <b>.rar / .7z</b> the app uses <b>7-Zip</b> — and can set up a portable copy by itself (no install, no admin, no WinRAR trial).</p>'
    + '<div class="row" style="margin-top:6px"><button class="btn g" onclick="setup7z(this)">Download portable 7-Zip</button></div>'
    + '<div class="row" style="margin-top:12px">'
    +   '<button class="btn p" onclick="api(\'/api/autofix\')">Fix it for me</button>'
    +   '<button class="btn" onclick="api(\'/api/rescan\')">Rescan</button>'
    +   '<button class="btn" onclick="api(\'/api/reextract\')">Force re-extract all zips</button>'
    +   '<button class="btn" onclick="fetch(\'/api/openfolder?which=logs\')">Open log folder</button>'
    + '</div>'
    + '<h2 style="margin-top:16px">Extraction log</h2><pre>' + esc((S.extract && S.extract.length) ? S.extract.join('\n') : 'Nothing new to extract.') + '</pre>';
}

/* ---------- mapping editor ---------- */
function openMap(name){
  dlgScheme = S.schemes.find(x => x.name === name);
  if(!dlgScheme) return;
  document.getElementById('dlgTitle').textContent = 'Assign cursors — ' + leaf(name);
  document.getElementById('mixAll').checked = false;
  fillMapTable();
  document.getElementById('dlg').showModal();
}
function fileOptions(cur){
  const mix = document.getElementById('mixAll').checked;
  let files = dlgScheme.files.slice();
  if(mix){ S.schemes.forEach(s => { if(s.name !== dlgScheme.name) files = files.concat(s.files); }); }
  if(cur && files.indexOf(cur) === -1) files.unshift(cur);
  return '<option value="">— Windows default —</option>' + files.map(f =>
    '<option value="' + esc(f) + '"' + (f === cur ? ' selected' : '') + '>' + esc(leaf(f)) + (mix ? '  ·  ' + esc(leaf(f.replace(/[\\/][^\\/]+$/,''))) : '') + '</option>').join('');
}
function fillMapTable(){
  const t = document.getElementById('mapTable');
  let h = '<tr><th style="width:36px"></th><th style="width:190px">Cursor job</th><th>File used</th><th style="width:90px">Source</th></tr>';
  S.roles.forEach(r => {
    const ov  = dlgScheme.overrides && dlgScheme.overrides[r.key];
    const cur = ov || dlgScheme.map[r.key] || '';
    const isA = /\.ani$/i.test(cur);
    const img = '<div class="mapimg">' + (cur ? '<img' + (isA ? ' data-ani="' + esc(cur) + '"' : '') + ' src="/file?p=' + encodeURIComponent(cur) + '" onerror="this.style.opacity=.15">' : '') + '</div>';
    const src = ov ? '<span class="chip" style="border-color:var(--acc);color:var(--acc)">custom</span>'
                   : (dlgScheme.map[r.key] ? '<span class="chip">auto</span>' : '<span class="chip">default</span>');
    h += '<tr><td>' + img + '</td><td>' + esc(r.label) + '</td>'
       + '<td><select data-role="' + r.key + '" onchange="previewCell(this)">' + fileOptions(cur) + '</select></td>'
       + '<td>' + src + '</td></tr>';
  });
  t.innerHTML = h;
  stopAnims(); startAnims();
}
function previewCell(sel){
  const cell = sel.closest('tr').querySelector('.mapimg');
  if(!cell) return;
  cell.innerHTML = sel.value ? '<img' + (/\.ani$/i.test(sel.value) ? ' data-ani="' + esc(sel.value) + '"' : '') + ' src="/file?p=' + encodeURIComponent(sel.value) + '" onerror="this.style.opacity=.15">' : '';
  startAnims();
}
async function autoDetect(){
  if(!dlgScheme) return;
  try{
    S = await req('/api/resetmap?name=' + encodeURIComponent(dlgScheme.name));
    dlgScheme = S.schemes.find(x => x.name === dlgScheme.name);
    fillMapTable(); render(); toast('Auto detection restored');
  }catch(e){ toast('Failed: ' + e.message); }
}
async function saveMapping(applyAfter){
  if(!dlgScheme) return;
  const ov = JSON.parse(JSON.stringify(S.config.overrides || {}));
  const m = {};
  document.querySelectorAll('#mapTable select').forEach(sl => { if(sl.value) m[sl.dataset.role] = sl.value; });
  ov[dlgScheme.name] = m;
  try{
    S = await req('/api/save', {method:'POST', body: JSON.stringify({overrides: ov})});
    if(applyAfter) S = await req('/api/apply?scheme=' + encodeURIComponent(dlgScheme.name));
    render(); document.getElementById('dlg').close();
    toast(applyAfter ? 'Saved and applied' : 'Mapping saved');
  }catch(e){ toast('Save failed: ' + e.message); }
}


/* ================= animated .ani previews ================= */
let animOn = true;
const aniMeta = new Map();      // path -> {frames, seq, rates}
const aniTimers = new Set();

function stopAnims(){ aniTimers.forEach(t => clearTimeout(t)); aniTimers.clear(); }
function toggleAnim(){
  animOn = document.getElementById('animOn').checked;
  try{ localStorage.setItem('cr-anim', animOn ? '1' : '0'); }catch(e){}
  stopAnims();
  if(animOn) startAnims(); else document.querySelectorAll('img[data-ani]').forEach(im => { im.src = '/file?p=' + encodeURIComponent(im.dataset.ani); });
}
async function metaFor(path){
  if(aniMeta.has(path)) return aniMeta.get(path);
  try{
    const r = await fetch('/api/aniinfo?p=' + encodeURIComponent(path), {cache:'force-cache'});
    const j = await r.json();
    aniMeta.set(path, j);
    return j;
  }catch(e){ aniMeta.set(path, {frames:0}); return {frames:0}; }
}
async function animate(img){
  const path = img.dataset.ani;
  const m = await metaFor(path);
  if(!m || !m.frames || m.frames < 2 || !animOn) return;
  const seq = (m.seq && m.seq.length) ? m.seq : [...Array(m.frames).keys()];
  const rates = (m.rates && m.rates.length) ? m.rates : seq.map(() => 100);
  // preload every frame once so the animation never flickers
  const urls = [];
  for(let f = 0; f < m.frames; f++){
    const u = '/file?p=' + encodeURIComponent(path) + '&frame=' + f;
    const pre = new Image(); pre.src = u; urls.push(u);
  }
  let i = 0;
  const step = () => {
    if(!animOn || !document.body.contains(img)) return;
    const fi = seq[i % seq.length];
    img.src = urls[Math.min(fi, urls.length - 1)];
    const wait = Math.max(40, rates[i % rates.length] || 100);
    i++;
    const t = setTimeout(step, wait);
    aniTimers.add(t);
  };
  step();
}
function startAnims(){
  if(!animOn) return;
  const imgs = Array.from(document.querySelectorAll('img[data-ani]')).slice(0, 90);
  if(!('IntersectionObserver' in window)){ imgs.forEach(animate); return; }
  const io = new IntersectionObserver((entries, obs) => {
    entries.forEach(e => { if(e.isIntersecting){ animate(e.target); obs.unobserve(e.target); } });
  }, {rootMargin:'120px'});
  imgs.forEach(im => io.observe(im));
}

/* ================= uploads ================= */
function dropFiles(ev){
  ev.preventDefault();
  document.getElementById('drop').classList.remove('hot');
  const items = ev.dataTransfer.files;
  if(items && items.length) pickFiles(items);
}
function b64(file){
  return new Promise((res, rej) => {
    const fr = new FileReader();
    fr.onload = () => res(String(fr.result).split(',')[1]);
    fr.onerror = rej;
    fr.readAsDataURL(file);
  });
}
async function pickFiles(fileList){
  const files = Array.from(fileList || []).filter(f => /\.(zip|7z|rar|cur|ani|inf)$/i.test(f.name));
  const ignored = Array.from(fileList || []).length - files.length;
  if(!files.length){ toast('Nothing usable here. Send .zip / .7z / .rar or .cur / .ani files.'); return; }
  const box = document.getElementById('uprog'), bar = document.getElementById('ubar'), txt = document.getElementById('utxt');
  box.style.display = 'block';
  let done = 0, ok = 0, msg = '';
  for(const f of files){
    txt.textContent = 'Uploading ' + f.name + ' (' + (done + 1) + ' of ' + files.length + ')...';
    try{
      const rel = (f.webkitRelativePath || '').split('/')[0] || '';
      const data = await b64(f);
      S = await req('/api/upload', {method:'POST', body: JSON.stringify({name: f.name, folder: rel, data: data})});
      msg = S.status; if(/^Added/.test(msg)) ok++;
    }catch(e){ msg = 'Failed: ' + e.message; }
    done++; bar.style.width = Math.round(done / files.length * 100) + '%';
  }
  txt.textContent = ok + ' of ' + files.length + ' file(s) added' + (ignored ? ' · ' + ignored + ' unsupported file(s) skipped' : '') + '. ' + msg;
  setTimeout(() => { box.style.display = 'none'; bar.style.width = '0%'; }, 2500);
  render(); showTab('packs'); toast(ok + ' file(s) added to Packs');
}

/* ================= pack actions ================= */
function toggleMenu(id, ev){
  ev.stopPropagation();
  const el = document.getElementById(id);
  document.querySelectorAll('.mlist.on').forEach(m => { if(m !== el) m.classList.remove('on'); });
  el.classList.toggle('on');
}
document.addEventListener('click', () => document.querySelectorAll('.mlist.on').forEach(m => m.classList.remove('on')));

async function renamePack(name){
  const leaf = name.split('\\').pop();
  const to = prompt('New name for this pack:', leaf);
  if(!to || to === leaf) return;
  S = await req('/api/renamepack?name=' + encodeURIComponent(name) + '&to=' + encodeURIComponent(to));
  render(); toast(S.status);
}
async function deletePack(name){
  if(!confirm('Delete this pack from disk?\n\n' + name + '\n\nThe folder and its zip are removed permanently.')) return;
  S = await req('/api/deletepack?name=' + encodeURIComponent(name));
  render(); toast(S.status);
}
async function removeEverything(){
  const withPacks = document.getElementById('rmPacks').checked;
  let msg = 'This will:\n  - restore your original Windows cursors\n  - remove the Start-with-Windows entry\n  - delete all app settings';
  if(withPacks) msg += '\n  - DELETE every cursor pack in the Packs folder';
  msg += '\n\nContinue?';
  if(!confirm(msg)) return;
  if(withPacks && !confirm('Really delete every downloaded cursor pack? This cannot be undone.')) return;
  S = await req('/api/removeall?packs=' + (withPacks ? '1' : '0'));
  render(); toast(S.status);
}

/* ================= custom pack builder ================= */
let bSel = {};
function openBuilder(){
  if(!S || !S.schemes.length){ toast('Add or download at least one pack first'); return; }
  bSel = {};
  const base = document.getElementById('bBase');
  base.innerHTML = '<option value="">Start from a pack...</option>'
    + S.schemes.map(s => '<option value="' + esc(s.name) + '">' + esc(leaf(s.name)) + '</option>').join('');
  document.getElementById('bName').value = '';
  document.getElementById('bFilter').value = '';
  renderBuilder();
  document.getElementById('bdlg').showModal();
}
function openBuilderFrom(name){
  openBuilder();
  const b = document.getElementById('bBase');
  b.value = name; builderFillFromBase();
  const s = S.schemes.find(x => x.name === name);
  document.getElementById('bName').value = (s ? (s.title || leaf(s.name)) : 'My pack') + ' mix';
}
function builderClear(){ bSel = {}; renderBuilder(); }
function builderFillFromBase(){
  const n = document.getElementById('bBase').value;
  const s = S.schemes.find(x => x.name === n);
  if(!s) return;
  S.roles.forEach(r => { const f = (s.overrides && s.overrides[r.key]) || s.map[r.key]; if(f) bSel[r.key] = f; });
  renderBuilder();
}
function renderBuilder(){
  const q = (document.getElementById('bFilter').value || '').toLowerCase();
  const opts = [];
  S.schemes.forEach(s => {
    s.files.forEach(f => {
      const lbl = leaf(s.name) + '  /  ' + leaf(f);
      if(!q || lbl.toLowerCase().includes(q)) opts.push([f, lbl]);
    });
  });
  const rows = S.roles.map(r => {
    const cur = bSel[r.key] || '';
    const list = '<option value="">— none (Windows default) —</option>'
      + opts.map(([f, lbl]) => '<option value="' + esc(f) + '"' + (f === cur ? ' selected' : '') + '>' + esc(lbl) + '</option>').join('')
      + (cur && !opts.some(([f]) => f === cur) ? '<option value="' + esc(cur) + '" selected>' + esc(leaf(cur)) + '</option>' : '');
    const prev = cur ? '<img src="/file?p=' + encodeURIComponent(cur) + '"' + (/\.ani$/i.test(cur) ? ' data-ani="' + esc(cur) + '"' : '') + '>' : '';
    return '<div class="builder">'
      + '<div class="rl">' + esc(r.label) + '</div>'
      + '<div class="pvbox">' + prev + '</div>'
      + '<select onchange="bSel[\'' + r.key + '\']=this.value; if(!this.value) delete bSel[\'' + r.key + '\']; renderBuilder()">' + list + '</select>'
      + '<button class="btn sm" onclick="bSel[\'' + r.key + '\']=\'\'; delete bSel[\'' + r.key + '\']; renderBuilder()">Clear</button>'
      + '</div>';
  }).join('');
  document.getElementById('bRows').innerHTML = rows;
  document.getElementById('bCount').textContent = Object.keys(bSel).filter(k => bSel[k]).length + ' of ' + S.roles.length + ' cursors chosen';
  startAnims();
}
async function createPack(){
  const name = (document.getElementById('bName').value || '').trim();
  if(!name){ toast('Give your pack a name first'); return; }
  const map = {};
  Object.keys(bSel).forEach(k => { if(bSel[k]) map[k] = bSel[k]; });
  if(!Object.keys(map).length){ toast('Choose at least one cursor'); return; }
  try{
    S = await req('/api/createpack', {method:'POST', body: JSON.stringify({name: name, map: map})});
    document.getElementById('bdlg').close();
    render(); showTab('packs'); toast(S.status);
  }catch(e){ toast('Could not create pack: ' + e.message); }
}

try{ if(localStorage.getItem('cr-anim') === '0'){ animOn = false; document.addEventListener('DOMContentLoaded', () => { const e = document.getElementById('animOn'); if(e) e.checked = false; }); } }catch(e){}
setInterval(() => { if(tick > 0){ tick--; paintNext(); } }, 1000);
setInterval(() => { if(document.visibilityState === 'visible' && !busy) load(); }, 15000);
load();
</script>
</body>
</html>
'@

function Get-StateJson {
    try {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($s in $Script:Schemes) {
            $mapObj = [ordered]@{}
            foreach ($k in $Script:RoleKeys) { if ($s.map.ContainsKey($k)) { $mapObj[$k] = $s.map[$k] } }
            $ovObj = [ordered]@{}
            $ov = Get-Prop (Get-Prop $Script:Cfg 'overrides') $s.name
            if ($ov) { foreach ($k in $Script:RoleKeys) { $v = Get-Prop $ov $k; if ($v) { $ovObj[$k] = $v } } }
            $off = @(Get-Prop $Script:Cfg 'disabledSchemes')
            $sizeTag = 'Standard'
            $ln = ([string]$s.name).ToLowerInvariant()
            if ($ln -match 'extra[\s_-]*large|xl\b') { $sizeTag = 'Extra Large' }
            elseif ($ln -match '\blarge\b') { $sizeTag = 'Large' }
            elseif ($ln -match '\bsmall\b') { $sizeTag = 'Small' }
            elseif ($ln -match 'regular|medium|normal') { $sizeTag = 'Regular' }
            $grp = ([string]$s.name) -split '[\\/]' | Select-Object -First 1
            $list.Add([pscustomobject]@{
                name = [string]$s.name; path = [string]$s.path
                size = [string]$sizeTag; group = [string]$grp
                coverage = [int]$s.coverage; total = [int]$s.total
                files = [object[]]$s.files; map = $mapObj; overrides = $ovObj
                enabled = [bool]($off -notcontains $s.name)
                aniCount = [int]$s.aniCount
                title = [string]$s.title
                weak = [bool]($s.coverage -lt 6)
                filled = [int]((Get-FilledMap -Scheme $s -Cfg $Script:Cfg).Count - $s.coverage)
                animated = [bool]($s.aniCount -gt 0)
                tags = [object[]](Get-PackTags -Name ([string]$s.name) -AniCount ([int]$s.aniCount))
            })
        }
        $roles = New-Object System.Collections.Generic.List[object]
        foreach ($r in $Script:Roles) { $roles.Add([pscustomobject]@{ key = $r.Key; label = $r.Label }) }
        $store = New-Object System.Collections.Generic.List[object]
        foreach ($i in $Script:Store) {
            $installed = [System.IO.Directory]::Exists((Join-Path $PacksDir $i.id))
            $store.Add([pscustomobject]@{ id=$i.id; name=$i.name; author=$i.author; desc=$i.desc; size=$i.size; installed=$installed; tags=[object[]]$i.tags })
        }
        $tool = Get-Extractor
        $extractor = if ($tool) { $tool.label } else { 'Built-in unzip only (.zip) - 7-Zip not set up yet' }
        $secs = [int][math]::Max(0, [math]::Round(($Script:NextChange - (Get-Date)).TotalSeconds))
        $iv   = [int](Get-IntervalSeconds $Script:Cfg)
        $obj = [pscustomobject]@{
            ok = $true
            config = $Script:Cfg
            schemes = [object[]]$list.ToArray()
            roles = [object[]]$roles.ToArray()
            store = [object[]]$store.ToArray()
            storeTags = [object[]](Get-StoreTagList)
            intervalSeconds = $iv
            extractor = [string]$extractor
            status = [string]$Script:Status
            autorun = [bool](Test-Autorun)
            nextInSec = $secs
            packsDir = [string]$PacksDir
            customDir = [string]$CustomDir
            extract = [object[]]$Script:ExtractReport
            diag = [pscustomobject]@{ folders=[int]$Script:Diag.folders; cursorFiles=[int]$Script:Diag.cursorFiles; skipped=[int]$Script:Diag.skipped; lastError=[string]$Script:LastError; ignored=[object[]]@($Script:Diag.ignored) }
        }
        return ($obj | ConvertTo-Json -Depth 8 -Compress)
    } catch {
        Log-Err $_ 'Get-StateJson'
        $msg = ($_.Exception.Message -replace '["\\]', ' ')
        return '{"ok":false,"config":{"enabled":false,"intervalSeconds":1800,"disabledSchemes":[],"overrides":{},"lastScheme":""},"schemes":[],"roles":[],"store":[],"status":"Internal error: ' + $msg + '","autorun":false,"nextInSec":0,"packsDir":"","cursorsDir":"","extract":[],"diag":{"folders":0,"cursorFiles":0,"skipped":0,"lastError":"' + $msg + '"}}'
    }
}

# bind port
$Script:Listener = $null
foreach ($p in @($Port, ($Port + 1), ($Port + 2), ($Port + 3), ($Port + 4))) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://127.0.0.1:$p/")
        $l.Start()
        $Script:Listener = $l
        $Script:UsedPort = $p
        break
    } catch { try { $l.Close() } catch { } }
}
if ($null -eq $Script:Listener) {
    Write-Log "Could not bind a port near $Port. Is another copy already running?" 'ERROR'
    try { [System.Windows.Forms.MessageBox]::Show("Cursor Rotator could not open local port $Port.`nRun Stop.bat and try again.", 'Cursor Rotator') | Out-Null } catch { }
    return
}
$Url = "http://127.0.0.1:$Script:UsedPort/"
Write-Log "UI ready at $Url"

function Send-Response {
    param($Ctx, [string]$Body = '', [string]$Type = 'application/json; charset=utf-8', $Bytes = $null)
    try {
        $res = $Ctx.Response
        if (-not $res.Headers['Cache-Control']) { $res.Headers['Cache-Control'] = 'no-store' }
        $b = if ($null -ne $Bytes) { $Bytes } else { [Text.Encoding]::UTF8.GetBytes($Body) }
        $res.ContentType = $Type
        $res.ContentLength64 = $b.Length
        $res.OutputStream.Write($b, 0, $b.Length)
        $res.OutputStream.Flush()
    } catch { } finally { try { $Ctx.Response.Close() } catch { } }
}

function Handle-Request {
    param($Ctx)
    try {
        $req = $Ctx.Request
        $path = $req.Url.AbsolutePath.ToLowerInvariant()
        $q = $req.QueryString

        if ($path -eq '/' -or $path -eq '/index.html') { Send-Response $Ctx $Script:Html 'text/html; charset=utf-8'; return }

        if ($path -eq '/api/state') { Send-Response $Ctx (Get-StateJson); return }

        if ($path -eq '/api/rescan') {
            $Script:ExtractReport = Expand-AllArchives
            $Script:Schemes = Get-Schemes
            $Script:Status = "Scan done - $(@($Script:Schemes).Count) pack(s) found"
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/reextract') {
            $Script:ExtractReport = Expand-AllArchives -Force
            $Script:Schemes = Get-Schemes
            $Script:Status = "Re-extracted - $(@($Script:Schemes).Count) pack(s)"
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/save') {
            $body = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
            if ($body) {
                $inc = $body | ConvertFrom-Json
                foreach ($p in $inc.PSObject.Properties) {
                    Add-Member -InputObject $Script:Cfg -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
                }
            }
            $iv = Get-IntervalSeconds $Script:Cfg
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'intervalSeconds' -NotePropertyValue $iv -Force
            Save-Config $Script:Cfg
            $Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
            $Script:Status = 'Settings saved'
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/apply') {
            $n = [string]$q['scheme']
            $s = $Script:Schemes | Where-Object { $_.name -eq $n } | Select-Object -First 1
            if ($s) {
                if (Apply-Scheme -Scheme $s -Cfg $Script:Cfg) {
                    $Script:Cfg.lastScheme = $s.name
                    Save-Config $Script:Cfg
                    $Script:Status = "Applied: $($s.name)"
                    $Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
                }
            } else { $Script:Status = 'Pack not found' }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/toggle') {
            $n = [string]$q['name']; $on = ([string]$q['on'] -eq '1')
            $off = New-Object System.Collections.Generic.List[string]
            foreach ($x in @(Get-Prop $Script:Cfg 'disabledSchemes')) { if ($x -and $x -ne $n) { $off.Add([string]$x) } }
            if (-not $on) { $off.Add($n) }
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]$off.ToArray()) -Force
            Save-Config $Script:Cfg
            $Script:Status = if ($on) { "Enabled: $n" } else { "Disabled: $n" }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/install7zip') {
            $Script:Status = Install-SevenZip
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/keepsize') {
            $want = [string]$q['size']
            $off = New-Object System.Collections.Generic.List[string]
            foreach ($sc in $Script:Schemes) {
                $ln = ([string]$sc.name).ToLowerInvariant()
                $tag = 'Standard'
                if ($ln -match 'extra[\s_-]*large|xl\b') { $tag = 'Extra Large' }
                elseif ($ln -match '\blarge\b') { $tag = 'Large' }
                elseif ($ln -match '\bsmall\b') { $tag = 'Small' }
                elseif ($ln -match 'regular|medium|normal') { $tag = 'Regular' }
                if ($tag -ne $want -and $tag -ne 'Standard') { $off.Add([string]$sc.name) }
            }
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]$off.ToArray()) -Force
            Save-Config $Script:Cfg
            $Script:Status = "Keeping only '$want' size packs ON"
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/togglegroup') {
            $g = [string]$q['group']; $on = ([string]$q['on'] -eq '1')
            $off = New-Object System.Collections.Generic.List[string]
            foreach ($x in @(Get-Prop $Script:Cfg 'disabledSchemes')) { if ($x) { $off.Add([string]$x) } }
            foreach ($sc in $Script:Schemes) {
                $grp = ([string]$sc.name) -split '[\\/]' | Select-Object -First 1
                if ($grp -ne $g) { continue }
                if ($on) { $off.Remove([string]$sc.name) | Out-Null } elseif ($off -notcontains $sc.name) { $off.Add([string]$sc.name) }
            }
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]$off.ToArray()) -Force
            Save-Config $Script:Cfg
            $Script:Status = if ($on) { "Group ON: $g" } else { "Group OFF: $g" }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/toggleall') {
            $on = ([string]$q['on'] -eq '1')
            $off = @()
            if (-not $on) { $off = [string[]]@($Script:Schemes | ForEach-Object { $_.name }) }
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue $off -Force
            Save-Config $Script:Cfg
            $Script:Status = if ($on) { 'All packs enabled' } else { 'All packs disabled' }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/resetmap') {
            $n = [string]$q['name']
            $ovAll = Get-Prop $Script:Cfg 'overrides'
            if ($ovAll -and $ovAll.PSObject.Properties[$n]) { $ovAll.PSObject.Properties.Remove($n) }
            Save-Config $Script:Cfg
            $Script:Status = "Auto detect restored for: $n"
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/autofix') {
            $Script:ExtractReport = Expand-AllArchives -Force
            $Script:Schemes = Get-Schemes
            if (@($Script:Schemes).Count -eq 0) {
                foreach ($id in @('bibata-modern-ice','googledot-blue','macos-black')) { Download-StoreItem -Id $id | Out-Null }
                $Script:Schemes = Get-Schemes
                $Script:Status = "Auto fix: downloaded starter packs - $(@($Script:Schemes).Count) pack(s) ready"
            } else {
                $Script:Status = "Auto fix: $(@($Script:Schemes).Count) pack(s) found"
            }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/random')  { Do-Rotate | Out-Null; Send-Response $Ctx (Get-StateJson); return }
        if ($path -eq '/api/restore') { if (Restore-OriginalScheme) { $Script:Status = 'Windows default cursors restored' }; Send-Response $Ctx (Get-StateJson); return }
        if ($path -eq '/api/autorun') {
            $on = ([string]$q['on'] -eq '1')
            Set-Autorun -Enable $on | Out-Null
            $Script:Status = if ($on) { 'Autorun enabled' } else { 'Autorun disabled' }
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/download') {
            $msg = Download-StoreItem -Id ([string]$q['id'])
            $Script:Schemes = Get-Schemes
            $Script:Status = $msg
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/toggleweak') {
            $off = New-Object System.Collections.Generic.List[string]
            foreach ($x in @(Get-Prop $Script:Cfg 'disabledSchemes')) { if ($x) { $off.Add([string]$x) } }
            $n = 0
            foreach ($sc in $Script:Schemes) {
                if ($sc.coverage -lt 6 -and -not $off.Contains([string]$sc.name)) { $off.Add([string]$sc.name); $n++ }
            }
            Add-Member -InputObject $Script:Cfg -NotePropertyName 'disabledSchemes' -NotePropertyValue ([string[]]$off.ToArray()) -Force
            Save-Config $Script:Cfg
            $Script:Status = "$n incomplete pack(s) turned OFF"
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/downloadmany') {
            $ids = @(([string]$q['ids']) -split ',' | Where-Object { $_ })
            $Script:Status = Download-StoreMany -Ids $ids
            $Script:Schemes = Get-Schemes
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/downloadtag') {
            $sel = Get-StoreByTag -Tag ([string]$q['tag'])
            $Script:Status = Download-StoreMany -Ids @($sel | ForEach-Object { $_.id })
            $Script:Schemes = Get-Schemes
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/renamepack') {
            $Script:Status = Rename-Pack -Name ([string]$q['name']) -NewName ([string]$q['to'])
            $Script:Schemes = Get-Schemes
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/deletepack') {
            $withZip = ([string]$q['zip'] -ne '0')
            $Script:Status = Remove-Pack -Name ([string]$q['name']) -WithArchive $withZip
            $Script:Schemes = Get-Schemes
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/removeall') {
            $Script:Status = Invoke-RemoveEverything -DeletePacks ([string]$q['packs'] -eq '1')
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/upload') {
            $body = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
            $msg = 'Nothing received'
            if ($body) {
                $o = $body | ConvertFrom-Json
                $msg = Save-UploadedFile -FileName ([string]$o.name) -Folder ([string]$o.folder) -Data ([string]$o.data)
            }
            $Script:Schemes = Get-Schemes
            $Script:Status = $msg
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/createpack') {
            $body = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
            $msg = 'Nothing received'
            if ($body) {
                $o = $body | ConvertFrom-Json
                $msg = New-CustomPack -Name ([string]$o.name) -Map $o.map
            }
            $Script:Schemes = Get-Schemes
            $Script:Status = $msg
            Send-Response $Ctx (Get-StateJson); return
        }
        if ($path -eq '/api/aniinfo') {
            $pa = [string]$q['p']
            if ($pa -and (Test-InsidePacks $pa) -and [System.IO.File]::Exists($pa)) {
                Send-Response $Ctx ((Get-AniMeta -Path $pa) | ConvertTo-Json -Depth 4 -Compress)
            } else {
                Send-Response $Ctx '{"ok":false,"frames":0}'
            }
            return
        }
        if ($path -eq '/api/openfolder') {
            $w = [string]$q['which']
            $t = if ($w -eq 'packs') { $PacksDir } elseif ($w -eq 'custom') { $CustomDir } elseif ($w -eq 'logs') { $DataDir } else { $Root }
            try { Start-Process explorer.exe $t } catch { }
            Send-Response $Ctx '{"ok":true}'; return
        }
        if ($path -eq '/api/exit') { $Script:Status = 'Exiting'; Send-Response $Ctx '{"ok":true}'; $Script:ShouldExit = $true; return }
        if ($path -eq '/file') {
            $p = [string]$q['p']
            $inRoot = $false
            if ($p) {
                foreach ($r in @($PacksDir)) {
                    if ($p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { $inRoot = $true; break }
                }
            }
            if ($inRoot -and [System.IO.File]::Exists($p)) {
                $frameQ = [string]$q['frame']
                if ($frameQ -ne '' -and $p.ToLowerInvariant().EndsWith('.ani')) {
                    $bytes = Get-AniFrameBytes -Path $p -Index ([int]$frameQ)
                } else {
                    $bytes = Get-CursorPreviewBytes -Path $p
                }
                if ($null -ne $bytes) {
                    $Ctx.Response.Headers['Cache-Control'] = 'public, max-age=86400'
                    Send-Response $Ctx '' 'image/vnd.microsoft.icon' $bytes
                } else {
                    $Ctx.Response.StatusCode = 415
                    Send-Response $Ctx '{"error":"preview not available"}'
                }
            } else { $Ctx.Response.StatusCode = 404; Send-Response $Ctx '{"error":"not found"}' }
            return
        }
        $Ctx.Response.StatusCode = 404
        Send-Response $Ctx '{"error":"not found"}'
    } catch {
        Log-Err $_ 'Handle-Request'
        try { $Ctx.Response.StatusCode = 500; Send-Response $Ctx ('{"ok":false,"status":"Server error"}') } catch { }
    }
}

# ---------- Tray ----------
$notify = $null
try {
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $ico = $null
    try { $ico = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $env:SystemRoot 'System32\main.cpl')) } catch { }
    if ($null -eq $ico) { $ico = [System.Drawing.SystemIcons]::Application }
    $notify.Icon = $ico
    $notify.Text = 'Cursor Rotator'
    $notify.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $miOpen  = $menu.Items.Add('Open Control Panel')
    $miNow   = $menu.Items.Add('Change Cursor Now')
    $miPause = $menu.Items.Add('Pause / Resume Rotation')
    $miRest  = $menu.Items.Add('Restore Windows Cursors')
    $menu.Items.Add('-') | Out-Null
    $miExit  = $menu.Items.Add('Exit')
    $notify.ContextMenuStrip = $menu

    $miOpen.Add_Click({ try { Start-Process $Url } catch { } })
    $notify.Add_DoubleClick({ try { Start-Process $Url } catch { } })
    $miNow.Add_Click({ Do-Rotate | Out-Null })
    $miPause.Add_Click({
        $Script:Cfg.enabled = -not $Script:Cfg.enabled
        Save-Config $Script:Cfg
        $Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
    })
    $miRest.Add_Click({ Restore-OriginalScheme | Out-Null })
    $miExit.Add_Click({ $Script:ShouldExit = $true })

    if ($Script:Cfg.notifications) {
        $notify.BalloonTipTitle = 'Cursor Rotator'
        $notify.BalloonTipText = "Running in tray. Control panel: $Url"
        $notify.ShowBalloonTip(3000)
    }
} catch { Write-Log "Tray icon unavailable: $($_.Exception.Message)" 'WARN' }

if (-not $NoBrowser) { try { Start-Process $Url } catch { } }

# ---------- Hotkeys ----------
$Script:HK = $null
try {
    if ($Script:Cfg.hotkeys -and ('CR.HotKeys' -as [type])) {
        $Script:HK = New-Object CR.HotKeys
        # MOD_ALT=1, MOD_CONTROL=2 ; VK_C=0x43, VK_P=0x50
        $Script:HK.Add(1, 3, 0x43) | Out-Null   # Ctrl+Alt+C
        $Script:HK.Add(2, 3, 0x50) | Out-Null   # Ctrl+Alt+P
        Write-Log 'Hotkeys ready: Ctrl+Alt+C = change now, Ctrl+Alt+P = pause/resume'
    }
} catch { Write-Log "Hotkey registration failed: $($_.Exception.Message)" 'WARN' }

# ---------- Main loop (single thread: HTTP + timer + tray) ----------
$task = $Script:Listener.GetContextAsync()
while (-not $Script:ShouldExit) {
    try {
        if ($task.IsCompleted) {
            $ctx = $null
            try { $ctx = $task.Result } catch { }
            $task = $Script:Listener.GetContextAsync()
            if ($ctx) { Handle-Request -Ctx $ctx }
        } else {
            Start-Sleep -Milliseconds 60
        }
        try { [System.Windows.Forms.Application]::DoEvents() } catch { }

        if ($Script:HK -and [CR.HotKeys]::Last -ne 0) {
            $hid = [CR.HotKeys]::Last
            [CR.HotKeys]::Last = 0
            if ($hid -eq 1) { Do-Rotate | Out-Null }
            elseif ($hid -eq 2) {
                $Script:Cfg.enabled = -not $Script:Cfg.enabled
                Save-Config $Script:Cfg
                $Script:NextChange = (Get-Date).AddSeconds((Get-IntervalSeconds $Script:Cfg))
                $Script:Status = if ($Script:Cfg.enabled) { 'Rotation resumed' } else { 'Rotation paused' }
            }
        }

        if ($Script:Cfg.enabled -and (Get-Date) -ge $Script:NextChange) {
            $n = Do-Rotate
            if ($n -and $Script:Cfg.notifications -and $notify) {
                try {
                    $notify.BalloonTipTitle = 'Cursor changed'
                    $notify.BalloonTipText = [string]$n
                    $notify.ShowBalloonTip(1500)
                } catch { }
            }
        }
        if ($notify) {
            $t = if ($Script:Cfg.enabled) { 'Cursor Rotator - running' } else { 'Cursor Rotator - paused' }
            if ($notify.Text -ne $t) { try { $notify.Text = $t } catch { } }
        }
    } catch {
        Log-Err $_ 'MainLoop'
        Start-Sleep -Milliseconds 300
        try { if (-not $task -or $task.IsCompleted) { $task = $Script:Listener.GetContextAsync() } } catch { }
    }
}

try { if ($Script:HK) { $Script:HK.RemoveAll(); $Script:HK.DestroyHandle() } } catch { }
try { if ($notify) { $notify.Visible = $false; $notify.Dispose() } } catch { }
try { $Script:Listener.Stop(); $Script:Listener.Close() } catch { }
Write-Log '--- Cursor Rotator stopped ---'
