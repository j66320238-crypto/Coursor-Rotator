# Cursor Rotator — Command Line & API Reference

All commands are run from inside the `CursorRotator` folder. If you prefer clicking, every common
command also has a ready-made `.bat` file (see the bottom of this page).

---

## Starting the app

```powershell
# normal start: tray icon + control panel in your browser
powershell -ExecutionPolicy Bypass -File .\CursorRotator.ps1

# hidden start, no browser (this is what the autorun shortcut uses)
powershell -ExecutionPolicy Bypass -File .\CursorRotator.ps1 -Silent -NoBrowser

# serve the control panel on a different port
powershell -ExecutionPolicy Bypass -File .\CursorRotator.ps1 -Port 9000
```

If the chosen port is busy the app automatically tries the next four ports and writes the final
address to `Data\log.txt`.

---

## One-shot commands

These do their job and exit. They work whether or not the app is already running.

| Command | What it does |
|---|---|
| `.\CursorRotator.ps1 -List` | Lists every detected pack with its mapping score and ON/OFF state |
| `.\CursorRotator.ps1 -Random` | Applies a random enabled pack immediately |
| `.\CursorRotator.ps1 -Apply "Bibata"` | Applies a pack by full or partial name |
| `.\CursorRotator.ps1 -Restore` | Restores the original Windows cursors |
| `.\CursorRotator.ps1 -Unblock` | Clear the Windows "downloaded from the internet" flag on the app folder |
| `.\CursorRotator.ps1 -RemoveAll` | Restore cursors, delete settings, remove autorun (asks for confirmation) |
| `.\CursorRotator.ps1 -RemoveAll -DeletePacks` | The same, and delete every pack in `Packs\` |
| `.\CursorRotator.ps1 -Rescan` | Re-extracts all archives and rescans |
| `.\CursorRotator.ps1 -Every 30` | Sets the rotation interval in **seconds** (minimum 5) |
| `.\CursorRotator.ps1 -Download tags` | Lists the store categories and how many packs each holds |
| `.\CursorRotator.ps1 -Download list` | Shows the store catalogue: id, name, size, installed, tags |
| `.\CursorRotator.ps1 -Download list -Tag RGB` | Same list, one category only |
| `.\CursorRotator.ps1 -DownloadAll` | Downloads every store pack (about 90 MB) |
| `.\CursorRotator.ps1 -DownloadAll -Tag Animated` | Downloads one whole category |
| `.\CursorRotator.ps1 -Download bibata-rainbow-modern` | Downloads a single store pack by id |
| `.\Download-Cursors.ps1` | Interactive downloader menu |
| `.\Download-Cursors.ps1 -Tag Anime` | Downloads a category, no questions asked |
| `.\Download-Cursors.ps1 -Id pokemon,marathon` | Downloads specific ids |
| `.\Download-Cursors.ps1 -ListOnly` | Prints the catalogue and waits |
| `.\CursorRotator.ps1 -Setup7Zip` | Downloads the portable 7-Zip used for .rar and .7z |

### Examples

```powershell
.\CursorRotator.ps1 -Every 15                              # change every 15 seconds
.\CursorRotator.ps1 -Every 3600                            # change once an hour
.\CursorRotator.ps1 -Apply "GoogleDot-Blue-Regular-Windows"
.\CursorRotator.ps1 -Download macos-black
```

### Store pack ids (33)

| id | tags |
|---|---|
| `bibata-modern-ice` | Light, Minimal, Popular |
| `bibata-modern-classic` | Dark, Minimal, Popular |
| `bibata-modern-amber` | Colorful, Minimal |
| `bibata-original-ice` | Light, Minimal |
| `bibata-original-classic` | Dark, Minimal |
| `bibata-original-amber` | Colorful, Minimal |
| `bibata-rainbow-modern` | **RGB, Animated**, Colorful, Game |
| `bibata-rainbow-original` | **RGB, Animated**, Colorful, Game |
| `bibata-extra-modern` | Colorful, Bundle, Minimal (4 colours in one zip) |
| `bibata-extra-original` | Colorful, Bundle, Minimal (4 colours in one zip) |
| `bibata-pink` / `bibata-dodgerblue` / `bibata-turquoise` | Colorful, Minimal |
| `bibata-darkred` | Colorful, Dark |
| `googledot-blue` / `googledot-red` | Minimal, Colorful |
| `googledot-black` | Minimal, Dark |
| `googledot-white` | Minimal, Light |
| `macos-black` | macOS, Dark, Minimal |
| `macos-white` | macOS, Light, Minimal |
| `notwaita-black` / `notwaita-gray` | Dark, Animated, Minimal |
| `notwaita-white` | Light, Animated, Minimal |
| `pokemon` | Game, Animated, Colorful, Fun |
| `marathon` | Game, Animated, Dark, Bundle |
| `modern-v2-dark` | Dark, Windows11, Minimal |
| `modern-v2-light` | Light, Windows11, Minimal |
| `anime-neuro-sama` | Anime, Animated, Fun, Colorful |
| `anime-ellen-joe` / `anime-noelle` / `anime-wanderer` | Anime, Animated, Fun, Game |
| `anime-kuro` / `anime-shiori` | Anime, Animated, Fun |

Categories: `Animated Anime Bundle Colorful Dark Fun Game Light macOS Minimal Popular RGB Windows11`

---

## Global hotkeys (while the app is running)

| Hotkey | Action |
|---|---|
| `Ctrl + Alt + C` | Change to another random pack now |
| `Ctrl + Alt + P` | Pause / resume rotation |

Both can be disabled with the **Global hotkeys** switch in the control panel.

---

## Local HTTP API

The control panel is a normal web page talking to a small local server, so you can automate
everything yourself. Base address: `http://127.0.0.1:8777` (or whichever port the log reports).
Every endpoint returns the full state as JSON.

| Endpoint | Purpose |
|---|---|
| `GET /api/state` | Complete status: config, packs, roles, store, diagnostics |
| `GET /api/random` | Apply a random enabled pack |
| `GET /api/apply?scheme=NAME` | Apply one specific pack |
| `GET /api/toggle?name=NAME&on=1\|0` | Switch a single pack on or off |
| `GET /api/togglegroup?group=NAME&on=1\|0` | Switch every pack from one archive on or off |
| `GET /api/toggleall?on=1\|0` | Switch all packs on or off |
| `GET /api/keepsize?size=Regular` | Keep only that size ON (`Small`, `Regular`, `Large`, `Extra Large`) |
| `POST /api/save` | Save settings — JSON body, e.g. `{"intervalSeconds":300,"enabled":true}` |
| `GET /api/resetmap?name=NAME` | Drop custom cursor assignments for a pack |
| `GET /api/download?id=ID` | Download and install a store pack |
| `GET /api/downloadmany?ids=A,B,C` | Download several store packs in one request |
| `GET /api/downloadtag?tag=RGB` | Download every store pack in a category |
| `GET /api/toggleweak` | Switch OFF every pack with fewer than 6 of the 17 cursor jobs |
| `GET /api/renamepack?name=N&to=X` | Rename a pack folder (settings follow the new name) |
| `GET /api/deletepack?name=N[&zip=0]` | Delete a pack folder, and its archive unless `zip=0` |
| `GET /api/removeall[?packs=1]` | Restore cursors, clear settings and autorun; `packs=1` also deletes every pack |
| `GET /api/aniinfo?p=FILE` | Frame count, frame order and per-frame timing of an animated cursor |
| `GET /file?p=FILE&frame=N` | One frame of an `.ani` as an icon (used by the animated previews) |
| `POST /api/upload` | `{"name":"pack.zip","folder":"","data":"<base64>"}` - upload an archive or a cursor file |
| `POST /api/createpack` | `{"name":"My mix","map":{"Arrow":"C:\\...\\a.cur"}}` - build a custom pack |
| `GET /api/install7zip` | Download and set up portable 7-Zip |
| `GET /api/rescan` | Extract new archives and rescan |
| `GET /api/reextract` | Force re-extract every archive |
| `GET /api/autofix` | Force re-extract, and download starter packs if nothing is found |
| `GET /api/restore` | Restore the original Windows cursors |
| `GET /api/autorun?on=1\|0` | Add or remove the Startup shortcut |
| `GET /api/openfolder?which=packs\|logs` | Open a folder in Explorer |
| `GET /api/exit` | Shut the app down |
| `GET /file?p=PATH` | Preview a cursor file as a browser-readable icon |

### Example: change the interval to 2 minutes from any script

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:8777/api/save' -Method POST `
  -Body '{"intervalSeconds":120}' -UseBasicParsing
```

---

## Ready-made .bat files

| File | Equivalent command |
|---|---|
| `Start.bat` | Normal start |
| `Start (with console - debug).bat` | Start with a visible console |
| `Stop.bat` | Exit the app, then force-close leftovers |
| `Update - Stop and Unlock Folder.bat` | Stop everything and free the folder for updating |
| `Change Cursor Now.bat` | `-Random` |
| `List Packs.bat` | `-List` |
| `Rescan Packs.bat` | `-Rescan` |
| `Download Top Cursors.bat` | `-DownloadAll` |
| `Download Cursor Packs (menu).bat` | `Download-Cursors.ps1` (interactive menu) |
| `Download RGB and Animated Packs.bat` | `Download-Cursors.ps1 -Tag RGB` then `-Tag Animated` |
| `Remove Everything (uninstall).bat` | `-RemoveAll`, optionally with `-DeletePacks` |
| `Unblock Files (fix Windows warning).bat` | `-Unblock` |
| `Extract All Packs.bat` | Extraction only |
| `Restore Windows Cursors.bat` | Restore defaults without launching the app |

---

## Extraction rules

1. `.zip` uses the built-in unzip — no external tool needed.
2. `.rar` and `.7z` use 7-Zip. If it is missing, the app downloads a portable copy into
   `Tools\7zip\` (no install, no admin rights).
3. WinRAR is only a last resort, because its trial dialog can block silent extraction.
4. Every archive is extracted **once**, into a folder of the same name next to it, tracked by an
   `.extracted.txt` marker.

---

## Files the app writes

| Path | Contents |
|---|---|
| `Data\config.json` | All your settings, disabled packs and custom cursor assignments |
| `Data\original-scheme.json` | Backup of your cursors from before the first change |
| `Data\log.txt` | Timestamped log of every action and error |
| `Packs\<name>\.extracted.txt` | Marker that stops repeated extraction |
| `Tools\7zip\` | Portable 7-Zip, only if it was ever needed |
| Startup shortcut | Only while **Start with Windows** is enabled |
