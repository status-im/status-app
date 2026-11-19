#!/bin/bash
# Runs tests of the desktop suite (test/e2e) on the Squish stand-in, inside the CI image,
# set up as ci/Jenkinsfile.tests-e2e sets up a Squish run: Xvfb, fluxbox, session keyring,
# local Waku fleet. See README.md.
# usage: APP=<path to AppRun> PLUGINS=<build-plugin.sh output>/plugins run.sh <pytest arguments>
set -euo pipefail
: "${APP:?path to the application, e.g. squashfs-root/AppRun of an unpacked Status.AppImage}"
: "${PLUGINS:?directory that holds generic/libqmlinspector.so}"
image="${IMAGE:-status-e2e-squish-stand-in}"
state="${STATE:-$HOME/.cache/status-e2e-squish-stand-in}"
fleet="${FLEET_PROJECT:-e2e-stand-in-fleet}"
repo=$(cd "$(dirname "$0")/../.." && pwd)
app_dir=$(cd "$(dirname "$APP")" && pwd)
plugins=$(cd "$PLUGINS" && pwd)
mkdir -p "$state"

# The container runs as the calling user, so the files it writes in the repo are yours.
# dbus refuses to start for a user that has no passwd entry.
docker run --rm --entrypoint "" "$image" cat /etc/passwd > "$state/passwd"
echo "tester:x:$(id -u):$(id -g):tester:/tmp/home:/bin/bash" >> "$state/passwd"

docker compose -p "$fleet" -f "$repo/docker-compose.waku.yml" up -d
trap 'docker compose -p "$fleet" -f "$repo/docker-compose.waku.yml" down --remove-orphans' EXIT
(cd "$repo" && python3 test/e2e/scripts/scan_waku_fleet.py --project "$fleet")

docker run --rm --network=host --cap-add=SYS_ADMIN --security-opt=apparmor:unconfined \
  --user "$(id -u):$(id -g)" --entrypoint "" \
  -e EXECUTOR_NUMBER -e SQUISH_STAND_IN_LOOKUP_LOG \
  -v "$state/passwd:/etc/passwd:ro" -v "$state:/state" \
  -v "$repo:/work" -v "$app_dir:/app:ro" -v "$plugins:/plugins:ro" \
  -e AUT_PATH="/app/$(basename "$APP")" \
  "$image" /work/test/e2e_squish_stand_in/docker/in-image.sh "$@"
