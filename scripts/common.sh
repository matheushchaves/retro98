# Shared helpers for install.sh and uninstall.sh. Source, don't run.

RETRO98_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_DIR="${RETRO98_SUPPORT_DIR:-$HOME/Library/Application Support/Retro98}"
INSTALLED_BIN="$SUPPORT_DIR/bin/retro98-settings"

# First preferred macOS language, e.g. "pt-BR". A failed lookup must never abort the
# calling script (set -e + pipefail), so it falls back to English.
RETRO98_LANG="$( { defaults read -g AppleLanguages 2>/dev/null || true; } | sed -n '2p' | tr -d ' ",')"

# say "texto em português" "English text"
say() {
    if [[ "$RETRO98_LANG" == pt* ]]; then
        echo "$1"
    else
        echo "$2"
    fi
}

# Retro98 Shell (taskbar) locations; overridable so tests never touch the real ones.
APPS_DIR="${RETRO98_APPS_DIR:-$HOME/Applications/Retro98}"
LAUNCH_AGENTS_DIR="${RETRO98_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
SHELL_LABEL="io.github.matheushchaves.retro98.shell"
SHELL_APP="$APPS_DIR/Retro98 Shell.app"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENTS_DIR/$SHELL_LABEL.plist"
PIECES_FILE="$SUPPORT_DIR/pieces"

# Retro98 Explorer travels with the taskbar (its quick launch button opens it).
EXPLORER_ID="io.github.matheushchaves.retro98.explorer"
EXPLORER_APP="$APPS_DIR/Retro98 Explorer.app"
EXPLORER_SCHEME="retro98-explorer"
LSREGISTER="${RETRO98_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"

# Unregisters and deletes the Explorer bundle (no-op when it isn't installed).
remove_explorer() {
    if [[ -d "$EXPLORER_APP" ]]; then
        "$LSREGISTER" -u "$EXPLORER_APP" > /dev/null 2>&1 || true
        rm -rf "$EXPLORER_APP"
    fi
}

# Stops the Shell (if running) and removes its LaunchAgent so launchd won't start it again.
stop_shell() {
    launchctl bootout "gui/$(id -u)/$SHELL_LABEL" > /dev/null 2>&1 || true
    rm -f "$LAUNCH_AGENT_PLIST"
}
