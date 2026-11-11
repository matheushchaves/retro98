# Shared helpers for install.sh and uninstall.sh. Source, don't run.

RETRO98_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_DIR="${RETRO98_SUPPORT_DIR:-$HOME/Library/Application Support/Retro98}"
INSTALLED_BIN="$SUPPORT_DIR/bin/retro98-settings"

# First preferred macOS language, e.g. "pt-BR".
RETRO98_LANG="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p' | tr -d ' ",')"

# say "texto em português" "English text"
say() {
    if [[ "$RETRO98_LANG" == pt* ]]; then
        echo "$1"
    else
        echo "$2"
    fi
}
