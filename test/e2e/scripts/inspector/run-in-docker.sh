#!/bin/bash
# Runs tests of the desktop suite (test/e2e) in the CI image, set up as ci/Jenkinsfile.tests-e2e
# sets up a run: Xvfb, fluxbox, session keyring, local Waku fleet. See README.md.
# usage: APP=<path to AppRun> PLUGINS=<build-plugin.sh output>/plugins run-in-docker.sh <pytest arguments>
set -euo pipefail
: "${APP:?path to the application, e.g. squashfs-root/AppRun of an unpacked Status.AppImage}"
: "${PLUGINS:?directory that holds generic/libqmlinspector.so}"
image="${IMAGE:-status-e2e-tests}"
state="${STATE:-$HOME/.cache/status-e2e}"
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
app_dir=$(cd "$(dirname "$APP")" && pwd)
plugins=$(cd "$PLUGINS" && pwd)
mkdir -p "$state"

# The container runs as the calling user, so the files it writes in the repo are yours.
# dbus refuses to start for a user that has no passwd entry.
docker run --rm --entrypoint "" "$image" cat /etc/passwd > "$state/passwd"
echo "tester:x:$(id -u):$(id -g):tester:/tmp/home:/bin/bash" >> "$state/passwd"

# Set before the start: a start that fails can leave some nodes running.
trap '"$repo/test/e2e/scripts/start-waku-fleet.sh" --stop "$state/waku"' EXIT
"$repo/test/e2e/scripts/start-waku-fleet.sh" "$state/waku"

docker run --rm --network=host --cap-add=SYS_ADMIN --security-opt=apparmor:unconfined \
  --user "$(id -u):$(id -g)" --entrypoint "" \
  -e EXECUTOR_NUMBER -e E2E_LOOKUP_LOG -e WALLET_TEST_USER_SEED -e STATUS_RUNTIME_MESSAGING_BACKEND \
  -v "$state/passwd:/etc/passwd:ro" -v "$state:/state" \
  -v "$repo:/work" -v "$app_dir:/app:ro" -v "$plugins:/plugins:ro" \
  -e AUT_PATH="/app/$(basename "$APP")" \
  "$image" /work/test/e2e/scripts/inspector/in-image.sh "$@"
