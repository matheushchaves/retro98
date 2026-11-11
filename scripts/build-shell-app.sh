#!/usr/bin/env bash
# Builds Retro98 Shell and assembles it as an app bundle: scripts/build-shell-app.sh "<output>.app"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?usage: build-shell-app.sh <output.app>}"
# The target is deleted before rebuilding: refuse anything that isn't an .app bundle path.
if [[ "$OUT" != *.app ]]; then
    echo "build-shell-app.sh: refusing '$OUT' (must end in .app)" >&2
    exit 1
fi

(cd "$ROOT" && swift build -c release --product Retro98Shell)

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
cp "$ROOT/.build/release/Retro98Shell" "$OUT/Contents/MacOS/Retro98Shell"
cat > "$OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.matheushchaves.retro98.shell</string>
    <key>CFBundleName</key><string>Retro98 Shell</string>
    <key>CFBundleDisplayName</key><string>Retro98 Shell</string>
    <key>CFBundleExecutable</key><string>Retro98Shell</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Retro98 Shell uses System Events to shut down, restart, log out or sleep when you choose it in Shut Down…</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$OUT"
