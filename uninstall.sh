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
permissions_forgotten=1
forget_permissions || permissions_forgotten=0
remove_signing_identity
if [[ -d "$SHELL_APP" ]]; then
    "$LSREGISTER" -u "$SHELL_APP" > /dev/null 2>&1 || true
    rm -rf "$SHELL_APP"
fi
remove_explorer
remove_prompt
remove_notepad
remove_browser
themes_removed=1
remove_themes || themes_removed=0
remove_control_panel
rm -f "$SOUNDS_DIR/Retro98.aiff"
rm -f "$APPS_DIR/.DS_Store"
rmdir "$APPS_DIR" 2>/dev/null || true
rm -f "$SUPPORT_DIR/backup.plist" "$INSTALLED_BIN" "$SUPPORT_DIR"/wallpaper-* "$SUPPORT_DIR/.DS_Store" \
    "$PIECES_FILE" "$SUPPORT_DIR/shell-launches.plist" "$SUPPORT_DIR/choices.plist"
rmdir "$SUPPORT_DIR/bin" 2>/dev/null || true
rmdir "$SUPPORT_DIR" 2>/dev/null || true
say "Pronto: seu Mac voltou ao normal e o Retro98 foi removido." "Done: your Mac is back to normal and Retro98 was removed."
if [[ $permissions_forgotten -eq 1 ]]; then
    say "As permissões do Retro98 em Privacidade e Segurança também foram apagadas." \
        "Retro98's permissions in Privacy & Security were cleared too."
else
    say "Não consegui apagar todas as permissões do Retro98: remova os apps do Retro98 das listas em Ajustes do Sistema › Privacidade e Segurança (Acessibilidade, Acesso Total ao Disco e Automação)." \
        "Couldn't clear all of Retro98's permissions: remove the Retro98 apps from the lists in System Settings › Privacy & Security (Accessibility, Full Disk Access and Automation)."
fi
say_browser_data_kept
if [[ $themes_removed -eq 1 ]]; then
    say "Temas removidos. No Chrome, remova o Retro98 em chrome://extensions. No Terminal, apague o perfil Retro98 Prompt em Ajustes › Perfis. No Sublime Text, escolha outro tema se o Retro98 estava em uso." \
        "Themes removed. In Chrome, remove Retro98 in chrome://extensions. In Terminal, delete the Retro98 Prompt profile in Settings › Profiles. In Sublime Text, pick another theme if Retro98 was in use."
fi
