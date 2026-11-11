#!/usr/bin/env bash
# Builds Retro98 Shell and assembles it as an app bundle: scripts/build-shell-app.sh "<output>.app"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
OUT="${1:?usage: build-shell-app.sh <output.app>}"
exec "$ROOT/scripts/build-app.sh" Retro98Shell "$SHELL_LABEL" "Retro98 Shell" "$OUT" agent "" shell \
    "Retro98 Shell uses System Events to shut down, restart, log out or sleep when you choose it in Shut Down…"
