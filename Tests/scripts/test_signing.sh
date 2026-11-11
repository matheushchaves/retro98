#!/usr/bin/env bash
# Local signing identity: a stable designated requirement across builds, a private password file,
# and the user's keychain search list left exactly as it was. Runs on temporary paths only.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
export RETRO98_SUPPORT_DIR="$WORK/support"
export RETRO98_SIGNING_KEYCHAIN="$WORK/retro98-signing-test.keychain-db"
unset RETRO98_SIGNING
BEFORE="$(security list-keychains -d user)"

source "$ROOT/scripts/common.sh"
source "$ROOT/scripts/signing.sh"

cleanup() {
    remove_signing_identity > /dev/null 2>&1
    rm -rf "$WORK"
}
trap cleanup EXIT

failures=0
check() {
    if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}

make_app() {
    rm -rf "$1"
    mkdir -p "$1/Contents/MacOS"
    cp /usr/bin/true "$1/Contents/MacOS/Probe"
    codesign --remove-signature "$1/Contents/MacOS/Probe" 2> /dev/null
    cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Probe</string>
<key>CFBundleIdentifier</key><string>io.github.matheushchaves.retro98.probe</string>
</dict></plist>
PLIST
}

requirement() { codesign -dr - "$1" 2>&1 | grep "designated"; }

APP="$WORK/Probe.app"
make_app "$APP"
sign_app "$APP" io.github.matheushchaves.retro98.probe > /dev/null 2>&1
first="$(requirement "$APP")"
check "designated-uses-certificate" '[[ "$first" == *"certificate leaf = H\""* ]]'

make_app "$APP"
sign_app "$APP" io.github.matheushchaves.retro98.probe > /dev/null 2>&1
second="$(requirement "$APP")"
check "requirement-stable-across-builds" '[[ -n "$first" && "$first" == "$second" ]]'
check "search-list-untouched" '[[ "$(security list-keychains -d user)" == "$BEFORE" ]]'
check "password-file-private" '[[ "$(stat -f %Lp "$RETRO98_SUPPORT_DIR/signing-password" 2> /dev/null)" == "600" ]]'

remove_signing_identity > /dev/null 2>&1
check "remove-cleans-up" '[[ ! -e "$RETRO98_SIGNING_KEYCHAIN" && ! -e "$RETRO98_SUPPORT_DIR/signing-password" && "$(security list-keychains -d user)" == "$BEFORE" ]]'

make_app "$APP"
RETRO98_SIGNING=adhoc sign_app "$APP" io.github.matheushchaves.retro98.probe > /dev/null 2>&1
adhoc="$(requirement "$APP")"
check "adhoc-override" '[[ -n "$adhoc" && "$adhoc" != *"certificate leaf"* ]]'
check "adhoc-creates-no-keychain" '[[ ! -e "$RETRO98_SIGNING_KEYCHAIN" ]]'

exit $((failures > 0 ? 1 : 0))
