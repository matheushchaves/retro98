#!/usr/bin/env bash
# Puts back every setting Retro98 changed. Its files are removed only after a full restore.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/scripts/common.sh"
source "$RETRO98_ROOT/scripts/signing.sh"

stop_shell

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

# Remove only Retro98's own files, never whole folders blindly.
remove_signing_identity
rm -rf "$SHELL_APP"
remove_explorer
rm -f "$APPS_DIR/.DS_Store"
rmdir "$APPS_DIR" 2>/dev/null || true
rm -f "$SUPPORT_DIR/backup.plist" "$INSTALLED_BIN" "$SUPPORT_DIR"/wallpaper-*.png "$SUPPORT_DIR/.DS_Store" \
    "$PIECES_FILE" "$SUPPORT_DIR/shell-launches.plist"
rmdir "$SUPPORT_DIR/bin" 2>/dev/null || true
rmdir "$SUPPORT_DIR" 2>/dev/null || true
say "Pronto: seu Mac voltou ao normal e o Retro98 foi removido." "Done: your Mac is back to normal and Retro98 was removed."
say "Se quiser, remova o Retro98 Shell da lista em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade (e o Retro98 Explorer de Acesso Total ao Disco)." \
    "If you like, remove Retro98 Shell from System Settings › Privacy & Security › Accessibility (and Retro98 Explorer from Full Disk Access)."
