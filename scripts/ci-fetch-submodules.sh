#!/usr/bin/env bash
set -euo pipefail

MOBILE=0
[[ "${1:-}" == "--mobile" ]] && MOBILE=1

git submodule update --init vendor/nimbus-build-system
# Skip fetching the vendored Nim compiler to save time when using system Nim
if [[ "${USE_SYSTEM_NIM:-0}" == "1" ]]; then
  git -C vendor/nimbus-build-system config submodule.vendor/Nim.update none
fi

if [[ "$MOBILE" == "1" ]]; then
  git submodule update --init mobile/vendors/openssl
  # Disable all nested openssl submodules to prevent recursive fetching
  # This avoids pulling in unnecessary dependencies that aren't needed for the build
  git -C mobile/vendors/openssl config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$' \
    | sed -e 's/^submodule\.//' -e 's/\.path$//' \
    | while read -r name; do
        git -C mobile/vendors/openssl config "submodule.${name}.update" none
      done
else
  git config submodule.mobile/vendors/openssl.update none
fi

git submodule update --init --recursive
