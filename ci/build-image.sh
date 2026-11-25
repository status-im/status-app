#!/usr/bin/env bash
# Builds a CI image and names it after its Dockerfile, so a changed Dockerfile
# gets a new tag and an unchanged one is found in the registry.
#
#   ci/build-image.sh <desktop|android|tests>          build the image
#   ci/build-image.sh --pull <desktop|android|tests>   pull it, or build it when the pull fails
#   ci/build-image.sh --image <desktop|android|tests>  print its reference
#   ci/build-image.sh --check <desktop|android|tests>  run the tools its jobs need in it
#
# tests is the image of the desktop e2e suite, built on the desktop image.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

action=build
case "${1:-}" in
  --image) action=image; shift ;;
  --pull) action=pull; shift ;;
  --check) action=check; shift ;;
esac

case "${1:-}" in
  desktop) dockerfile=ci/Dockerfile ;;
  android) dockerfile=mobile/docker/Dockerfile ;;
  tests) dockerfile=ci/tests.Dockerfile ;;
  *)
    echo "usage: $0 [--image|--pull|--check] <desktop|android|tests>" >&2
    exit 2
    ;;
esac
name="$1"

tag="$(git -C "$repo" hash-object "$dockerfile" | cut -c1-12)"
base_arg=()
if [ "$name" = tests ]; then
  # A changed desktop image changes this one too.
  base="$("$0" --image desktop)"
  tag="$(echo "$tag $base" | git hash-object --stdin | cut -c1-12)"
  base_arg=(--build-arg "BASE=$base")
fi
image="ghcr.io/status-im/status-app-build:$name-$tag"

case "$action" in
  image)
    echo "$image"
    ;;
  pull)
    if ! docker pull --quiet "$image"; then
      echo "::warning::$image cannot be pulled, building it here" >&2
      [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || echo "The \`$name\` image was built in this job: \`$image\` could not be pulled." >> "$GITHUB_STEP_SUMMARY"
      "$0" "$name"
    fi
    ;;
  build)
    [ "$name" != tests ] || "$0" --pull desktop
    docker build --platform linux/amd64 --tag "$image" ${base_arg[@]+"${base_arg[@]}"} \
      --label "org.opencontainers.image.source=https://github.com/status-im/status-app" \
      --file "$repo/$dockerfile" "$(dirname "$repo/$dockerfile")"
    ;;
  check)
    tools='qmake --version && cmake --version && nimble --version && go version && protoc --version && ccache --version'
    if [ "$name" = android ]; then
      # Gradle takes Java from JAVA_HOME, which is not the java on PATH.
      tools="$tools && \"\$JAVA_HOME/bin/java\" -version && test -d \"\$ANDROID_NDK_ROOT\""
    fi
    if [ "$name" = tests ]; then
      tools='command -v Xvfb fluxbox gnome-keyring-daemon && python3 --version && node --version'
    fi
    docker run --rm --platform linux/amd64 --entrypoint "" "$image" bash -c "$tools"
    ;;
esac
