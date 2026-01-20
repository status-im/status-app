#!/usr/bin/env bash
#
# Sign an unsigned APK with zipalign + apksigner.
#
# Called by mobile/scripts/buildApp.sh when Gradle produces an unsigned APK
# (e.g. fdroid builds where signing configs are stripped by fdroid's
# remove_signing_keys).
# See: https://gitlab.com/fdroid/fdroidserver/-/blob/master/fdroidserver/common.py#L3427
#
# Required environment variables:
#   APK_OUT_UNSIGNED   - path to the unsigned APK produced by Gradle
#   APK_OUT            - desired output path for the signed APK
#   ANDROID_HOME       - Android SDK root (for build-tools)
#   FDROID_STORE_FILE  - keystore path
#   FDROID_KEY_ALIAS   - key alias in the keystore
#   FDROID_STORE_PASSWORD - keystore password
#   FDROID_KEY_PASSWORD   - key password
#
set -eou pipefail

ZIPALIGN=$(find "$ANDROID_HOME/build-tools" -name zipalign | sort -V | tail -1)
APKSIGNER=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -1)

if [[ -z "$ZIPALIGN" || -z "$APKSIGNER" ]]; then
    echo "Error: zipalign or apksigner not found in ANDROID_HOME=$ANDROID_HOME" >&2
    exit 1
fi

APK_DIR="$(dirname "$APK_OUT")"
APK_ALIGNED="${APK_DIR}/$(basename "${APK_OUT_UNSIGNED%.apk}")-aligned.apk"

"$ZIPALIGN" -f 4 "$APK_OUT_UNSIGNED" "$APK_ALIGNED"

"$APKSIGNER" sign \
    --ks "$FDROID_STORE_FILE" \
    --ks-key-alias "$FDROID_KEY_ALIAS" \
    --ks-pass "pass:$FDROID_STORE_PASSWORD" \
    --key-pass "pass:$FDROID_KEY_PASSWORD" \
    --out "$APK_OUT" \
    "$APK_ALIGNED"

"$APKSIGNER" verify "$APK_OUT"
echo "APK signed and verified: $APK_OUT"
rm -f "$APK_ALIGNED" "$APK_OUT_UNSIGNED"
