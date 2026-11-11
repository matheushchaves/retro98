# Local code-signing identity for Retro98. Source after scripts/common.sh.
# A self-signed certificate in its own keychain keeps the Shell's designated requirement stable
# across rebuilds, so macOS remembers its Accessibility permission. The user's keychain search
# list is never left modified.

SIGNING_KEYCHAIN="${RETRO98_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/retro98-signing.keychain-db}"
SIGNING_IDENTITY="Retro98 Local Signing"
SIGNING_PASSWORD_FILE="$SUPPORT_DIR/signing-password"

# Prints the user's keychain search list, one path per line.
_signing_search_list() {
    security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//'
}

# Restores the search list from lines on stdin, skipping the signing keychain itself.
_signing_restore_search_list() {
    local paths=() line
    while IFS= read -r line; do
        [[ -n "$line" && "$line" != "$SIGNING_KEYCHAIN" ]] && paths+=("$line")
    done
    if [[ ${#paths[@]} -gt 0 ]]; then
        security list-keychains -d user -s "${paths[@]}"
    fi
}

ensure_signing_identity() {
    if [[ -f "$SIGNING_KEYCHAIN" && -f "$SIGNING_PASSWORD_FILE" ]]; then
        security unlock-keychain -p "$(cat "$SIGNING_PASSWORD_FILE")" "$SIGNING_KEYCHAIN" 2> /dev/null &&
            security find-certificate -c "$SIGNING_IDENTITY" "$SIGNING_KEYCHAIN" > /dev/null 2>&1 && return 0
    fi

    local saved password work
    saved="$(_signing_search_list)"
    [[ -f "$SIGNING_KEYCHAIN" ]] && { security delete-keychain "$SIGNING_KEYCHAIN" > /dev/null 2>&1 || rm -f "$SIGNING_KEYCHAIN"; }

    mkdir -p "$SUPPORT_DIR" "$(dirname "$SIGNING_KEYCHAIN")"
    (umask 077 && /usr/bin/openssl rand -hex 24 > "$SIGNING_PASSWORD_FILE")
    chmod 600 "$SIGNING_PASSWORD_FILE"
    password="$(cat "$SIGNING_PASSWORD_FILE")"

    work="$(mktemp -d)"
    cat > "$work/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $SIGNING_IDENTITY
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$work/cert.cnf" \
        -keyout "$work/key.pem" -out "$work/cert.pem" > /dev/null 2>&1
    /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -out "$work/identity.p12" \
        -passout "pass:$password" > /dev/null 2>&1

    security create-keychain -p "$password" "$SIGNING_KEYCHAIN"
    echo "$saved" | _signing_restore_search_list
    security set-keychain-settings "$SIGNING_KEYCHAIN"
    security unlock-keychain -p "$password" "$SIGNING_KEYCHAIN"
    security import "$work/identity.p12" -k "$SIGNING_KEYCHAIN" -P "$password" -T /usr/bin/codesign > /dev/null
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$SIGNING_KEYCHAIN" > /dev/null 2>&1
    rm -rf "$work"
}

# sign_app <path.app> <bundle identifier>
sign_app() {
    local app="$1" identifier="$2"
    if [[ "${RETRO98_SIGNING:-}" == "adhoc" ]]; then
        codesign --force --sign - -i "$identifier" "$app"
        return
    fi
    ensure_signing_identity
    codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" -i "$identifier" "$app"
}

remove_signing_identity() {
    local saved
    saved="$(_signing_search_list)"
    if [[ -f "$SIGNING_KEYCHAIN" ]]; then
        security delete-keychain "$SIGNING_KEYCHAIN" > /dev/null 2>&1 || rm -f "$SIGNING_KEYCHAIN"
    fi
    rm -f "$SIGNING_PASSWORD_FILE"
    echo "$saved" | _signing_restore_search_list
}
