#!/usr/bin/env bash
set -e

# Generate a single-use keystore for signing the F-Droid APK.
# Intended to be sourced: `source generate-keystore.sh <keystore_path>`
# Exports: FDROID_STORE_FILE, FDROID_STORE_PASSWORD, FDROID_KEY_ALIAS, FDROID_KEY_PASSWORD

if [[ -z "${1:-}" ]]; then
    echo "Usage: source generate-keystore.sh <keystore_path>" >&2
    return 1 2>/dev/null || exit 1
fi

KEYSTORE_PATH="$1"
FDROID_KEY_ALIAS="status-fdroid"
FDROID_STORE_PASSWORD=$(openssl rand -base64 16)
FDROID_KEY_PASSWORD="$FDROID_STORE_PASSWORD"

mkdir -p "$(dirname "$KEYSTORE_PATH")"
rm -f "$KEYSTORE_PATH"

keytool -genkey -v \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -deststoretype pkcs12 \
    -dname "CN=Status, OU=Mobile, O=Status Research, L=Zug, S=Zug, C=CH" \
    -keystore "$KEYSTORE_PATH" \
    -alias "$FDROID_KEY_ALIAS" \
    -storepass "$FDROID_STORE_PASSWORD" \
    -keypass "$FDROID_KEY_PASSWORD" \
    >&2

export FDROID_STORE_FILE="$KEYSTORE_PATH"
export FDROID_STORE_PASSWORD
export FDROID_KEY_ALIAS
export FDROID_KEY_PASSWORD
