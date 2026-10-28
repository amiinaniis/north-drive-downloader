#!/bin/zsh
# Build an actual macOS drag-and-drop .dmg containing a compiled universal .app.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "ERROR: This script must run on macOS; it cannot build a working Mac app on Linux."
  exit 1
fi
for command in npm cargo rustup xcode-select hdiutil; do
  if ! command -v "$command" >/dev/null 2>&1; then
    print -u2 "ERROR: Missing $command. Install Node.js, Rust, and Xcode Command Line Tools."
    exit 1
  fi
done
if ! xcode-select -p >/dev/null 2>&1; then
  print -u2 "ERROR: Xcode Command Line Tools missing. Run: xcode-select --install"
  exit 1
fi

VERSION="$(node -p "require('./package.json').version")"
OUTPUT="$(pwd)/dist/NorthDriveDownloader-${VERSION}-universal-adhoc.dmg"
BUNDLE_DIR="src-tauri/target/universal-apple-darwin/release/bundle/dmg"
print "Building North Drive Downloader $VERSION — macOS Universal (Apple Silicon + Intel)..."

rustup target add aarch64-apple-darwin x86_64-apple-darwin
npm install --no-audit --no-fund
# Ad-hoc signing is not Apple Developer ID signing or notarization.
export APPLE_SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:--}"
npm run build -- --bundles dmg --target universal-apple-darwin --ci

DMG_FILE="$(find "$BUNDLE_DIR" -maxdepth 1 -type f -name '*.dmg' -print -quit 2>/dev/null || true)"
if [[ -z "$DMG_FILE" || ! -s "$DMG_FILE" ]]; then
  print -u2 "ERROR: Tauri did not produce a DMG. See build log above."
  exit 1
fi
mkdir -p dist
cp -f "$DMG_FILE" "$OUTPUT"
hdiutil imageinfo "$OUTPUT" >/dev/null

# Verify that the installer contains both the real app bundle and the Applications shortcut.
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp/}north-dmg.XXXXXX")"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" -eq 1 ]]; then hdiutil detach -quiet "$MOUNT_DIR" || true; fi
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$OUTPUT"
MOUNTED=1
if [[ ! -d "$MOUNT_DIR/North Drive Downloader.app" || ! -e "$MOUNT_DIR/Applications" ]]; then
  print -u2 "ERROR: DMG missing the compiled app or Applications shortcut."
  exit 1
fi
print "SUCCESS: $OUTPUT"
print "Open the DMG, then drag North Drive Downloader into Applications."
if [[ -z "${CI:-}" ]]; then open dist; fi
