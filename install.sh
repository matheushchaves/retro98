#!/usr/bin/env bash
# Builds Retro98 on this Mac and applies the Phase 1 base tweaks (with a backup of every original).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/scripts/common.sh"

MINIMUM_MACOS=14
ASSUME_YES=false

usage() {
    say "Uso: ./install.sh [--yes]" "Usage: ./install.sh [--yes]"
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=true ;;
        --help|-h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( macos_major < MINIMUM_MACOS )); then
    say "O Retro98 precisa do macOS $MINIMUM_MACOS ou mais novo." "Retro98 needs macOS $MINIMUM_MACOS or newer."
    exit 1
fi

if ! xcode-select -p > /dev/null 2>&1; then
    say "Instale as Ferramentas de Linha de Comando do Xcode e rode de novo: xcode-select --install" \
        "Install the Xcode Command Line Tools and run again: xcode-select --install"
    exit 1
fi

if [[ -n "${RETRO98_SETTINGS_BIN:-}" ]]; then
    BIN="$RETRO98_SETTINGS_BIN"
else
    say "Compilando o Retro98..." "Building Retro98..."
    (cd "$RETRO98_ROOT" && swift build -c release --product retro98-settings)
    mkdir -p "$SUPPORT_DIR/bin"
    cp "$RETRO98_ROOT/.build/release/retro98-settings" "$INSTALLED_BIN"
    BIN="$INSTALLED_BIN"
fi

if ! $ASSUME_YES; then
    if [[ ! -t 0 ]]; then
        say "Sem terminal interativo: rode ./install.sh --yes para aplicar." \
            "No interactive terminal: run ./install.sh --yes to apply."
        exit 1
    fi
    read -r -p "$(say 'Aplicar os ajustes base agora? [S/n] ' 'Apply the base tweaks now? [Y/n] ')" answer
    if [[ "${answer:-}" == [nN]* ]]; then
        say "Nada foi alterado." "Nothing was changed."
        exit 0
    fi
fi

set +e
"$BIN" apply
status=$?
set -e

say "Para ver o estado: \"$BIN\" status · Para desfazer tudo: ./uninstall.sh" \
    "To check: \"$BIN\" status · To undo everything: ./uninstall.sh"
exit $status
