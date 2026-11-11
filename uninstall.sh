#!/usr/bin/env bash
# Puts back every setting Retro98 changed. Its files are removed only after a full restore.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/scripts/common.sh"

if [[ -n "${RETRO98_SETTINGS_BIN:-}" ]]; then
    BIN="$RETRO98_SETTINGS_BIN"
elif [[ -x "$INSTALLED_BIN" ]]; then
    BIN="$INSTALLED_BIN"
else
    say "Compilando a ferramenta de restauração..." "Building the restore tool..."
    (cd "$RETRO98_ROOT" && swift build -c release --product retro98-settings)
    BIN="$RETRO98_ROOT/.build/release/retro98-settings"
fi

set +e
"$BIN" restore
status=$?
set -e

if [[ $status -ne 0 ]]; then
    say "Backup mantido em $SUPPORT_DIR. Corrija o que foi indicado acima e rode ./uninstall.sh de novo." \
        "Backup kept in $SUPPORT_DIR. Fix what is shown above and run ./uninstall.sh again."
    exit $status
fi

# Remove only Retro98's own files, never the whole folder blindly.
rm -f "$SUPPORT_DIR/backup.plist" "$INSTALLED_BIN" "$SUPPORT_DIR"/wallpaper-*.png
rmdir "$SUPPORT_DIR/bin" 2>/dev/null || true
rmdir "$SUPPORT_DIR" 2>/dev/null || true
say "Pronto: seu Mac voltou ao normal e o Retro98 foi removido." "Done: your Mac is back to normal and Retro98 was removed."
