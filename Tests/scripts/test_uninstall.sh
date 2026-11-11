#!/usr/bin/env bash
# uninstall.sh must remove Retro98's files only when the restore fully succeeded.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB="$WORK/stub-settings"
printf '#!/usr/bin/env bash\nexit "${STUB_EXIT:-0}"\n' > "$STUB"
chmod +x "$STUB"

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

exit $((failures > 0 ? 1 : 0))
