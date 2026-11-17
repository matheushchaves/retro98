#!/usr/bin/env bash
# Draws the README's images into docs/images/<language>/, off screen: nothing is opened or captured.
# Each app's test target draws its real window with made-up content (never your files); the desktop picture
# is then composed from those windows. The screen savers, with no words to translate, go once into
# docs/images/screensavers/. Usage: scripts/make-screenshots.sh [output folder]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/images}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

cd "$ROOT"
RETRO98_SCREENSHOTS="$OUT" swift test --filter 'screenshot(Browser|Notepad|Explorer|ControlPanel|Screensaver)'
RETRO98_SCREENSHOTS="$OUT" swift test --filter screenshotHero
# The background-window variants only exist to compose the desktop picture.
rm -rf "$OUT"/*/parts
echo "Images written to $OUT"
