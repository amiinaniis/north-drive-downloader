# North Drive Downloader 0.1.2 — DMG Builder Edition

This is the **source project** for the dark/pink macOS Google Drive downloader. It is not a precompiled or validated installer. The included build pipeline targets a real **universal macOS `.dmg`** that opens with a `North Drive Downloader.app` icon and `Applications` folder shortcut.

## Get the DMG using a hosted Mac (no local compilation needed)

1. Create a GitHub repository, upload/commit the files in this project **including `.github/workflows/build-macos-dmg.yml`**. To retain this hidden folder, use Git, not a web upload that omits hidden directories.
2. Open your repository's **Actions** tab → **Build macOS Universal DMG** → **Run workflow**.
3. Once the workflow finishes successfully, download the **NorthDriveDownloader-macOS-Universal-DMG** artifact. Unzip that GitHub artifact to obtain `NorthDriveDownloader-0.1.2-universal-adhoc.dmg`.
4. Open the DMG, drag **North Drive Downloader.app** onto **Applications**, then eject the DMG.

The workflow runs on GitHub's macOS runner and **has not been run or verified yet**. If the application fails to compile, the workflow will fail rather than upload a fake installer.

## Build locally on your Mac

Install Node.js 22+, stable Rust with `rustup`, and Xcode Command Line Tools. Then open Terminal in this folder and run:

```sh
zsh scripts/build-dmg.command
```

This builds an Apple Silicon + Intel universal app and uses Tauri to create the drag-and-drop disk image. The output is under `dist/`. The `scripts/build-mac.command` shortcut runs the same builder. This is a normal `.dmg`, **not a `.pkg` installer**.

## Status and setup

- The dark-pink UI and HTML browser preview are included at `NorthDrive_UI_Preview.html`. The preview is simulated, not a working downloader.
- The Rust backend includes source implementations of Drive folder enumeration, public API key access, private OAuth read-only access, streaming downloads, range-based partial-file resume, and checksum verification.
- **This backend has not been compiled/tested on macOS or verified against Google Drive in this session.** Treat as developer-preview code, not a reliable production release.
- Live use requires a Google Cloud project with **Google Drive API enabled**, an API key for public folders, and a Desktop OAuth Client ID for restricted folders, configured in Settings. Sign in with a Google account authorized to access the link.
- The GitHub DMG is **ad-hoc signed** and **not notarized**, so macOS Gatekeeper may block the first launch. A normal public release needs Apple Developer ID signing and notarization. Never disable system security globally to open an unknown app.
- Universal binary support depends on successful builds for both `aarch64-apple-darwin` and `x86_64-apple-darwin` targets.

## Installed app folder

The disk image must contain:

```
North Drive Downloader.app   → compiled native app
Applications                 → link to your /Applications folder
```

The script verifies these entries and refuses to ship the image if they're missing.

## Limitations

Only one connected Google account, no persistent queue history, and downloads start after scanning finishes. Google Drive API quota/permissions, storage, and network limits still apply. Testing against non-sensitive Google Drive folders is recommended before using important client files.
