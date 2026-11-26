#!/bin/bash
# Starts the nodes of docker-compose.waku.yml on Linux or macOS without Docker,
# from the node's release binary, and writes assets/local-waku-fleets-config.json.
# Windows has start-waku-fleet-windows.ps1.
#
#   start-waku-fleet.sh [work dir]          start the nodes
#   start-waku-fleet.sh --stop [work dir]   stop them
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../../.." && pwd)
stop=0
if [ "${1:-}" = --stop ]; then
    stop=1
    shift
fi
work=${1:-${TMPDIR:-/tmp}/status-e2e-waku}
python=${SETUP_PYTHON:-python3}

fail() {
    echo "waku fleet: $1" >&2
    exit 1
}

mkdir -p "$work/node" "$work/logs"
work=$(CDPATH= cd -- "$work" && pwd)
# Nodes left by an earlier run hold the ports until they have exited.
pkill -f "$work/node/" 2> /dev/null || true
for _ in $(seq 50); do
    pgrep -f "$work/node/" > /dev/null || break
    sleep 0.2
done
[ "$stop" = 0 ] || exit 0
# Each start begins with empty stores and one node version.
rm -rf "$work/node" "$work/data"
mkdir -p "$work/node" "$work/data"

# The node loads libpq at run time, whatever store it uses.
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)
        platform=amd64-linux
        ldconfig -p | grep 'libpq\.so\.5' > /dev/null || fail 'install libpq: sudo apt-get install libpq5'
        ;;
    Darwin-arm64)
        platform=arm64-macos
        libpq=$(brew --prefix libpq 2> /dev/null || true)
        [ -n "$libpq" ] && [ -f "$libpq/lib/libpq.dylib" ] || fail 'install libpq: brew install libpq'
        echo "export DYLD_FALLBACK_LIBRARY_PATH='$libpq/lib:/usr/local/lib:/usr/lib'" > "$work/env.sh"
        ;;
    *)
        fail "no node release for $(uname -s) $(uname -m)"
        ;;
esac

"$python" "$here/lib/waku_fleet_scripts.py" "$repo/docker-compose.waku.yml" "$work" \
    --install-dir "$work/node" --log-dir "$work/logs" --data-dir "$work/data" >&2
tag=$(cat "$work/tag.txt")
name=waku-$tag-$platform.tar.gz
sha256=$(awk -v name="$name" '$2 == name { print $1 }' "$here/lib/waku-node.sha256")
[ -n "$sha256" ] || fail "add the checksum of $name to lib/waku-node.sha256"
archive=$work/$name
checksum_ok() {
    [ -f "$archive" ] && echo "$sha256  $archive" | shasum -a 256 -c - > /dev/null 2>&1
}
if ! checksum_ok; then
    curl -sSfL --retry 5 -o "$archive" \
        "https://github.com/logos-messaging/logos-delivery/releases/download/$tag/$name"
    checksum_ok || fail "wrong checksum of $archive"
fi
tar xzf "$archive" -C "$work/node"

while read -r service; do
    [ -n "$service" ] || continue
    nohup bash "$work/$service.sh" > /dev/null 2>&1 &
    echo "waku fleet: started $service" >&2
done < "$work/services.txt"

"$python" "$here/scan_waku_fleet.py" --no-docker --output "$repo/assets/local-waku-fleets-config.json" ||
    fail "the nodes did not come up; see $work/logs"
