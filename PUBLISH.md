# How to publish this on GitHub

Your repository: **<https://github.com/j66320238-crypto/Coursor-Rotator>**

Pick **one** of the two ways below. Way A needs no software at all.

---

## A. Upload through the website (easiest, no Git needed)

1. Open <https://github.com/j66320238-crypto/Coursor-Rotator> in your browser and sign in.
2. If the repository is completely empty you will see a page with the line
   **"uploading an existing file"** — click that link.
   If it already has files, click **Add file → Upload files**.
3. Open the `cursor-rotator` folder on your PC, select **everything inside it**
   (Ctrl+A) and drag it into the browser window.
   * Include the `docs` and `tools` folders — dragging folders works in Chrome and Edge.
   * The hidden `.github` folder cannot be dragged from Explorer; see step 6.
   * Do **not** upload the `Packs`, `Data` or `release` folders if they have your own
     downloads in them — they are only placeholders.
4. In **Commit changes** write: `Cursor Rotator 1.0.0` and press **Commit changes**.
5. Wait for the upload to finish. Your README will now show on the repository front page.
6. *(optional)* To add the GitHub Actions check and the issue templates:
   **Add file → Create new file**, type `.github/workflows/lint.yml` as the name
   (typing the slashes creates the folders), paste the contents of that file from your
   PC, and commit. Repeat for `.github/ISSUE_TEMPLATE/bug_report.md` and
   `.github/ISSUE_TEMPLATE/pack_request.md`.

---

## B. With Git (recommended, one command per update)

Install Git for Windows once: <https://git-scm.com/download/win>, then open
**PowerShell** inside the `cursor-rotator` folder and run:

```powershell
git init
git branch -M main
git add .
git commit -m "Cursor Rotator 1.0.0"
git remote add origin https://github.com/j66320238-crypto/Coursor-Rotator.git
git push -u origin main
```

Git will ask you to sign in — use the browser sign-in window that pops up
(or a personal access token as the password).

The folder already contains a `.gitignore`, so your downloaded cursor packs,
`Data\log.txt`, `MANIFEST.txt` and any `release\` zips stay out of the repository
automatically.

### Later updates

```powershell
git add .
git commit -m "what you changed"
git push
```

---

## Make a release (so people can download one ZIP)

1. On your PC, build a clean package:

   ```powershell
   .\tools\Build-Release.ps1 -Version 1.0.0
   ```

   This regenerates `MANIFEST.txt` and creates `release\CursorRotator-1.0.0.zip`.

2. On GitHub: **Releases → Create a new release**.
3. **Choose a tag** → type `v1.0.0` → *Create new tag on publish*.
4. Title: `Cursor Rotator 1.0.0`.
5. Description — you can paste this:

   ```text
   First public release.

   - Random cursor rotation, 5 seconds to 24 hours
   - Local web control panel with animated .ani previews
   - Built-in store: 56 free cursor packs from GitHub, browsable by category
   - Upload your own zips/folders, build custom packs, rename and delete packs
   - No installer, no admin rights, no telemetry

   Windows note: right-click the downloaded ZIP -> Properties -> tick "Unblock"
   before extracting, or run "Unblock Files (fix Windows warning).bat" once.
   ```

6. Drag `release\CursorRotator-1.0.0.zip` into the **Attach binaries** box.
7. **Publish release.**

---

## Repository settings worth 30 seconds

* **About** (top right of the repo page) → add a description and topics:
  `windows` `cursor` `powershell` `cursor-theme` `mouse-cursor` `rotator` `animated-cursors`
* Tick **Releases** in the About box so the release shows on the front page.
* **Settings → General → Features:** keep **Issues** on so people can report bugs.

---

## What each file in the repository is for

| Path | Purpose |
|---|---|
| `README.md` | The front page people see |
| `LICENSE` | MIT licence, © 2026 j66320238-crypto |
| `THIRD-PARTY.md` | Credits and licences of the cursor packs the store links to |
| `CHANGELOG.md` | Version history |
| `CONTRIBUTING.md` | How others can help / add packs |
| `docs/` | Full user guide, command reference, images |
| `tools/` | `Embed-Ui.ps1` (after editing `ui.html`), `Build-Release.ps1` |
| `.github/` | CI check + issue templates |
| everything else | The app itself |

---

## If you ever edit the UI

`ui.html` is a copy of the interface that is embedded inside `CursorRotator.ps1`.
After editing it, run:

```powershell
.\tools\Embed-Ui.ps1
```

otherwise the app keeps showing the old interface (and the GitHub check will fail).
