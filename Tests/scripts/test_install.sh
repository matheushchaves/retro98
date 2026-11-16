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
# Never touch the real ~/Library/Sounds.
export RETRO98_SOUNDS_DIR="$WORK/sounds"
# Never register anything with the real LaunchServices database.
export RETRO98_LSREGISTER="$WORK/stub-lsregister"
# Never create the real signing keychain from tests.
export RETRO98_SIGNING=adhoc
export RETRO98_SIGNING_KEYCHAIN="$WORK/never-created.keychain-db"
# Never touch the real permissions or the Shell's real preferences.
export RETRO98_TCCUTIL=/usr/bin/false
export RETRO98_DEFAULTS=/usr/bin/false
# Never touch the real ~/Library/Fonts or Sublime Text's real packages.
export RETRO98_FONTS_DIR="$WORK/fonts"
export RETRO98_SUBLIME_PACKAGES="$WORK/sublime/Packages"
mkdir -p "$WORK/sublime/Packages"
FONT_FILE="PxPlus_IBM_VGA_8x16.ttf"
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
check "pieces-recorded" '[[ "$(cat "$WORK/support/pieces")" == "base shell prompt notepad themes" ]]'
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
CONTROL_PANEL="$WORK/apps/Retro98 Control Panel.app"
check "control-panel-built" 'codesign --verify "$CONTROL_PANEL" 2> /dev/null'
check "control-panel-is-regular-app" '! /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$CONTROL_PANEL/Contents/Info.plist" > /dev/null 2>&1'
check "control-panel-has-icon" '[[ -s "$CONTROL_PANEL/Contents/Resources/AppIcon.icns" ]]'
check "control-panel-apple-events-usage" '[[ "$(/usr/libexec/PlistBuddy -c "Print :NSAppleEventsUsageDescription" "$CONTROL_PANEL/Contents/Info.plist" 2> /dev/null)" == "Retro98 Control Panel uses System Events to switch between light and dark mode right away." ]]'
check "control-panel-registered" 'grep -qx "lsregister -f $CONTROL_PANEL" "$WORK_LOG"'
NOTEPAD="$WORK/apps/Retro98 Notepad.app"
check "notepad-built" 'codesign --verify "$NOTEPAD" 2> /dev/null'
check "notepad-is-regular-app" '! /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$NOTEPAD/Contents/Info.plist" > /dev/null 2>&1'
check "notepad-has-font" '[[ -s "$NOTEPAD/Contents/Resources/PxPlus_IBM_VGA_8x16.ttf" && -s "$NOTEPAD/Contents/Resources/LICENSE-PxPlus_IBM_VGA_8x16.txt" ]]'
check "notepad-has-icon" '[[ -s "$NOTEPAD/Contents/Resources/AppIcon.icns" ]]'
# Listed in "Open With" for text files without becoming their default app.
check "notepad-opens-plain-text-without-being-default" '[[ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSItemContentTypes:0" "$NOTEPAD/Contents/Info.plist" 2> /dev/null)" == "public.plain-text" && "$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$NOTEPAD/Contents/Info.plist" 2> /dev/null)" == "Alternate" && "$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeRole" "$NOTEPAD/Contents/Info.plist" 2> /dev/null)" == "Editor" ]]'
check "notepad-registered" 'grep -qx "lsregister -f $NOTEPAD" "$WORK_LOG"'
check "other-apps-declare-no-documents" '! /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" "$EXPLORER/Contents/Info.plist" > /dev/null 2>&1'
THEMES="$WORK/support/Themes"
check "themes-written" '[[ -s "$THEMES/Chrome/manifest.json" && -s "$THEMES/Chrome/images/theme_frame.png" && -s "$THEMES/Chrome/images/theme_frame_inactive.png" && -s "$THEMES/Retro98 Prompt.terminal" ]] && plutil -lint "$THEMES/Retro98 Prompt.terminal" > /dev/null && plutil -convert xml1 -o /dev/null "$THEMES/Chrome/manifest.json"'
check "themes-font-installed" 'cmp -s "$WORK/fonts/$FONT_FILE" "$ROOT/Resources/Fonts/$FONT_FILE" && [[ -e "$WORK/support/font-installed" ]]'
check "themes-sublime-installed" '[[ -s "$WORK/sublime/Packages/Retro98/Retro98.sublime-theme" && -s "$WORK/sublime/Packages/Retro98/Retro98.sublime-color-scheme" ]]'
check "themes-steps-told" 'grep -q "chrome://extensions" "$WORK/out.log" && grep -q "Retro98 Prompt.terminal" "$WORK/out.log" && grep -q "Select Theme" "$WORK/out.log"'
check "themes-folder-opened-the-first-time" 'grep -qx "open $THEMES" "$WORK_LOG"'

# Turned off in the Control Panel ("shelloff"): the apps are rebuilt, the taskbar stays off and the Dock normal.
echo "base shelloff prompt" > "$WORK/support/pieces"
rm -rf "$WORK/apps/Retro98 Shell.app"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-shelloff.log" 2>&1
check "shelloff-keeps-taskbar-off" '[[ -d "$WORK/apps/Retro98 Shell.app" ]] && ! grep -q "^bootstrap " "$WORK_LOG" \
    && grep -qx "settings restore --only dockUnderTaskbar" "$WORK_LOG" && grep -q "^bootout gui/$(id -u)/$LABEL" "$WORK_LOG" \
    && [[ ! -e "$WORK/agents/$LABEL.plist" ]] && [[ "$(cat "$WORK/support/pieces")" == "base shelloff prompt notepad themes" ]]'
# A later install refreshes the themes without opening their folder again, and the font stays marked as ours.
check "themes-folder-not-opened-again" '! grep -qx "open $THEMES" "$WORK_LOG" && [[ -e "$WORK/support/font-installed" && -s "$THEMES/Chrome/manifest.json" ]]'

# Pieces saved before the Prompt existed get it (new pieces arrive on); a declined Prompt stays off and goes away.
rm -rf "$PROMPT"
echo "base shell" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-old-pieces.log" 2>&1
check "old-pieces-get-prompt" '[[ -d "$PROMPT" && "$(cat "$WORK/support/pieces")" == "base shell prompt notepad themes" ]]'
echo "base shell noprompt" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-noprompt.log" 2>&1
check "declined-prompt-stays-off" '[[ ! -e "$PROMPT" ]] && grep -qx "lsregister -u $PROMPT" "$WORK_LOG" && [[ "$(cat "$WORK/support/pieces")" == "base shell noprompt notepad themes" ]]'

# The same for the Notepad: pieces saved before it existed get it; a declined one stays off and goes away.
rm -rf "$NOTEPAD"
echo "base shell prompt" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-old-notepad.log" 2>&1
check "old-pieces-get-notepad" '[[ -d "$NOTEPAD" && "$(cat "$WORK/support/pieces")" == "base shell prompt notepad themes" ]]'
echo "base shell nonotepad" > "$WORK/support/pieces"
: > "$WORK_LOG"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-nonotepad.log" 2>&1
check "declined-notepad-stays-off" '[[ ! -e "$NOTEPAD" ]] && grep -qx "lsregister -u $NOTEPAD" "$WORK_LOG" && [[ "$(cat "$WORK/support/pieces")" == "base shell nonotepad prompt themes" ]]'

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

# A font the person already had is never replaced, and never marked as Retro98's.
mkdir -p "$WORK/support-font" "$WORK/fonts-own"
echo "fonte da pessoa" > "$WORK/fonts-own/$FONT_FILE"
echo "base noprompt nonotepad themes" > "$WORK/support-font/pieces"
RETRO98_SUPPORT_DIR="$WORK/support-font" RETRO98_FONTS_DIR="$WORK/fonts-own" bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-font.log" 2>&1
check "themes-keep-the-persons-font" '[[ "$(cat "$WORK/fonts-own/$FONT_FILE")" == "fonte da pessoa" && ! -e "$WORK/support-font/font-installed" && -s "$WORK/support-font/Themes/Retro98 Prompt.terminal" ]]'

# Without Sublime Text the installer says so and creates nothing in its place.
mkdir -p "$WORK/support-nosublime"
echo "base noprompt nonotepad themes" > "$WORK/support-nosublime/pieces"
RETRO98_SUPPORT_DIR="$WORK/support-nosublime" RETRO98_SUBLIME_PACKAGES="$WORK/no-sublime/Packages" bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-nosublime.log" 2>&1
check "themes-without-sublime" 'grep -qE "Sublime Text não encontrado|Sublime Text not found" "$WORK/out-nosublime.log" && [[ ! -e "$WORK/no-sublime" ]]'

# When the themes can't be generated, the installer fails and leaves no font or Sublime package behind.
mkdir -p "$WORK/support-broken" "$WORK/sublime-broken/Packages"
echo "base noprompt nonotepad themes" > "$WORK/support-broken/pieces"
RETRO98_TOOLS=/usr/bin/false RETRO98_SUPPORT_DIR="$WORK/support-broken" RETRO98_FONTS_DIR="$WORK/fonts-broken" \
    RETRO98_SUBLIME_PACKAGES="$WORK/sublime-broken/Packages" bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-broken.log" 2>&1
broken_status=$?
check "failed-themes-fail-the-install" '[[ $broken_status -ne 0 ]] && ! grep -qE "Temas do Retro98 em|Retro98 themes are in" "$WORK/out-broken.log" && grep -qE "Não foi possível preparar os temas|Couldn.t prepare the themes" "$WORK/out-broken.log"'
check "failed-themes-leave-nothing" '[[ ! -e "$WORK/fonts-broken/$FONT_FILE" && ! -e "$WORK/sublime-broken/Packages/Retro98" && ! -e "$WORK/support-broken/font-installed" ]]'

# Declining the themes later removes what the installer put, and only that.
echo "base noprompt nonotepad themes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-themes-on.log" 2>&1
echo "da pessoa" > "$WORK/sublime/Packages/Retro98/minha.txt"
echo "base noprompt nonotepad nothemes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > "$WORK/out-nothemes.log" 2>&1
check "declined-themes-are-removed" '[[ ! -e "$THEMES" && ! -e "$WORK/fonts/$FONT_FILE" && ! -e "$WORK/sublime/Packages/Retro98/Retro98.sublime-theme" && ! -e "$WORK/sublime/Packages/Retro98/Retro98.sublime-color-scheme" ]]'
check "declined-themes-keep-the-persons-files" '[[ "$(cat "$WORK/sublime/Packages/Retro98/minha.txt")" == "da pessoa" && "$(cat "$WORK/support/pieces")" == "base noprompt nonotepad nothemes" ]]'

# The themes folder is visible in Finder: binning it must not orphan the font or the Sublime package.
echo "base noprompt nonotepad themes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > /dev/null 2>&1
rm -rf "$THEMES"
echo "base noprompt nonotepad nothemes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > /dev/null 2>&1
check "themes-removed-even-without-their-folder" '[[ ! -e "$WORK/fonts/$FONT_FILE" && ! -e "$WORK/sublime/Packages/Retro98/Retro98.sublime-theme" && ! -e "$WORK/support/font-installed" ]]'

# A font Retro98 installed and the person later replaced with their own file is theirs: it stays.
echo "base noprompt nonotepad themes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > /dev/null 2>&1
echo "trocada pela pessoa" > "$WORK/fonts/$FONT_FILE"
echo "base noprompt nonotepad nothemes" > "$WORK/support/pieces"
bash "$ROOT/install.sh" --yes < /dev/null > /dev/null 2>&1
check "replaced-font-is-kept" '[[ "$(cat "$WORK/fonts/$FONT_FILE" 2> /dev/null)" == "trocada pela pessoa" && ! -e "$WORK/support/font-installed" ]]'
rm -f "$WORK/fonts/$FONT_FILE"

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
