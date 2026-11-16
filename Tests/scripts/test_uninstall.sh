#!/usr/bin/env bash
# uninstall.sh must remove Retro98's files only when the restore fully succeeded.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB="$WORK/stub-settings"
printf '#!/usr/bin/env bash\nexit "${STUB_EXIT:-0}"\n' > "$STUB"
chmod +x "$STUB"

# Never touch the real Shell: a fake launchctl first in PATH, and temporary app/agent folders.
FAKE_BIN="$WORK/fake-bin"
mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\necho "$*" >> "${LAUNCHCTL_LOG:-/dev/null}"\nexit 0\n' > "$FAKE_BIN/launchctl"
printf '#!/usr/bin/env bash\necho "lsregister $*" >> "${LAUNCHCTL_LOG:-/dev/null}"\nexit 0\n' > "$WORK/stub-lsregister"
chmod +x "$FAKE_BIN/launchctl" "$WORK/stub-lsregister"
export RETRO98_LSREGISTER="$WORK/stub-lsregister"
export PATH="$FAKE_BIN:$PATH"
export RETRO98_APPS_DIR="$WORK/apps-default"
export RETRO98_LAUNCH_AGENTS_DIR="$WORK/agents-default"
# Never touch the real ~/Library/Sounds.
export RETRO98_SOUNDS_DIR="$WORK/sounds-default"
# Never touch the real signing keychain either.
export RETRO98_SIGNING_KEYCHAIN="$WORK/default-signing.keychain-db"
# Nor the real permissions (tccutil) or the Shell's real preferences (defaults).
printf '#!/usr/bin/env bash\necho "tccutil $*" >> "${LAUNCHCTL_LOG:-/dev/null}"\nexit "${TCCUTIL_EXIT:-0}"\n' > "$WORK/stub-tccutil"
printf '#!/usr/bin/env bash\necho "defaults $*" >> "${LAUNCHCTL_LOG:-/dev/null}"\nexit 0\n' > "$WORK/stub-defaults"
chmod +x "$WORK/stub-tccutil" "$WORK/stub-defaults"
export RETRO98_TCCUTIL="$WORK/stub-tccutil"
export RETRO98_DEFAULTS="$WORK/stub-defaults"
# Nor the real ~/Library/Fonts or Sublime Text's real packages.
export RETRO98_FONTS_DIR="$WORK/fonts-default"
export RETRO98_SUBLIME_PACKAGES="$WORK/sublime-default/Packages"
FONT_FILE="PxPlus_IBM_VGA_8x16.ttf"

# Plants what the installer's themes piece leaves: <support> <fonts> <sublime packages>
plant_themes() {
    local themes="$1/Themes" fonts="$2" package="$3/Retro98"
    mkdir -p "$themes/Chrome/images" "$fonts" "$package"
    echo "{}" > "$themes/Chrome/manifest.json"
    echo "png" > "$themes/Chrome/images/theme_frame.png"
    echo "png" > "$themes/Chrome/images/theme_frame_inactive.png"
    echo "plist" > "$themes/Retro98 Prompt.terminal"
    : > "$1/font-installed"
    cp "$ROOT/Resources/Fonts/$FONT_FILE" "$fonts/$FONT_FILE"
    echo "{}" > "$package/Retro98.sublime-theme"
    echo "{}" > "$package/Retro98.sublime-color-scheme"
}
LABEL="io.github.matheushchaves.retro98.shell"

failures=0

run_case() {
    local name="$1" stub_exit="$2" expected_exit="$3" expected_backup="$4" extra_path="${5:-}"
    local support="$WORK/support-$name"
    mkdir -p "$support/bin"
    echo "<plist/>" > "$support/backup.plist"
    [[ "$name" == "dsstore" ]] && echo "finder" > "$support/.DS_Store"

    PATH="${extra_path:+$extra_path:}$PATH" \
        STUB_EXIT="$stub_exit" RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$support" \
        bash "$ROOT/uninstall.sh" > /dev/null 2>&1
    local actual_exit=$?

    local backup_state="absent"
    [[ -f "$support/backup.plist" ]] && backup_state="present"
    local dir_state="absent"
    [[ -d "$support" ]] && dir_state="present"

    if [[ "$actual_exit" == "$expected_exit" && "$backup_state" == "$expected_backup" ]] \
        && { [[ "$expected_backup" == "present" ]] || [[ "$dir_state" == "absent" ]]; }; then
        echo "PASS $name"
    else
        echo "FAIL $name (exit $actual_exit, backup $backup_state, folder $dir_state)"
        failures=$((failures + 1))
    fi
}

run_case restored 0 0 absent
run_case partial 2 2 present
run_case corrupted 3 3 present
run_case dsstore 0 0 absent

# A failing `defaults read` (language lookup) must not abort the script before restore runs.
BROKEN_DEFAULTS="$WORK/broken-defaults"
mkdir -p "$BROKEN_DEFAULTS"
printf '#!/usr/bin/env bash\nexit 1\n' > "$BROKEN_DEFAULTS/defaults"
chmod +x "$BROKEN_DEFAULTS/defaults"
run_case defaults-unreadable 0 0 absent "$BROKEN_DEFAULTS"

run_shell_case() {
    local name="$1" stub_exit="$2" expected_exit="$3" expected_app="$4"
    local support="$WORK/support-$name" apps="$WORK/apps-$name" agents="$WORK/agents-$name" calls="$WORK/launchctl-$name.log"
    local sounds="$WORK/sounds-$name" fonts="$WORK/fonts-$name" packages="$WORK/sublime-$name/Packages"
    plant_themes "$support" "$fonts" "$packages"
    mkdir -p "$support" "$apps/Retro98 Shell.app/Contents" "$apps/Retro98 Explorer.app/Contents" "$apps/Retro98 Prompt.app/Contents" "$agents"
    mkdir -p "$apps/Retro98 Control Panel.app/Contents" "$apps/Retro98 Notepad.app/Contents" "$sounds"
    echo "aiff" > "$sounds/Retro98.aiff"
    echo "<plist/>" > "$support/choices.plist"
    echo "png" > "$support/wallpaper-picture-1.png"
    echo "finder" > "$apps/.DS_Store"   # Finder leaves one after the installer shows the folder
    echo "<plist/>" > "$support/backup.plist"
    echo "<plist/>" > "$agents/$LABEL.plist"

    LAUNCHCTL_LOG="$calls" STUB_EXIT="$stub_exit" RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$support" \
        RETRO98_APPS_DIR="$apps" RETRO98_LAUNCH_AGENTS_DIR="$agents" RETRO98_SOUNDS_DIR="$sounds" \
        RETRO98_FONTS_DIR="$fonts" RETRO98_SUBLIME_PACKAGES="$packages" \
        bash "$ROOT/uninstall.sh" > /dev/null 2>&1
    local actual_exit=$?

    local app_state="absent"
    [[ -d "$apps/Retro98 Shell.app" ]] && app_state="present"
    local problems=""
    [[ "$actual_exit" == "$expected_exit" ]] || problems+=" exit=$actual_exit"
    grep -q "bootout gui/$(id -u)/$LABEL" "$calls" 2>/dev/null || problems+=" no-bootout"
    [[ ! -f "$agents/$LABEL.plist" ]] || problems+=" agent-plist-left"
    [[ "$app_state" == "$expected_app" ]] || problems+=" app=$app_state"
    local explorer_state="absent"
    [[ -d "$apps/Retro98 Explorer.app" ]] && explorer_state="present"
    [[ "$explorer_state" == "$expected_app" ]] || problems+=" explorer=$explorer_state"
    if [[ "$expected_app" == "absent" ]] && ! grep -qx "lsregister -u $apps/Retro98 Explorer.app" "$calls"; then
        problems+=" explorer-not-unregistered"
    fi
    local prompt_state="absent"
    [[ -d "$apps/Retro98 Prompt.app" ]] && prompt_state="present"
    [[ "$prompt_state" == "$expected_app" ]] || problems+=" prompt=$prompt_state"
    if [[ "$expected_app" == "absent" ]] && ! grep -qx "lsregister -u $apps/Retro98 Prompt.app" "$calls"; then
        problems+=" prompt-not-unregistered"
    fi
    local notepad_state="absent"
    [[ -d "$apps/Retro98 Notepad.app" ]] && notepad_state="present"
    [[ "$notepad_state" == "$expected_app" ]] || problems+=" notepad=$notepad_state"
    if [[ "$expected_app" == "absent" ]] && ! grep -qx "lsregister -u $apps/Retro98 Notepad.app" "$calls"; then
        problems+=" notepad-not-unregistered"
    fi
    local panel_state="absent"
    [[ -d "$apps/Retro98 Control Panel.app" ]] && panel_state="present"
    [[ "$panel_state" == "$expected_app" ]] || problems+=" control-panel=$panel_state"
    if [[ "$expected_app" == "absent" ]] && ! grep -qx "lsregister -u $apps/Retro98 Control Panel.app" "$calls"; then
        problems+=" control-panel-not-unregistered"
    fi
    for file in "$sounds/Retro98.aiff" "$support/choices.plist" "$support/wallpaper-picture-1.png"; do
        local file_state="absent"
        [[ -e "$file" ]] && file_state="present"
        [[ "$file_state" == "$expected_app" ]] || problems+=" $(basename "$file")=$file_state"
    done
    if [[ "$expected_app" == "absent" && -d "$apps" ]]; then problems+=" apps-folder-left"; fi
    for file in "$support/Themes/Chrome/manifest.json" "$support/Themes/Retro98 Prompt.terminal" "$fonts/$FONT_FILE" \
        "$packages/Retro98/Retro98.sublime-theme" "$packages/Retro98/Retro98.sublime-color-scheme"; do
        local theme_state="absent"
        [[ -e "$file" ]] && theme_state="present"
        [[ "$theme_state" == "$expected_app" ]] || problems+=" $(basename "$file")=$theme_state"
    done
    if [[ "$expected_app" == "absent" && ( -d "$support" || -d "$packages/Retro98" ) ]]; then problems+=" theme-folders-left"; fi
    if [[ "$expected_app" == "absent" ]]; then
        local id last_reset first_unregister
        for id in "$LABEL" io.github.matheushchaves.retro98.explorer io.github.matheushchaves.retro98.prompt \
            io.github.matheushchaves.retro98.controlpanel io.github.matheushchaves.retro98.notepad; do
            grep -qx "tccutil reset All $id" "$calls" || problems+=" permissions-kept:$id"
        done
        # tccutil can't find an unregistered bundle ID: every reset must come before any unregistering.
        last_reset="$(grep -n "^tccutil reset" "$calls" | tail -1 | cut -d: -f1)"
        first_unregister="$(grep -n "^lsregister -u" "$calls" | head -1 | cut -d: -f1)"
        [[ -n "$last_reset" && -n "$first_unregister" && "$last_reset" -lt "$first_unregister" ]] || problems+=" reset-after-unregister"
        grep -qx "lsregister -u $apps/Retro98 Shell.app" "$calls" || problems+=" shell-not-unregistered"
        grep -qx "defaults delete $LABEL" "$calls" || problems+=" prompt-mark-kept"
    elif grep -q "^tccutil" "$calls"; then
        problems+=" permissions-cleared-on-failure"
    fi
    if [[ "$expected_app" == "present" && ! -f "$support/backup.plist" ]]; then problems+=" backup-lost"; fi

    if [[ -z "$problems" ]]; then
        echo "PASS $name"
    else
        echo "FAIL $name ($problems )"
        failures=$((failures + 1))
    fi
}

run_shell_case explorer-removed 0 0 absent
run_shell_case shell-kept-on-failure 2 2 present

# With themes installed, the closing note says what is left to remove inside Chrome and Terminal.
themes_note_case() {   # <name> <with themes: yes|no>
    local name="$1" with_themes="$2"
    local support="$WORK/support-$name" fonts="$WORK/fonts-$name" packages="$WORK/sublime-$name/Packages"
    mkdir -p "$support"
    echo "<plist/>" > "$support/backup.plist"
    [[ "$with_themes" == yes ]] && plant_themes "$support" "$fonts" "$packages"
    STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$support" RETRO98_APPS_DIR="$WORK/apps-$name" \
        RETRO98_FONTS_DIR="$fonts" RETRO98_SUBLIME_PACKAGES="$packages" bash "$ROOT/uninstall.sh" > "$WORK/$name.log" 2>&1
    local told=no
    grep -qE "Temas removidos|Themes removed" "$WORK/$name.log" && told=yes
    if [[ "$told" == "$with_themes" ]]; then
        echo "PASS $name"
    else
        echo "FAIL $name (note told=$told)"
        failures=$((failures + 1))
    fi
}
themes_note_case themes-note-when-removed yes
themes_note_case no-themes-note-without-themes no

# A font the person already had (no marker from the installer) survives, and so do their own files in the package.
OWN_SUPPORT="$WORK/support-ownfont" OWN_FONTS="$WORK/fonts-ownfont" OWN_PACKAGES="$WORK/sublime-ownfont/Packages"
mkdir -p "$OWN_SUPPORT"
echo "<plist/>" > "$OWN_SUPPORT/backup.plist"
plant_themes "$OWN_SUPPORT" "$OWN_FONTS" "$OWN_PACKAGES"
rm "$OWN_SUPPORT/font-installed"
echo "da pessoa" > "$OWN_PACKAGES/Retro98/minha.txt"
STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$OWN_SUPPORT" RETRO98_APPS_DIR="$WORK/apps-ownfont" \
    RETRO98_FONTS_DIR="$OWN_FONTS" RETRO98_SUBLIME_PACKAGES="$OWN_PACKAGES" bash "$ROOT/uninstall.sh" > /dev/null 2>&1
if [[ -e "$OWN_FONTS/$FONT_FILE" && -e "$OWN_PACKAGES/Retro98/minha.txt" && ! -e "$OWN_PACKAGES/Retro98/Retro98.sublime-theme" \
    && ! -d "$OWN_SUPPORT" ]]; then
    echo "PASS uninstall-keeps-the-persons-font-and-files"
else
    echo "FAIL uninstall-keeps-the-persons-font-and-files"
    failures=$((failures + 1))
fi

# The themes folder is visible in Finder: with it binned, uninstall still removes the font and the Sublime package.
GONE_SUPPORT="$WORK/support-nofolder" GONE_FONTS="$WORK/fonts-nofolder" GONE_PACKAGES="$WORK/sublime-nofolder/Packages"
mkdir -p "$GONE_SUPPORT"
echo "<plist/>" > "$GONE_SUPPORT/backup.plist"
plant_themes "$GONE_SUPPORT" "$GONE_FONTS" "$GONE_PACKAGES"
rm -rf "$GONE_SUPPORT/Themes"
STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$GONE_SUPPORT" RETRO98_APPS_DIR="$WORK/apps-nofolder" \
    RETRO98_FONTS_DIR="$GONE_FONTS" RETRO98_SUBLIME_PACKAGES="$GONE_PACKAGES" bash "$ROOT/uninstall.sh" > "$WORK/nofolder.log" 2>&1
if [[ ! -e "$GONE_FONTS/$FONT_FILE" && ! -d "$GONE_PACKAGES/Retro98" && ! -d "$GONE_SUPPORT" ]] \
    && grep -qE "Temas removidos|Themes removed" "$WORK/nofolder.log"; then
    echo "PASS uninstall-removes-themes-without-their-folder"
else
    echo "FAIL uninstall-removes-themes-without-their-folder"
    failures=$((failures + 1))
fi

# A font Retro98 installed and the person later replaced is theirs: uninstall leaves it.
SWAP_SUPPORT="$WORK/support-swapped" SWAP_FONTS="$WORK/fonts-swapped" SWAP_PACKAGES="$WORK/sublime-swapped/Packages"
mkdir -p "$SWAP_SUPPORT"
echo "<plist/>" > "$SWAP_SUPPORT/backup.plist"
plant_themes "$SWAP_SUPPORT" "$SWAP_FONTS" "$SWAP_PACKAGES"
echo "trocada pela pessoa" > "$SWAP_FONTS/$FONT_FILE"
STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$SWAP_SUPPORT" RETRO98_APPS_DIR="$WORK/apps-swapped" \
    RETRO98_FONTS_DIR="$SWAP_FONTS" RETRO98_SUBLIME_PACKAGES="$SWAP_PACKAGES" bash "$ROOT/uninstall.sh" > /dev/null 2>&1
if [[ "$(cat "$SWAP_FONTS/$FONT_FILE" 2> /dev/null)" == "trocada pela pessoa" && ! -d "$SWAP_SUPPORT" ]]; then
    echo "PASS uninstall-keeps-a-replaced-font"
else
    echo "FAIL uninstall-keeps-a-replaced-font"
    failures=$((failures + 1))
fi

# The closing note says whether macOS forgot Retro98's permissions or they must be removed by hand.
permissions_note_case() {   # <name> <tccutil exit> <expected note>
    local name="$1" tccutil_exit="$2" pattern="$3"
    local support="$WORK/support-$name" apps="$WORK/apps-$name"
    mkdir -p "$support" "$apps/Retro98 Shell.app/Contents"
    echo "<plist/>" > "$support/backup.plist"
    TCCUTIL_EXIT="$tccutil_exit" STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$support" \
        RETRO98_APPS_DIR="$apps" bash "$ROOT/uninstall.sh" > "$WORK/$name.log" 2>&1
    local actual_exit=$?
    if [[ $actual_exit -eq 0 ]] && grep -qE "$pattern" "$WORK/$name.log"; then
        echo "PASS $name"
    else
        echo "FAIL $name (exit $actual_exit: $(tail -2 "$WORK/$name.log" | tr '\n' ' '))"
        failures=$((failures + 1))
    fi
}
permissions_note_case permissions-cleared-note 0 "também foram apagadas|were cleared too"
permissions_note_case permissions-left-note 1 "Não consegui apagar|Couldn't clear"

# Copies opened outside launchd (System Settings' "Quit & Reopen", Finder, the Start menu) survive
# `launchctl bootout`: uninstall must stop them by their executable path, and only those.
start_fake_app() {   # <bundle> <executable name> → prints the pid of a process running from that bundle
    mkdir -p "$1/Contents/MacOS"
    cp /bin/sleep "$1/Contents/MacOS/$2"
    # A copied Apple binary is killed on launch outside the system folders; sign the copy ad hoc.
    codesign --force --sign - "$1/Contents/MacOS/$2" 2> /dev/null
    "$1/Contents/MacOS/$2" 300 > /dev/null 2>&1 &
    echo $!
}
STRAY_APPS="$WORK/apps-stray"
STRAY_SUPPORT="$WORK/support-stray"
mkdir -p "$STRAY_SUPPORT" "$WORK/agents-stray"
echo "<plist/>" > "$STRAY_SUPPORT/backup.plist"
shell_pid="$(start_fake_app "$STRAY_APPS/Retro98 Shell.app" Retro98Shell)"
explorer_pid="$(start_fake_app "$STRAY_APPS/Retro98 Explorer.app" Retro98Explorer)"
prompt_pid="$(start_fake_app "$STRAY_APPS/Retro98 Prompt.app" Retro98Prompt)"
bystander_pid="$(start_fake_app "$WORK/other/Retro98 Shell.app" Retro98Shell)"   # same name, other path
sleep 0.3
STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$STRAY_SUPPORT" RETRO98_APPS_DIR="$STRAY_APPS" \
    RETRO98_LAUNCH_AGENTS_DIR="$WORK/agents-stray" bash "$ROOT/uninstall.sh" > /dev/null 2>&1
sleep 0.3
if ! kill -0 "$shell_pid" 2>/dev/null && ! kill -0 "$explorer_pid" 2>/dev/null && ! kill -0 "$prompt_pid" 2>/dev/null \
    && kill -0 "$bystander_pid" 2>/dev/null; then
    echo "PASS stray-copies-stopped"
else
    echo "FAIL stray-copies-stopped (shell $(kill -0 "$shell_pid" 2>/dev/null && echo alive || echo gone)," \
        "explorer $(kill -0 "$explorer_pid" 2>/dev/null && echo alive || echo gone)," \
        "prompt $(kill -0 "$prompt_pid" 2>/dev/null && echo alive || echo gone)," \
        "bystander $(kill -0 "$bystander_pid" 2>/dev/null && echo alive || echo gone))"
    failures=$((failures + 1))
fi
kill "$shell_pid" "$explorer_pid" "$prompt_pid" "$bystander_pid" 2>/dev/null

# The local signing keychain goes away with a successful uninstall; the search list is untouched.
BEFORE_LIST="$(security list-keychains -d user)"
SIGN_SUPPORT="$WORK/support-signing"
SIGN_KEYCHAIN="$WORK/signing-case.keychain-db"
mkdir -p "$SIGN_SUPPORT"
echo "<plist/>" > "$SIGN_SUPPORT/backup.plist"
echo "secret" > "$SIGN_SUPPORT/signing-password"
security create-keychain -p secret "$SIGN_KEYCHAIN" > /dev/null 2>&1
security list-keychains -d user -s $(echo "$BEFORE_LIST" | tr -d '"')
STUB_EXIT=0 RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$SIGN_SUPPORT" RETRO98_SIGNING_KEYCHAIN="$SIGN_KEYCHAIN" \
    bash "$ROOT/uninstall.sh" > "$WORK/signing-out.log" 2>&1
if [[ ! -e "$SIGN_KEYCHAIN" && "$(security list-keychains -d user)" == "$BEFORE_LIST" ]] \
    && grep -qE "Privacidade e Segurança|Privacy & Security" "$WORK/signing-out.log"; then
    echo "PASS signing-removed"
else
    echo "FAIL signing-removed"
    failures=$((failures + 1))
    [[ -e "$SIGN_KEYCHAIN" ]] && security delete-keychain "$SIGN_KEYCHAIN" > /dev/null 2>&1
fi

# "Show in Finder" must point back at Finder (the restore) while the Explorer still exists.
VIEWER_SUPPORT="$WORK/support-viewer"
VIEWER_APPS="$WORK/apps-viewer"
mkdir -p "$VIEWER_SUPPORT" "$VIEWER_APPS/Retro98 Explorer.app/Contents"
echo "<plist/>" > "$VIEWER_SUPPORT/backup.plist"
VIEWER_STUB="$WORK/stub-viewer"
printf '#!/usr/bin/env bash\nif [[ -d "$RETRO98_APPS_DIR/Retro98 Explorer.app" ]]; then state=present; else state=gone; fi\necho "settings $* explorer-$state" >> "$VIEWER_LOG"\nexit 0\n' > "$VIEWER_STUB"
chmod +x "$VIEWER_STUB"
VIEWER_LOG="$WORK/viewer.log" RETRO98_SETTINGS_BIN="$VIEWER_STUB" RETRO98_SUPPORT_DIR="$VIEWER_SUPPORT" RETRO98_APPS_DIR="$VIEWER_APPS" \
    bash "$ROOT/uninstall.sh" > /dev/null 2>&1
if grep -qx "settings restore explorer-present" "$WORK/viewer.log" && [[ ! -e "$VIEWER_APPS/Retro98 Explorer.app" ]]; then
    echo "PASS uninstall-restores-file-viewer-before-removing-explorer"
else
    echo "FAIL uninstall-restores-file-viewer-before-removing-explorer ($(cat "$WORK/viewer.log" 2>/dev/null))"
    failures=$((failures + 1))
fi

exit $((failures > 0 ? 1 : 0))
