#!/usr/bin/env bash
# Builds one Retro98 app product and assembles it as a signed app bundle:
#   scripts/build-app.sh <product> <bundle id> <name> <output.app> <agent|regular> [url scheme] [icon] [Apple Events usage text]
# "agent" apps (LSUIElement) have no Dock icon or menu bar; the icon name goes to `retro98-tools iconset`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
source "$ROOT/scripts/signing.sh"

usage="usage: build-app.sh <product> <bundle id> <name> <output.app> <agent|regular> [url scheme] [icon] [apple events usage]"
PRODUCT="${1:?$usage}"
BUNDLE_ID="${2:?$usage}"
NAME="${3:?$usage}"
OUT="${4:?$usage}"
MODE="${5:?$usage}"
SCHEME="${6:-}"
ICON="${7:-}"
APPLE_EVENTS_USAGE="${8:-}"
VERSION="0.6.0"
BUILD="6"

# The target is deleted before rebuilding: refuse anything that isn't an .app bundle path.
if [[ "$OUT" != *.app ]]; then
    echo "build-app.sh: refusing '$OUT' (must end in .app)" >&2
    exit 1
fi
if [[ "$MODE" != agent && "$MODE" != regular ]]; then
    echo "build-app.sh: mode must be 'agent' or 'regular', not '$MODE'" >&2
    exit 1
fi

(cd "$ROOT" && swift build -c release --product "$PRODUCT")
[[ -z "$ICON" ]] || (cd "$ROOT" && swift build -c release --product retro98-tools)

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$ROOT/.build/release/$PRODUCT" "$OUT/Contents/MacOS/$PRODUCT"

extra=""
if [[ "$MODE" == agent ]]; then
    extra+="    <key>LSUIElement</key><true/>"$'\n'
fi
if [[ -n "$SCHEME" ]]; then
    extra+="    <key>CFBundleURLTypes</key><array><dict>
        <key>CFBundleURLName</key><string>$BUNDLE_ID</string>
        <key>CFBundleURLSchemes</key><array><string>$SCHEME</string></array>
    </dict></array>"$'\n'
fi
if [[ -n "$ICON" ]]; then
    iconset="$(mktemp -d)/AppIcon.iconset"
    "$ROOT/.build/release/retro98-tools" iconset "$ICON" "$iconset"
    iconutil -c icns "$iconset" -o "$OUT/Contents/Resources/AppIcon.icns"
    rm -rf "$(dirname "$iconset")"
    extra+="    <key>CFBundleIconFile</key><string>AppIcon</string>"$'\n'
fi
if [[ -n "$APPLE_EVENTS_USAGE" ]]; then
    extra+="    <key>NSAppleEventsUsageDescription</key><string>$APPLE_EVENTS_USAGE</string>"$'\n'
fi

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$NAME</string>
    <key>CFBundleDisplayName</key><string>$NAME</string>
    <key>CFBundleExecutable</key><string>$PRODUCT</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
$extra</dict>
</plist>
PLIST
plutil -lint "$OUT/Contents/Info.plist" > /dev/null
sign_app "$OUT" "$BUNDLE_ID"
