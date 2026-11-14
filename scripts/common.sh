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

# Quits, unregisters and deletes the Explorer bundle (no-op when it isn't installed).
remove_explorer() {
    if [[ -d "$EXPLORER_APP" ]]; then
        stop_executable "$EXPLORER_APP/Contents/MacOS/Retro98Explorer"
        "$LSREGISTER" -u "$EXPLORER_APP" > /dev/null 2>&1 || true
        rm -rf "$EXPLORER_APP"
    fi
}

# Retro98 Prompt, the retro terminal: a piece of its own, independent of the taskbar.
PROMPT_ID="io.github.matheushchaves.retro98.prompt"
PROMPT_APP="$APPS_DIR/Retro98 Prompt.app"

# Quits, unregisters and deletes the Prompt bundle (no-op when it isn't installed).
remove_prompt() {
    if [[ -d "$PROMPT_APP" ]]; then
        stop_executable "$PROMPT_APP/Contents/MacOS/Retro98Prompt"
        "$LSREGISTER" -u "$PROMPT_APP" > /dev/null 2>&1 || true
        rm -rf "$PROMPT_APP"
    fi
}

# Retro98 Notepad, the plain-text editor: a piece of its own too.
NOTEPAD_ID="io.github.matheushchaves.retro98.notepad"
NOTEPAD_APP="$APPS_DIR/Retro98 Notepad.app"

# Quits, unregisters and deletes the Notepad bundle (no-op when it isn't installed).
remove_notepad() {
    if [[ -d "$NOTEPAD_APP" ]]; then
        stop_executable "$NOTEPAD_APP/Contents/MacOS/Retro98Notepad"
        "$LSREGISTER" -u "$NOTEPAD_APP" > /dev/null 2>&1 || true
        rm -rf "$NOTEPAD_APP"
    fi
}

# Retro98 Control Panel: always installed, since it is where pieces are turned on and off.
CONTROL_PANEL_ID="io.github.matheushchaves.retro98.controlpanel"
CONTROL_PANEL_APP="$APPS_DIR/Retro98 Control Panel.app"
# The alert sound the Control Panel can put in ~/Library/Sounds; overridable so tests never touch the real one.
SOUNDS_DIR="${RETRO98_SOUNDS_DIR:-$HOME/Library/Sounds}"

# Quits, unregisters and deletes the Control Panel bundle (no-op when it isn't installed).
remove_control_panel() {
    if [[ -d "$CONTROL_PANEL_APP" ]]; then
        stop_executable "$CONTROL_PANEL_APP/Contents/MacOS/Retro98ControlPanel"
        "$LSREGISTER" -u "$CONTROL_PANEL_APP" > /dev/null 2>&1 || true
        rm -rf "$CONTROL_PANEL_APP"
    fi
}

# Stops every process running the executable at $1, however it was started: politely first,
# then for good after 5 seconds. Matches the full path, so other apps are never touched.
stop_executable() {
    local executable="$1" pids="" pid args alive attempt
    while read -r pid args; do
        [[ "$args" == "$executable" || "$args" == "$executable "* ]] && pids+=" $pid"
    done < <(ps -axo pid=,args=)
    [[ -n "$pids" ]] || return 0
    kill -TERM $pids 2> /dev/null || true
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        alive=""
        for pid in $pids; do kill -0 "$pid" 2> /dev/null && alive+=" $pid"; done
        [[ -n "$alive" ]] || return 0
        pids="$alive"
        sleep 0.5
    done
    kill -KILL $pids 2> /dev/null || true
}

# Stops the Shell: the LaunchAgent's copy and any copy opened outside launchd (System Settings'
# "Quit & Reopen" after a permission change, Finder, the Start menu), which bootout can't reach.
stop_shell_processes() {
    launchctl bootout "gui/$(id -u)/$SHELL_LABEL" > /dev/null 2>&1 || true
    stop_executable "$SHELL_APP/Contents/MacOS/Retro98Shell"
}

# Stops the Shell and removes its LaunchAgent so launchd won't start it again.
stop_shell() {
    stop_shell_processes
    rm -f "$LAUNCH_AGENT_PLIST"
}

# Overridable so tests never touch the real permissions or the Shell's real preferences.
TCCUTIL="${RETRO98_TCCUTIL:-/usr/bin/tccutil}"
DEFAULTS_TOOL="${RETRO98_DEFAULTS:-/usr/bin/defaults}"

# Makes macOS forget what it allowed Retro98's apps (Accessibility, Full Disk Access, Automation) and the
# Shell's "already asked" mark. Their permissions are tied to the signing certificate the uninstaller
# deletes, so a later install would otherwise show switches that are on but no longer work. tccutil only
# finds registered apps: run this before unregistering them. Returns 1 if a reset failed.
forget_permissions() {
    local pair id app failed=0
    for pair in "$SHELL_LABEL|$SHELL_APP" "$EXPLORER_ID|$EXPLORER_APP" "$PROMPT_ID|$PROMPT_APP" \
        "$CONTROL_PANEL_ID|$CONTROL_PANEL_APP" "$NOTEPAD_ID|$NOTEPAD_APP"; do
        id="${pair%%|*}" app="${pair#*|}"
        [[ -d "$app" ]] || continue
        "$LSREGISTER" -f "$app" > /dev/null 2>&1 || true   # launchd starts the Shell, so it may never have been registered
        "$TCCUTIL" reset All "$id" > /dev/null 2>&1 || failed=1
    done
    "$DEFAULTS_TOOL" delete "$SHELL_LABEL" > /dev/null 2>&1 || true
    return $failed
}
