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
chmod +x "$FAKE_BIN/launchctl"
export PATH="$FAKE_BIN:$PATH"
export RETRO98_APPS_DIR="$WORK/apps-default"
export RETRO98_LAUNCH_AGENTS_DIR="$WORK/agents-default"
# Never touch the real signing keychain either.
export RETRO98_SIGNING_KEYCHAIN="$WORK/default-signing.keychain-db"
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
    mkdir -p "$support" "$apps/Retro98 Shell.app/Contents" "$agents"
    echo "<plist/>" > "$support/backup.plist"
    echo "<plist/>" > "$agents/$LABEL.plist"

    LAUNCHCTL_LOG="$calls" STUB_EXIT="$stub_exit" RETRO98_SETTINGS_BIN="$STUB" RETRO98_SUPPORT_DIR="$support" \
        RETRO98_APPS_DIR="$apps" RETRO98_LAUNCH_AGENTS_DIR="$agents" bash "$ROOT/uninstall.sh" > /dev/null 2>&1
    local actual_exit=$?

    local app_state="absent"
    [[ -d "$apps/Retro98 Shell.app" ]] && app_state="present"
    local problems=""
    [[ "$actual_exit" == "$expected_exit" ]] || problems+=" exit=$actual_exit"
    grep -q "bootout gui/$(id -u)/$LABEL" "$calls" 2>/dev/null || problems+=" no-bootout"
    [[ ! -f "$agents/$LABEL.plist" ]] || problems+=" agent-plist-left"
    [[ "$app_state" == "$expected_app" ]] || problems+=" app=$app_state"
    if [[ "$expected_app" == "present" && ! -f "$support/backup.plist" ]]; then problems+=" backup-lost"; fi

    if [[ -z "$problems" ]]; then
        echo "PASS $name"
    else
        echo "FAIL $name ($problems )"
        failures=$((failures + 1))
    fi
}

run_shell_case shell-removed 0 0 absent
run_shell_case shell-kept-on-failure 2 2 present

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
    && grep -qE "Acessibilidade|Accessibility" "$WORK/signing-out.log"; then
    echo "PASS signing-removed"
else
    echo "FAIL signing-removed"
    failures=$((failures + 1))
    [[ -e "$SIGN_KEYCHAIN" ]] && security delete-keychain "$SIGN_KEYCHAIN" > /dev/null 2>&1
fi

exit $((failures > 0 ? 1 : 0))
