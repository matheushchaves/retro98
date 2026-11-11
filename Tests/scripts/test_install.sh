#!/usr/bin/env bash
# install.sh --yes with stubs: writes a valid LaunchAgent, builds the app bundle, loads it via launchctl,
# and never touches the real LaunchAgents, Applications or preferences.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/fake-bin"
printf '#!/usr/bin/env bash\necho "$*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/fake-bin/launchctl"
printf '#!/usr/bin/env bash\necho "settings $*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/stub-settings"
chmod +x "$WORK/fake-bin/launchctl" "$WORK/stub-settings"

export WORK_LOG="$WORK/calls.log"
export PATH="$WORK/fake-bin:$PATH"
export RETRO98_SETTINGS_BIN="$WORK/stub-settings"
export RETRO98_SUPPORT_DIR="$WORK/support"
export RETRO98_APPS_DIR="$WORK/apps"
export RETRO98_LAUNCH_AGENTS_DIR="$WORK/agents"
LABEL="io.github.matheushchaves.retro98.shell"

failures=0
check() {
    if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}

bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out.log" 2>&1
check "exit-zero" '[[ $? -eq 0 ]]'
check "base-applied" 'grep -qx "settings apply" "$WORK_LOG"'
check "dock-applied" 'grep -qx "settings apply --only dockUnderTaskbar" "$WORK_LOG"'
check "agent-valid" 'plutil -lint "$WORK/agents/$LABEL.plist" > /dev/null'
check "agent-points-to-app" 'grep -q "$WORK/apps/Retro98 Shell.app/Contents/MacOS/Retro98Shell" "$WORK/agents/$LABEL.plist"'
check "app-signed" 'codesign --verify "$WORK/apps/Retro98 Shell.app" 2> /dev/null'
check "app-is-agent" '[[ "$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$WORK/apps/Retro98 Shell.app/Contents/Info.plist")" == "true" ]]'
check "bootstrapped" 'grep -q "bootstrap gui/$(id -u) $WORK/agents/$LABEL.plist" "$WORK_LOG"'
check "pieces-recorded" '[[ "$(cat "$WORK/support/pieces")" == "base shell" ]]'

# Re-install with only the base tweaks: the taskbar must be turned off and the Dock restored.
echo "base" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out2.log" 2>&1
check "shell-removed-when-not-chosen" '[[ ! -e "$WORK/agents/$LABEL.plist" && ! -e "$WORK/apps/Retro98 Shell.app" ]]'
check "dock-restored" 'grep -qx "settings restore --only dockUnderTaskbar" "$WORK_LOG"'

exit $((failures > 0 ? 1 : 0))
