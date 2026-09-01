# Changelog

All notable changes to this project are documented here.
Versions follow [semantic versioning](https://semver.org/).

## 1.1.0 - 2026-09-01

### Added

* **Now on your screen** panel: shows the pack that is really applied right now, with
  live previews, the time it was applied and the countdown to the next change.
* **Simple / Advanced modes.** Simple shows only the everyday controls; Advanced adds
  role assignment, hotkeys, the pack builder, diagnostics, the updater and the reset zone.
  The choice is remembered in the browser.
* **Built-in updater.** *Advanced -> Check for updates* asks GitHub for the newest release
  and can install it in place; your `Packs/` folder and settings are never touched.
  Also available as `Update.bat` and `CursorRotator.ps1 -Update`, plus `-Version`.
* **Duplicate detection.** Every pack folder is fingerprinted (file names, sizes and
  content hash). A pack that holds exactly the same cursors as one you already have is
  marked DUPLICATE, skipped by the rotation, and can be deleted with one click.
  Uploading the very same archive twice is refused with a clear message.
* `Start.bat` now opens the control panel in your browser by itself (with three fallbacks
  if the default browser cannot be launched).
* New "Get the 3 starter packs" button in the store and on the empty state.

### Changed

* **Nothing is downloaded unless you press a button.** The old automatic 7-Zip fetch and the
  automatic starter-pack download are gone; the 7-Zip helper only runs if you enable
  `autoGetTools`, and *Fix it for me* now just re-scans your folder.
* My Packs: duplicate banner, "Only complete packs" and "Only duplicates" filters,
  "Remove duplicates" action.

### Fixed

* **The rotation now really changes the pointer.** Writing the registry alone often needed a
  sign-out before Windows noticed. Each cursor is now also pushed into the running session
  with `LoadCursorFromFile` + `SetSystemCursor`, and `Scheme Source` is set, so the new pack
  appears instantly. The log reports how many cursors were set live.

---

## 1.0.0 - 2026-09-01

First public release. Everything below was built and tested before this tag; the
numbers in the older entries are internal development builds, kept for reference.

### Highlights

* Rotates the Windows cursor theme automatically, from every 5 seconds to once a day.
* Reads `.zip`, `.7z`, `.rar` and plain folders; unpacks each archive exactly once and
  never needs WinRAR (built-in unzip, then portable 7-Zip on demand).
* Detects which file is which of the 17 Windows cursor jobs from `install.inf` or from
  the file names, and fills anything a pack is missing from the pack's own cursors.
* Local web control panel with **real animated previews** of `.ani` cursors.
* Built-in store with **56 free packs** from public GitHub releases, browsable by category
  (RGB, Animated, Anime, Game, Minimal, Colorful, Dark, Light, macOS, Windows 11, Bundles).
* Upload archives, loose cursor files or a whole unzipped folder straight from the UI.
* Custom pack builder: mix cursors from different themes into your own named pack.
* Per-pack ON/OFF, rename, delete, manual role assignment, hotkeys, autorun, tray icon.
* One-click **Remove everything**: original cursors back, autorun gone, settings cleared,
  packs optionally deleted.
* No installer, no admin rights, no telemetry. One PowerShell script plus `.bat` shortcuts.

### Fixed in this release

* Windows "The publisher could not be verified" prompt: the app now clears the
  *downloaded from the internet* flag on its own files at startup, and
  `Unblock Files (fix Windows warning).bat` does it for the whole folder in one click.

---

## Development history

## 3.6 - 2026-09-01

### Added
- **Store grew to 56 packs**: Capitaine Cursors (16 themes in one zip), Dota 2 (24 themes + single
  hero packs), 13 more animated anime/character packs, Cyberpunk, Cinnamon, Felyne and animated
  Windows 11 Dark / Light.
- **Real animation in the browser.** `.ani` files are parsed frame by frame (RIFF/ACON: `anih`,
  `rate`, `seq `, `icon`) and previews play at the pack's own timing. New `/api/aniinfo` and
  `/file?p=...&frame=N` endpoints, plus a **Play animations** switch.
- **Upload from the UI**: drag and drop archives or cursor files, an *Upload ZIP* button, and
  *Upload an unzipped folder* for packs you already extracted (`POST /api/upload`).
- **Custom pack builder**: mix cursors from any packs into a new named pack, saved to
  `Packs\_My Custom Packs\` with role-named files (`POST /api/createpack`).
- **Rename** and **Delete** for every pack, in a ⋮ menu on the card (`/api/renamepack`, `/api/deletepack`).
- **Remove everything**: one button (and `Remove Everything (uninstall).bat`, `-RemoveAll`) that
  restores the original cursors, removes autorun, clears settings and optionally deletes all packs.
- Friendly pack titles taken from the pack's own `install.inf` (`SCHEME_NAME`).
- Diagnostics now lists **files that were ignored** (readmes, images, `uninstall.bat`, ...) so stray
  files in the Packs folder are reported instead of being a mystery - and never cause an error.

### Changed
- **One cursor location only.** The old second folder (`Cursors\`) is gone; everything lives in
  `Packs\`, including custom packs.
- Nicer pack cards: friendly title, ⋮ actions menu, animated preview badge.

## 3.5 - 2026-09-01

### Added
- **Cursor store grew from 12 to 33 packs**, all from public GitHub releases: Bibata Rainbow (RGB,
  fully animated), Bibata Extra colour bundles, Notwaita Black/Gray/White, Pokemon, Marathon,
  Modern Cursors v2 Dark/Light and six animated anime/character packs.
- **Categories and tags** for every store pack: RGB, Animated, Anime, Game, Fun, Minimal, Colorful,
  Dark, Light, macOS, Windows11, Bundle, Popular.
- **Store browser in the UI**: search box, category chips with counts, checkbox multi-select,
  "Download selected" with a live progress bar, and "Download all shown".
- **`Download-Cursors.ps1`** standalone downloader with an interactive menu, plus
  `Download Cursor Packs (menu).bat` and `Download RGB and Animated Packs.bat`.
- CLI: `-Download tags`, `-Tag <category>` filter for `-Download list` and `-DownloadAll`.
- HTTP API: `/api/downloadmany`, `/api/downloadtag`, `/api/toggleweak`.
- **Badges on pack cards**: ANIMATED, RGB, ANIME, INCOMPLETE, plus an explicit green
  "ON - in rotation" / red "OFF - never used" label.
- Pack filters: All / Only ON / Only OFF / Only animated / Only static / Only RGB.
- **Smart fill** (`fillMissing`, on by default): missing cursor jobs borrow from the pack's own
  cursors instead of falling back to Windows defaults, so a theme is never half-applied.
- `MANIFEST.txt` in every release: file list with sizes and SHA-256 hashes.

### Changed
- Auto-detection now also matches word-by-word (`Kuro precision.ani`), handles two-word names
  (`Diagonal 1.ani`) and knows ~60 more file-name spellings.
- Rotation automatically skips folders with fewer than 6 of the 17 cursor jobs.

## 3.4

- Store commands on the command line (`-Download list`, `-Download <id>`, `-DownloadAll`, `-Setup7Zip`).
- All documentation rewritten in English; added `READ ME FIRST.txt`.

## 3.3

- App now runs from `%TEMP%` so Windows never reports "folder in use" when updating or deleting it.
- Added `Update - Stop and Unlock Folder.bat`.

## 3.2

- Extraction no longer depends on WinRAR: built-in unzip, then portable 7-Zip (downloaded on demand).

## 3.1

- Each archive is unpacked exactly once, into a folder named after the archive.
- Real cursor previews in the web UI.

## 3.0

- Per-pack ON/OFF switches, intervals down to seconds, manual role assignment, CLI mode.
