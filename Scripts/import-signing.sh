#!/bin/bash
set -euo pipefail
umask 077
# Used only by the optional credentialed GitHub release path. Never prints secrets.
if [[ -z "${DEVELOPER_ID_CERT_BASE64:-}" ]]; then
    [[ -z "${SIGNING_IDENTITY:-}${NOTARY_KEY_ID:-}${NOTARY_ISSUER_ID:-}${NOTARY_KEY_P8:-}" ]] || { echo 'Partial signing configuration' >&2; exit 1; }
    exit 0
fi
: "${DEVELOPER_ID_CERT_PASSWORD:?}" "${SIGNING_IDENTITY:?}" "${NOTARY_KEY_ID:?}" "${NOTARY_ISSUER_ID:?}" "${NOTARY_KEY_P8:?}"
keychain="$RUNNER_TEMP/screensavers-signing.keychain-db"
cert="$RUNNER_TEMP/screensavers-certificate.p12"
trap 'rm -f "$cert"' EXIT
password=$(openssl rand -hex 24)
printf '%s' "$DEVELOPER_ID_CERT_BASE64" | base64 --decode > "$cert"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$cert" -k "$keychain" -P "$DEVELOPER_ID_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" login.keychain-db
rm -f "$cert"
