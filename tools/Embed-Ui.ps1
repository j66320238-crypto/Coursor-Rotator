<#
    Embed-Ui.ps1
    Copies ui.html into the $Script:Html here-string inside CursorRotator.ps1.
    Run this after every UI edit, then commit both files.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app  = Join-Path $root 'CursorRotator.ps1'
$ui   = Join-Path $root 'ui.html'

$html = [System.IO.File]::ReadAllText($ui)
if ($html -match "(?m)^'@") { throw "ui.html contains a line starting with '@ - that would end the here-string." }

$src   = [System.IO.File]::ReadAllText($app)
$open  = "`$Script:Html = @'`n"
$start = $src.IndexOf($open)
if ($start -lt 0) { throw 'Could not find $Script:Html in CursorRotator.ps1' }
$start += $open.Length
$end = $src.IndexOf("`n'@", $start)
if ($end -lt 0) { throw 'Could not find the end of the here-string' }

$out = $src.Substring(0, $start) + $html.TrimEnd("`r", "`n") + $src.Substring($end)
[System.IO.File]::WriteAllText($app, $out)

$err = $null
[System.Management.Automation.Language.Parser]::ParseFile($app, [ref]$null, [ref]$err) | Out-Null
if ($err -and $err.Count) { $err | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }; throw 'Syntax error after embedding' }
Write-Host ("UI embedded ({0} characters). Syntax OK." -f $html.Length) -ForegroundColor Green
