# North Drive Downloader 1.0.0 — Reliable Transfer Release

A native Apple Silicon + Intel macOS Google Drive folder downloader built with Rust/Tauri.

## Version 1.0 improvements

- Detect interrupted / short downloads, validate Content-Range and safely resume partially downloaded large files.
- Retry transient connection failures, 429 rate limits, 5xx responses, and stalled transfers with backoff.
- Refresh expired Google OAuth access tokens, and retry MD5 mismatches once from a clean file.
- Restore the Retry failed / Resume controls; show actual transfer error messages in the UI.
- Safely skip completed Google Workspace exports using SHA-256 receipts stored in a hidden .north-drive-state directory.
- Retry transient folder scans and identify Google Workspace modifications with modifiedTime.
- Maintain compatible .northpart metadata for resumable files downloaded in v0.1.2.
- Run cargo test and node --check in CI before packaging.

## Download and recovery

Open GitHub Actions → Build macOS Universal DMG → latest successful main run → download artifact.
Unzip the GitHub artifact and install North Drive Downloader.app from the DMG.
If a file failed, keep the existing .northpart files; re-analyze the same folder, use the same destination and click Retry failed / Resume.
Workspace exports do not support byte-range resume and start over if interrupted. For restricted links connect your authorized Google account.
For large files on unstable networks start with 2 parallel downloads.

## Validation / limits

CI covers Rust unit tests, JavaScript syntax, the macOS app build, and DMG contents.
Real Google Drive API transfer testing against the failing folder and macOS version remains necessary before claiming fully production-proven stability.
Google Drive owner permissions, account quotas, 403 download restrictions, lack of disk space, and interrupted internet cannot be bypassed by the client.
The DMG is ad-hoc signed, not Apple notarized; do not disable Gatekeeper globally.

---

This is the **source project** for the dark/pink macOS Google Drive downloader. It is not a precompiled or validated installer. The included build pipeline targets a real **universal macOS `.dmg`** that opens with a `North Drive Downloader.app` icon and `Applications` folder shortcut.

## Get the DMG using a hosted Mac (no local compilation needed)

1. Create a GitHub repository, upload/commit the files in this project **including `.github/workflows/build-macos-dmg.yml`**. To retain this hidden folder, use Git, not a web upload that omits hidden directories.
2. Open your repository's **Actions** tab → **Build macOS Universal DMG** → **Run workflow**.
3. Once the workflow finishes successfully, download the **NorthDriveDownloader-macOS-Universal-DMG** artifact. Unzip that GitHub artifact to obtain `NorthDriveDownloader-1.0.0-universal-adhoc.dmg`.
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
