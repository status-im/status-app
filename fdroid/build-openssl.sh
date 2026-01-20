#!/usr/bin/env bash
#
# Build OpenSSL for Qt Android build
# This builds OpenSSL as a dependency for Qt compilation
# (separate from mobile/scripts/buildOpenSSL.sh which builds for the app)
#
set -eo pipefail

cd "$OPENSSL_SRCDIR"

if [[ -z "$ANDROID_NDK_ROOT" ]]; then
    echo "Error: ANDROID_NDK_ROOT is not set" >&2
    exit 1
fi

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin:$PATH"

ANDROID_API="${ANDROID_API:-28}"

./Configure android-arm64 -D__ANDROID_API__="$ANDROID_API" \
    --prefix="$HOME/openssl" \
    --openssldir="$HOME/openssl" \
    no-shared no-tests

make -j"$(nproc)" 2>&1 | tail -100
make install_sw > /dev/null
