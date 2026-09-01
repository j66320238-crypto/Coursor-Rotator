# Contributing

Thanks for wanting to help. This is a single-file PowerShell app, so contributing is easy.

## Project layout

| Path | What it is |
|---|---|
| `CursorRotator.ps1` | The whole application. The web UI is embedded near the bottom in a `@'...'@` here-string. |
| `ui.html` | The editable copy of that UI. **Edit this file, then re-embed it.** |
| `Download-Cursors.ps1`, `Extract-Packs.ps1` | Helper scripts |
| `*.bat` | Shortcuts for people who never open a terminal (CRLF line endings, please) |
| `docs/` | User guide and command reference |
| `tools/` | Release helpers |

## Editing the UI

```powershell
# 1. edit ui.html
# 2. put it back inside the app
.\tools\Embed-Ui.ps1
# 3. run it
.\CursorRotator.ps1
```

## Adding a pack to the store

Find the release asset URL of a Windows cursor pack (a `.zip` containing `.cur` / `.ani` files and
ideally an `install.inf`), then add one line to `$Script:Store` in `CursorRotator.ps1`:

```powershell
@{ id='my-pack'; name='My Pack'; author='someone'; desc='One sentence.';
   url='https://github.com/someone/repo/releases/download/v1.0/My-Pack-Windows.zip';
   size='0.5 MB'; tags=@('Animated','Dark') }
```

Rules:

* Link the author's own release asset — never re-host the pack in this repository.
* Use existing tags where possible: `RGB Animated Anime Game Fun Minimal Colorful Dark Light macOS Windows11 Bundle Popular`.
* Check the pack's licence allows redistribution by link (it always does) and add it to `THIRD-PARTY.md`.
* Test with `.\CursorRotator.ps1 -Download my-pack` and then `-List` to confirm the coverage.

## Style

* PowerShell 5.1 compatible — no `??`, no ternaries, no PS7-only cmdlets.
* Use `[System.IO.Directory]` / `[System.IO.File]` instead of `Get-ChildItem` / `Test-Path`:
  pack folder names contain `[` `]` `#`, which break provider paths.
* Return arrays as `, ([object[]]$list.ToArray())` so `.Count` behaves.
* Keep everything in English, and keep the app runnable with zero dependencies.

## Before opening a PR

```powershell
# syntax check
$e=$null; [System.Management.Automation.Language.Parser]::ParseFile("$PWD\CursorRotator.ps1",[ref]$null,[ref]$e); $e

# smoke test
.\CursorRotator.ps1 -List
.\CursorRotator.ps1 -Download list
```
