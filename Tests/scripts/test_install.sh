#!/usr/bin/env bash
# install.sh --yes with stubs: writes a valid LaunchAgent, builds the app bundle, loads it via launchctl,
# and never touches the real LaunchAgents, Applications or preferences.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/fake-bin"
printf '#!/usr/bin/env bash\necho "$*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/fake-bin/launchctl"
printf '#!/usr/bin/env bash\necho "open $*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/fake-bin/open"
printf '#!/usr/bin/env bash\necho "settings $*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/stub-settings"
printf '#!/usr/bin/env bash\necho "lsregister $*" >> "$WORK_LOG"\nexit 0\n' > "$WORK/stub-lsregister"
chmod +x "$WORK/fake-bin/launchctl" "$WORK/fake-bin/open" "$WORK/stub-settings" "$WORK/stub-lsregister"

export WORK_LOG="$WORK/calls.log"
export PATH="$WORK/fake-bin:$PATH"
export RETRO98_SETTINGS_BIN="$WORK/stub-settings"
export RETRO98_SUPPORT_DIR="$WORK/support"
export RETRO98_APPS_DIR="$WORK/apps"
export RETRO98_LAUNCH_AGENTS_DIR="$WORK/agents"
# Never register anything with the real LaunchServices database.
export RETRO98_LSREGISTER="$WORK/stub-lsregister"
# Never create the real signing keychain from tests.
export RETRO98_SIGNING=adhoc
export RETRO98_SIGNING_KEYCHAIN="$WORK/never-created.keychain-db"
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
enable_line="$(grep -n "^enable gui/$(id -u)/$LABEL" "$WORK_LOG" | head -1 | cut -d: -f1)"
bootstrap_line="$(grep -n "^bootstrap " "$WORK_LOG" | head -1 | cut -d: -f1)"
check "enabled-before-bootstrap" '[[ -n "$enable_line" && -n "$bootstrap_line" && "$enable_line" -lt "$bootstrap_line" ]]'
check "pieces-recorded" '[[ "$(cat "$WORK/support/pieces")" == "base shell prompt" ]]'
check "accessibility-hint" 'grep -qE "Acessibilidade|Accessibility" "$WORK/out.log"'
EXPLORER="$WORK/apps/Retro98 Explorer.app"
check "explorer-built" 'codesign --verify "$EXPLORER" 2> /dev/null'
check "explorer-is-regular-app" '! /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$EXPLORER/Contents/Info.plist" > /dev/null 2>&1'
check "explorer-url-scheme" '[[ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$EXPLORER/Contents/Info.plist")" == "retro98-explorer" ]]'
check "explorer-has-icon" '[[ -s "$EXPLORER/Contents/Resources/AppIcon.icns" ]]'
check "explorer-registered" 'grep -qx "lsregister -f $EXPLORER" "$WORK_LOG"'
register_line="$(grep -n "^lsregister -f" "$WORK_LOG" | head -1 | cut -d: -f1)"
check "explorer-registered-before-shell-starts" '[[ -n "$register_line" && -n "$bootstrap_line" && "$register_line" -lt "$bootstrap_line" ]]'
check "explorer-fda-hint" 'grep -qE "Acesso Total ao Disco|Full Disk Access" "$WORK/out.log" && grep -q "open x-apple.systempreferences:.*Privacy_AllFiles" "$WORK_LOG" && grep -qx "open -R $EXPLORER" "$WORK_LOG"'
check "fileviewer-off-by-default" '! grep -qx "settings apply --only explorerFileViewer" "$WORK_LOG"'
PROMPT="$WORK/apps/Retro98 Prompt.app"
check "prompt-built" 'codesign --verify "$PROMPT" 2> /dev/null'
check "prompt-is-regular-app" '! /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$PROMPT/Contents/Info.plist" > /dev/null 2>&1'
check "prompt-has-font" '[[ -s "$PROMPT/Contents/Resources/PxPlus_IBM_VGA_8x16.ttf" && -s "$PROMPT/Contents/Resources/LICENSE-PxPlus_IBM_VGA_8x16.txt" ]]'
check "prompt-has-icon" '[[ -s "$PROMPT/Contents/Resources/AppIcon.icns" ]]'
check "prompt-apple-events-usage" '[[ -n "$(/usr/libexec/PlistBuddy -c "Print :NSAppleEventsUsageDescription" "$PROMPT/Contents/Info.plist" 2> /dev/null)" ]]'
check "prompt-registered" 'grep -qx "lsregister -f $PROMPT" "$WORK_LOG"'
check "prompt-not-default-terminal" '! /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" "$PROMPT/Contents/Info.plist" > /dev/null 2>&1 && ! /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PROMPT/Contents/Info.plist" > /dev/null 2>&1'

# Pieces saved before the Prompt existed get it (new pieces arrive on); a declined Prompt stays off and goes away.
rm -rf "$PROMPT"
echo "base shell" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-old-pieces.log" 2>&1
check "old-pieces-get-prompt" '[[ -d "$PROMPT" && "$(cat "$WORK/support/pieces")" == "base shell prompt" ]]'
echo "base shell noprompt" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-noprompt.log" 2>&1
check "declined-prompt-stays-off" '[[ ! -e "$PROMPT" ]] && grep -qx "lsregister -u $PROMPT" "$WORK_LOG" && [[ "$(cat "$WORK/support/pieces")" == "base shell noprompt" ]]'

# A Shell copy opened outside launchd must not survive a reinstall next to the LaunchAgent's copy.
mkdir -p "$WORK/apps/Retro98 Shell.app/Contents/MacOS"
cp /bin/sleep "$WORK/apps/Retro98 Shell.app/Contents/MacOS/Retro98Shell"
# A copied Apple binary is killed on launch outside the system folders; sign the copy ad hoc.
codesign --force --sign - "$WORK/apps/Retro98 Shell.app/Contents/MacOS/Retro98Shell" 2> /dev/null
"$WORK/apps/Retro98 Shell.app/Contents/MacOS/Retro98Shell" 300 > /dev/null 2>&1 &
stray_pid=$!
sleep 0.3
stray_alive_before="$(kill -0 $stray_pid 2> /dev/null && echo yes)"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-stray.log" 2>&1
sleep 0.3
check "stray-shell-was-running" '[[ -n "$stray_alive_before" ]]'
check "install-stops-stray-shell" '! kill -0 $stray_pid 2> /dev/null'
kill "$stray_pid" 2> /dev/null

# Choosing the Explorer as the file viewer applies its tweak.
echo "base shell fileviewer" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-viewer.log" 2>&1
check "fileviewer-applied-when-chosen" 'grep -qx "settings apply --only explorerFileViewer" "$WORK_LOG"'

# Re-install with only the base tweaks: the taskbar must be turned off and the Dock restored.
echo "base" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out2.log" 2>&1
check "shell-removed-when-not-chosen" '[[ ! -e "$WORK/agents/$LABEL.plist" && ! -e "$WORK/apps/Retro98 Shell.app" ]]'
check "explorer-removed-when-not-chosen" '[[ ! -e "$EXPLORER" ]] && grep -qx "lsregister -u $EXPLORER" "$WORK_LOG"'
check "dock-restored" 'grep -qx "settings restore --only dockUnderTaskbar" "$WORK_LOG"'
viewer_line="$(grep -nx "settings restore --only explorerFileViewer" "$WORK_LOG" | head -1 | cut -d: -f1)"
unregister_line="$(grep -nx "lsregister -u $EXPLORER" "$WORK_LOG" | head -1 | cut -d: -f1)"
# "Show in Finder" must point back at Finder before the Explorer leaves the disk.
check "install-without-shell-restores-file-viewer-first" '[[ -n "$viewer_line" && -n "$unregister_line" && "$viewer_line" -lt "$unregister_line" ]]'

# The bundle script must refuse anything that isn't an .app path (it deletes its target first).
mkdir -p "$WORK/nao-e-app" && touch "$WORK/nao-e-app/keep"
bash "$ROOT/scripts/build-shell-app.sh" "$WORK/nao-e-app" > /dev/null 2>&1
refused=$?
check "build-script-refuses-non-app" '[[ $refused -ne 0 && -f "$WORK/nao-e-app/keep" ]]'

# A failing Shell build must not leave the Dock shrunk.
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/failing-build"
chmod +x "$WORK/failing-build"
echo "shell" > "$WORK/support/pieces"
: > "$WORK_LOG"
RETRO98_BUILD_SHELL_APP="$WORK/failing-build" bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out3.log" 2>&1
build_status=$?
check "failed-build-exits-nonzero" '[[ $build_status -ne 0 ]]'
check "failed-build-keeps-dock" '! grep -q "apply --only dockUnderTaskbar" "$WORK_LOG"'

check "no-signing-keychain-created" '[[ ! -e "$WORK/never-created.keychain-db" ]]'

exit $((failures > 0 ? 1 : 0))
