#!/usr/bin/env bash
# Builds a CI image and names it after its Dockerfile, so a changed Dockerfile
# gets a new tag and an unchanged one is found in the registry.
#
#   ci/build-image.sh <desktop|android>          build the image
#   ci/build-image.sh --image <desktop|android>  print its reference
#   ci/build-image.sh --check <desktop|android>  run the tools the builds need in it
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

action=build
case "${1:-}" in
  --image) action=image; shift ;;
  --check) action=check; shift ;;
esac

case "${1:-}" in
  desktop) dockerfile=ci/Dockerfile ;;
  android) dockerfile=mobile/docker/Dockerfile ;;
  *)
    echo "usage: $0 [--image|--check] <desktop|android>" >&2
    exit 2
    ;;
esac
name="$1"

tag="$(git -C "$repo" hash-object "$dockerfile" | cut -c1-12)"
image="${STATUS_APP_BUILD_REGISTRY:-ghcr.io/status-im}/status-app-build:$name-$tag"

case "$action" in
  image)
    echo "$image"
    ;;
  build)
    docker build --platform linux/amd64 --tag "$image" \
      --label "org.opencontainers.image.source=https://github.com/status-im/status-app" \
      --file "$repo/$dockerfile" "$(dirname "$repo/$dockerfile")"
    ;;
  check)
    tools='qmake --version && cmake --version && nim --version && nimble --version && go version && protoc --version'
    if [ "$name" = android ]; then
      tools="$tools && java -version && test -d \"\$ANDROID_NDK_ROOT\" && test -f \"\$OPENSSL_LIB_DIR/libssl.a\""
    fi
    docker run --rm --platform linux/amd64 --entrypoint "" "$image" bash -c "$tools"
    ;;
esac
