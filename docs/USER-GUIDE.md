# Cursor Rotator 1.0

**Automatic random mouse cursor changer for Windows.**

Drop your cursor packs in one folder. The app unpacks them once, figures out which file is the
arrow, which one is the loading spinner, the text beam, the link hand and so on, and then swaps
your whole cursor theme on a timer you choose — anywhere from every 5 seconds to once a day.

Everything runs locally. No installation, no administrator rights, no ads, no background telemetry.

---

## Simple and Advanced mode

The switch at the top right of the control panel decides how much you see.

* **Simple** - the pack list, the interval, ON/OFF switches and the store. Enough for
  everyday use.
* **Advanced** - everything above plus manual cursor assignment, hotkeys, the custom pack
  builder, the diagnostics tab, the updater and the "remove everything" zone.

Your choice is stored in the browser, so the panel opens the same way next time.

## Which pack is running right now?

The first card in the control panel, **Now on your screen**, always shows the pack Windows
is actually using: its name, animated previews of the main pointers, the time it was
applied and how long until the next change. If it says nothing is applied yet, press
**Change now**.

## Duplicates

Packs are fingerprinted by their contents. If two folders hold exactly the same cursors
(the same zip unpacked twice, a copy, a re-download), the later one gets a **DUPLICATE**
badge, is skipped by the rotation, and can be deleted with **Remove duplicates**.
Uploading an archive you already have is refused instead of creating a second copy.

## Updating

Press **Check for updates** in Advanced mode, or run `Update.bat`. Nothing is downloaded
until you confirm, and your packs and settings survive the update.

## Table of contents

1. [Quick start](#1-quick-start)
1b. [Windows says "The publisher could not be verified"](#1b-windows-says-the-publisher-could-not-be-verified)
2. [How the folders work](#2-how-the-folders-work)
3. [Getting cursor packs](#3-getting-cursor-packs)
4. [The control panel](#4-the-control-panel)
5. [Assigning cursors manually](#5-assigning-cursors-manually)
6. [Keyboard shortcuts and tray menu](#6-keyboard-shortcuts-and-tray-menu)
7. [Command line](#7-command-line)
8. [Turning things off and undoing everything](#8-turning-things-off-and-undoing-everything)
9. [Archive extraction (zip / rar / 7z)](#9-archive-extraction-zip--rar--7z)
10. [Updating the app](#10-updating-the-app)
11. [Troubleshooting](#11-troubleshooting)
12. [File reference](#12-file-reference)
13. [How auto-detection works](#13-how-auto-detection-works)
14. [Privacy and safety](#14-privacy-and-safety)

---

## 1. Quick start

1. Put the `CursorRotator` folder anywhere you like, for example `E:\mouse pointers\CursorRotator`.
2. Copy your cursor **.zip** packs into `CursorRotator\Packs\`.
3. Double-click **`Start.bat`**.

That is it. On the first run the app will:

* unpack every archive **once**,
* detect which cursor file belongs to which job,
* apply a random pack straight away,
* move to the system tray,
* open the control panel in your browser at `http://127.0.0.1:8777`.

**No packs yet?** Skip step 2 and double-click **`Download Top Cursors.bat`**, or open the
**Download Store** tab in the control panel.

> First launch may show a Windows SmartScreen or firewall prompt. The app only listens on
> `127.0.0.1` (your own machine), so you can safely allow it — or block it, the UI still works.

---

## 1b. Windows says "The publisher could not be verified"

![Windows security warning](unblock.png)

This is not a virus warning and nothing is wrong with the files. Windows attaches a hidden
*"downloaded from the internet"* mark (the *Mark of the Web*) to everything that comes out of a
downloaded ZIP, and then warns before running any script from it.

Fix it in whichever way suits you:

1. **Before extracting** — right-click the downloaded ZIP → **Properties** → tick **Unblock** → OK,
   then extract. The warning never appears.
2. **Already extracted** — double-click **`Unblock Files (fix Windows warning).bat`** once, or run
   `.\CursorRotator.ps1 -Unblock`. It clears the mark for the whole folder.
3. **Do nothing** — press **Run** in the dialog. The app clears the mark from its own folder at
   every startup, so from the second launch the prompt is gone.

If your PC also refuses with *"running scripts is disabled on this system"*, that is the PowerShell
execution policy. Every `.bat` in this app already starts PowerShell with `-ExecutionPolicy Bypass`,
so it only affects you if you run the `.ps1` files by hand. In that case use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CursorRotator.ps1
```

---

## 2. How the folders work

```
CursorRotator\
├── Start.bat                  ← run this
├── CursorRotator.ps1          ← the app (server + rotation engine + UI)
├── Packs\                     ← your cursor packs live here
│     my-pack.zip              ← the archive you dropped in
│     my-pack\                 ← unpacked once, right next to the zip
│         .extracted.txt       ← marker so it is never unpacked again
├── Data\                      ← settings, cursor backup, log
├── Tools\                     ← portable 7-Zip, only if it is ever needed
└── ui.html                    ← source copy of the control panel
```

**Each archive is extracted exactly once.** The `.extracted.txt` marker stores the archive's size and
date. On the next start the app sees the marker and skips it, so startup stays instant. It re-extracts
only if you replace the zip with a different one, delete the marker, or press
*Force re-extract all zips* in the app.

Every folder that contains cursor files becomes one selectable "pack". Most themes ship
Small / Regular / Large / Extra Large copies, so one zip usually produces three or four packs.

---

## 3. Getting cursor packs

### Your own packs
Copy the `.zip` files into `Packs\` and press **Rescan** in the control panel (or just restart the app).

### The built-in store
**56 free, open-source packs** are bundled as download links — no accounts, no bundled software,
everything comes straight from public GitHub releases.

| Category (tag) | Packs |
|---|---|
| **RGB** | Bibata Rainbow Modern, Bibata Rainbow Original — colour-cycling rainbow cursors, every single cursor animated |
| **Animated** | The two Rainbow packs, all six Anime packs, Pokemon, Marathon, Notwaita Black / Gray / White (13 packs total) |
| **Anime** | Neuro-sama, Ellen Joe, Kuro, Noelle, Shiori Novella, Wanderer — animated character cursors |
| **Game / Fun** | Pokemon (pokeball loading rings), Marathon Bold + Regular (sci-fi) |
| **Minimal** | Bibata Modern / Original (Ice, Classic, Amber), GoogleDot (Blue, Black, White, Red), macOS Black / White, Notwaita |
| **Colorful** | Bibata Pink, Dodger Blue, Turquoise, Dark Red, plus the two "Extra" bundles that contain four colours each |
| **Dark / Light** | Modern Cursors v2 Dark / Light (Windows 11 style), plus the dark and light variants above |
| **macOS** | macOS Cursors Black / White |

Four ways to download them:

**a) From the control panel — Download Store tab**
* Type in the **search box** (`rgb`, `anime`, `dark`, `macos`, ...).
* Click a **category chip**: All, Not installed, Installed, RGB, Animated, Anime, Game, Minimal,
  Colorful, Dark, Light, macOS, Windows11, Bundle, Popular, Fun.
* **Tick the checkboxes** of the packs you want and press **Download selected (n)** —
  a progress bar shows which pack is downloading and how many are left.
* Or press **Download all shown** to grab everything currently visible in the filter.

**b) The download script (menu)**
Double-click **`Download Cursor Packs (menu).bat`**. It asks what you want:
everything / RGB only / animated only / anime only / minimal only / just show the list.

**c) One-click shortcuts**
* `Download RGB and Animated Packs.bat` — the flashy stuff, about 30 MB.
* `Download Top Cursors.bat` — every pack in the store.

**d) From the command line**
```powershell
.\CursorRotator.ps1 -Download tags                  # list the categories
.\CursorRotator.ps1 -Download list                  # every pack: id, size, tags, installed
.\CursorRotator.ps1 -Download list -Tag Animated    # only that category
.\CursorRotator.ps1 -DownloadAll -Tag RGB           # download a whole category
.\CursorRotator.ps1 -Download bibata-rainbow-modern # download just one

.\Download-Cursors.ps1                              # interactive menu
.\Download-Cursors.ps1 -Tag Anime
.\Download-Cursors.ps1 -Id pokemon,marathon
```

Downloads go straight into `Packs\`, unpack themselves and join the rotation immediately.
Anything already installed is skipped. Downloading the whole store is roughly 90 MB compressed
and produces about 70 usable packs (many themes ship Small / Regular / Large / Extra Large copies).

**Too many packs?** Press **Only Regular** in the My Packs toolbar and every other size is switched
off automatically, or use **Turn group OFF** on a theme you do not want.

---

## 4. The control panel

Opens automatically at `http://127.0.0.1:8777`. You can reopen it any time by double-clicking the
tray icon. If that port is busy the app quietly moves to 8778–8781 and the log tells you which one.

### Rotation (left column)

| Setting | What it does |
|---|---|
| **Auto rotation** | Master on/off switch for the timer. |
| **Change cursor every** | Any number plus **Seconds / Minutes / Hours**. Minimum is 5 seconds. Quick buttons: 10s, 30s, 1m, 5m, 15m, 30m, 1h, 6h, 1 day. |
| **Random order** | Off means the packs are used in list order instead. |
| **Never repeat same pack twice** | Guarantees a different pack on each change. |
| **Fill missing cursors from the same pack** | On by default. If a pack has no Location / Person / Handwriting cursor, the pack's own arrow or hand is used instead of a Windows cursor, so the theme is never half-applied. See section 13. |
| **Change on app start** | Applies a new pack the moment the app launches. |
| **Tray notifications** | Small balloon tip whenever the cursor changes. |
| **Global hotkeys** | Enables `Ctrl+Alt+C` and `Ctrl+Alt+P`. |
| **Start with Windows** | Adds a hidden shortcut to your Startup folder. No admin needed. |

Every setting saves itself the moment you touch it — there is no Save button to forget.

The header shows a live countdown to the next change, the pack currently in use, and three buttons:
**Change Now**, **Rescan**, **Restore Windows Default**.

### Adding your own cursors (top of the My Packs tab)

The **Add your own cursors** box accepts three things:

* **Drag and drop** — drop a `.zip`, `.7z` or `.rar` straight onto it, or drop loose `.cur` / `.ani` files.
* **Upload ZIP / archive** — file picker for archives. They are saved into `Packs\` and unpacked at once.
* **Upload an unzipped folder** — if a pack is already extracted somewhere, pick the folder and every
  cursor inside it is copied into `Packs\<folder name>\`.

A progress bar shows each file, and anything that is not a cursor or archive is skipped with a note
instead of an error.

### Make your own pack (custom pack builder)

Left column → **Create custom pack**, or a pack's **⋮ → Use as base for a custom pack**.

1. Choose a pack in *Start from a pack* — all 17 jobs are filled with that pack's cursors.
2. Swap any single row for a cursor from any other pack. The filter box narrows the long lists,
   and the little preview next to each row animates if the file is an `.ani`.
3. Type a name and press **Create pack**.

The pack is written to `Packs\_My Custom Packs\<name>\` with files named after their job
(`Arrow.cur`, `Wait.ani`, ...), so detection is exact. It appears in My Packs immediately and takes
part in the rotation like anything else.

### My Packs tab

Each pack is a card showing:

* **Real previews** of the actual cursor files, with a letter badge —
  `A` normal arrow, `L` busy/loading, `W` working in background, `T` text select,
  `H` link select, `P` location, `M` move. Animated `.ani` cursors show their first frame.
  Hover a preview to see the file name.
* A coverage bar, for example **17/17 cursor jobs assigned**, plus the file count.
* An **ON/OFF switch** in the top-right corner, plus a coloured label under the name that spells it
  out: green **ON - in rotation** or red **OFF - never used**. Nothing ambiguous: a pack marked OFF
  is never applied, not at startup, not on a timer, not with the hotkey.
* Badges: purple **ANIMATED** (the pack contains `.ani` cursors), rainbow **RGB**,
  pink **ANIME**, and red **INCOMPLETE** when a folder has fewer than 6 of the 17 cursor jobs.
* **Apply** to use it right now, **Assign cursors** to edit it, and a **⋮ menu** with
  *Apply now*, *Rename pack*, *Assign cursors*, *Use as base for a custom pack* and
  *Delete pack from disk* (the folder and its archive are removed, after a confirmation).
* Previews of animated `.ani` cursors **play the real animation** at the pack's own frame timing.
  The **Play animations** checkbox in the toolbar turns that off if you prefer still images.

Above the cards: a search box; a filter with **All packs / Only ON / Only OFF / Only animated /
Only static / Only RGB**; **All ON**, **All OFF**, **Turn OFF incomplete** (switches off every pack
that is missing most of its cursors, e.g. leftover sub-folders inside a theme); and the
size buttons **Only Small / Only Regular / Only Large / Only Extra Large**.
Packs are grouped by the zip they came from, and each group has its own
**Turn group ON / OFF** button.

### Download Store tab
All 33 store packs with size, author, category badges and an Installed marker.
Search box + category chips + checkbox multi-select + a live download progress bar.

### Diagnostics tab
Shows the Packs folder path, how many folders were scanned, how many `.cur`/`.ani` files were found,
how many packs were detected, which archive extractor is active, the last error, and the extraction
log. Buttons: **Fix it for me**, **Rescan**, **Force re-extract all zips**,
**Download portable 7-Zip**, **Open log folder**.

*Fix it for me* force re-extracts everything, and if still nothing is found it downloads a few
starter packs so you are never stuck with an empty list.

---

## 5. Assigning cursors manually

Press **Assign cursors** on any pack. You get one row per cursor job:

| Cursor job | Where Windows uses it |
|---|---|
| Normal Select | The everyday arrow |
| Help Select | Arrow with a question mark |
| Working In Background | Arrow with a spinner — app is starting |
| Busy / Loading | The full loading spinner |
| Precision Select | Crosshair, used in editors |
| Text Select | The I-beam over text |
| Handwriting | Pen cursor |
| Unavailable | The "not allowed" circle |
| Vertical Resize | Resizing a window edge up/down |
| Horizontal Resize | Resizing left/right |
| Diagonal Resize 1 | Corner resize, top-left ↔ bottom-right |
| Diagonal Resize 2 | Corner resize, top-right ↔ bottom-left |
| Move | Moving a window or object |
| Alternate Select | The upward arrow |
| Link Select | The hand over links |
| Location Select | Location/pin pointer |
| Person Select | Person pointer |

Each row has a live preview, a dropdown with every file in the pack, and a badge telling you where
the current choice came from: **auto** (detected by the app), **custom** (chosen by you) or
**default** (left as the Windows cursor).

* Tick **Allow files from other packs** to mix and match — for example one pack's arrow with another
  pack's loading spinner.
* **Reset to auto detect** throws your changes away and goes back to the detected mapping.
* **Save** stores the mapping; **Save & Apply** stores it and applies the pack immediately.

Custom mappings are remembered per pack and survive restarts. A pack with custom choices is marked
with a `custom` chip on its card.

---

## 6. Keyboard shortcuts and tray menu

| Hotkey | Action |
|---|---|
| `Ctrl + Alt + C` | Change to another random cursor pack right now |
| `Ctrl + Alt + P` | Pause / resume the rotation |

Hotkeys work from anywhere in Windows and can be disabled with the **Global hotkeys** toggle.

Right-click the tray icon for: **Open Control Panel**, **Change Cursor Now**,
**Pause / Resume Rotation**, **Restore Windows Cursors**, **Exit**.
Double-click the tray icon to open the control panel.

---

## 7. Command line

Run these from the `CursorRotator` folder in PowerShell. Full details and the local HTTP API are in
**`COMMANDS.md`**.

```powershell
# start normally (tray + browser UI)
powershell -ExecutionPolicy Bypass -File .\CursorRotator.ps1

# start hidden, no browser window (what autorun uses)
powershell -ExecutionPolicy Bypass -File .\CursorRotator.ps1 -Silent -NoBrowser
```

One-shot commands that do the job and exit, even when the app is not running:

| Command | Action |
|---|---|
| `-List` | List every detected pack with its mapping score and ON/OFF state |
| `-Random` | Apply a random enabled pack now |
| `-Apply "Bibata"` | Apply a pack by full or partial name |
| `-Restore` | Restore the original Windows cursors |
| `-Rescan` | Re-extract archives and rescan |
| `-Every 30` | Set the rotation interval in **seconds** (minimum 5) |
| `-Download list` | Show the store catalogue |
| `-DownloadAll` | Download every store pack |
| `-Download <id>` | Download one store pack |
| `-Setup7Zip` | Fetch the portable 7-Zip used for rar/7z |
| `-Port 9000` | Serve the control panel on a different port |

---

## 8. Turning things off and undoing everything

| Goal | How |
|---|---|
| Pause rotation | Tray → *Pause*, `Ctrl+Alt+P`, or the **Auto rotation** toggle |
| Stop using one pack | Flip that pack's **ON/OFF** switch |
| Stop using a whole theme | **Turn group OFF** on the group header |
| Get the original cursors back | **Restore Windows Default** in the UI, `Restore Windows Cursors.bat`, or `-Restore` |
| Close the app | Tray → *Exit*, or `Stop.bat` |
| Remove autorun | Turn **Start with Windows** off |
| Remove the app completely | Restore default cursors, run `Stop.bat`, delete the folder. Nothing is left behind outside it except the optional Startup shortcut. |

Your original cursor scheme is backed up to `Data\original-scheme.json` the very first time the app
runs, so *Restore* always brings back exactly what you had before.

---

### Remove everything

Left column → **Danger zone → Remove everything** (or `Remove Everything (uninstall).bat`,
or `.\CursorRotator.ps1 -RemoveAll`). It:

1. restores your original Windows cursors,
2. deletes the Start-with-Windows shortcut,
3. deletes `Data\config.json` and the cursor backup,
4. and, only if you tick *Also delete all cursor packs*, empties the `Packs` folder.

After that the app folder can simply be deleted — nothing is left anywhere in Windows.

---

## 9. Archive extraction (zip / rar / 7z)

* **.zip** — handled by the app's built-in unzip. No external program required.
* **.rar / .7z** — handled by **7-Zip**. If 7-Zip is not installed, the app downloads a
  **portable copy into `Tools\7zip\`** by itself: nothing is installed, no admin rights are needed,
  and no WinRAR trial nag can block it.
* **WinRAR** is only used as a last resort, because its 40-day trial dialog can interrupt silent
  extraction.

The Diagnostics tab always shows which extractor is currently active, and has a
**Download portable 7-Zip** button if you want to set it up in advance. The automatic setup is
attempted only once per session, so a missing internet connection will never slow down your startup.

---

## 10. Updating the app

1. Run **`Update - Stop and Unlock Folder.bat`**. It asks the app to exit, kills anything left over,
   and closes Explorer windows that are sitting inside the folder.
2. Replace `CursorRotator.ps1`, `ui.html` and the `.bat` files with the new ones — or replace the
   whole folder.
3. Run `Start.bat` again.

Keep `Packs\` (your cursors) and `Data\` (settings plus your cursor backup) and everything carries
over. Since version 3.3 the app runs from your TEMP folder, so it no longer locks its own directory
and you can usually replace files even while it is running.

---

## 11. Troubleshooting

**"The action can't be completed because the folder is open in another program"**
The app is still running. Run `Update - Stop and Unlock Folder.bat`, or exit from the tray icon,
or run `Stop.bat`. Also make sure no Explorer window is open inside the folder and that
`Data\log.txt` is not open in Notepad.

**No packs are detected**
Open the **Diagnostics** tab. It shows how many folders were scanned and how many cursor files were
found. Press **Fix it for me**. If the count is zero, your packs are probably still zipped somewhere
else — copy them into `Packs\` and press **Rescan**.

**"Script cannot be loaded because running scripts is disabled"**
Do not double-click the `.ps1` file. Always start through `Start.bat`, which passes
`-ExecutionPolicy Bypass`.

**A .rar or .7z pack will not extract**
Diagnostics → **Download portable 7-Zip** → **Rescan**. WinRAR is not required.

**A preview box is empty**
That single cursor file could not be decoded; everything else keeps working. The app converts
`.cur` and `.ani` into browser-readable icons on the fly, using the first frame for animated cursors.

**The cursor did not change immediately**
A few applications hold on to the old cursor until you move the mouse over them or switch windows.
The registry and Windows itself are already updated.

**The control panel will not open**
Check `Data\log.txt` for the line `UI ready at http://127.0.0.1:PORT/` and open that address —
the app moves to 8778–8781 if 8777 is taken.

**Anything else**
`Data\log.txt` records every action and every error with a timestamp.

---

## 12. File reference

| File | Purpose |
|---|---|
| `Start.bat` | Normal start: tray icon plus control panel |
| `Start (with console - debug).bat` | Same, but with a visible console for troubleshooting |
| `Stop.bat` | Ask the app to exit, then force-close anything left |
| `Update - Stop and Unlock Folder.bat` | Frees the folder so you can replace or delete it |
| `Change Cursor Now.bat` | Apply a random pack once |
| `List Packs.bat` | Print all detected packs |
| `Rescan Packs.bat` | Re-extract and rescan |
| `Download Cursor Packs (menu).bat` | Interactive downloader: pick a category and go |
| `Download RGB and Animated Packs.bat` | Grabs the RGB and animated packs in one go |
| `Download Top Cursors.bat` | Download every store pack |
| `Download-Cursors.ps1` | The downloader script behind the two `.bat` files above |
| `Remove Everything (uninstall).bat` | Restore cursors, clear settings/autorun, optionally delete packs |
| `Unblock Files (fix Windows warning).bat` | Clears the "downloaded from the internet" mark |
| `Create Custom Pack (open app).bat` | Starts the app and opens the control panel (builder lives there) |
| `Packs\_My Custom Packs\` | Packs you build yourself with the mixer |
| `MANIFEST.txt` | List of every file in this package with size and SHA-256, so you can verify nothing is missing |
| `Extract All Packs.bat` | Extraction only, without starting the app |
| `Restore Windows Cursors.bat` | Restore the original cursors without the app |
| `CursorRotator.ps1` | The application |
| `Extract-Packs.ps1` | Standalone extractor used by `Extract All Packs.bat` |
| `ui.html` | Editable copy of the control panel (already embedded in the app) |
| `docs/COMMANDS.md` | Command line and HTTP API reference |
| `docs/USER-GUIDE.md` | This manual |
| `README.md` | Project overview (GitHub front page) |
| `LICENSE` / `THIRD-PARTY.md` | MIT licence, and credits/licences of the store packs |
| `CHANGELOG.md` | What changed in each version |
| `tools\Embed-Ui.ps1` | Puts `ui.html` back inside the app after you edit it |
| `tools\Build-Release.ps1` | Builds `MANIFEST.txt` and a release zip |
| `Packs\` | Your archives and their unpacked folders |
| `Data\` | `config.json`, `original-scheme.json`, `log.txt` |
| `Tools\7zip\` | Portable 7-Zip, created only when needed |

---

## 13. How auto-detection works

For every folder that contains `.cur` or `.ani` files the app builds a map of the **17 cursor jobs**
Windows knows about, in this order:

1. **`install.inf`** — if the pack ships one, its `[Strings]` and `[Wreg]` sections are parsed. This is
   what the "Install" right-click menu in Windows uses, so it is the most accurate source.
2. **File names** — three passes:
   * the whole name, symbols removed (`Diagonal_Resize_1.cur` → `diagonalresize1`),
   * the same name with prefixes (`cursor`, `aero`, `ptr`) and size suffixes (`-Large`, `_48`) stripped,
   * **word by word**, right to left (`Kuro precision.ani` → `precision`), including two-word combos
     (`Diagonal 1.ani` → `diagonal1`).
   About 200 spellings are recognised, including `grab`, `xterm`, `fleur`, `sbvdoublearrow`,
   `not-allowed`, `all-scroll`, `pointing hand`, `size1..size4`, `dgn1`, `hres`, and so on.
3. **Fallback** — the first `.cur` in the folder becomes the normal arrow, so a pack is never useless.

### Smart fill

Most community packs simply do not contain a *Location Select*, *Person Select* or *Handwriting*
cursor: 15 of 17 is the normal maximum. Without help, Windows would keep its own cursor for those
three jobs and your theme would look half-applied.

With **Fill missing cursors from the same pack** switched on (default), the app borrows from the
pack itself: *Location* and *Person* take the pack's link hand, *Handwriting* takes the precision
cursor, *Busy* and *Working* substitute for each other, and everything else falls back to the pack's
own arrow. The card then shows for example **15/17 detected · +2 filled**, and the whole theme is
consistent. Turn the switch off if you prefer the Windows originals for the missing jobs.

### Incomplete folders

Some themes ship extra sub-folders such as `hand old version` that hold one or two cursors. They get
an **INCOMPLETE** badge, they are skipped by the rotation automatically, and **Turn OFF incomplete**
in the My Packs toolbar switches them off for good.

---

## 14. Privacy and safety

* Everything is plain PowerShell and HTML that you can read — nothing is compiled or obfuscated.
* The web server binds to `127.0.0.1` only, so it is not reachable from your network.
* Cursor settings are written to `HKCU\Control Panel\Cursors` — current user only, no admin rights,
  and no other part of the registry is touched.
* Network access happens only when *you* ask for it: downloading a store pack or fetching 7-Zip.
  Store downloads come straight from official GitHub release URLs.
* Your original cursor scheme is backed up before the first change and can be restored at any time.
