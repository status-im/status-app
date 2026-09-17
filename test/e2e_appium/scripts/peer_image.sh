#!/usr/bin/env bash
# Build the status-go image the messaging tests pair a phone with, tagged with
# the pinned commit so an unmoved pin reuses the agent's image, and create
# the network the client attaches it to. Only the tag goes to stdout.
set -euo pipefail

project="${1:?usage: peer_image.sh <docker-project-name>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${root}"

command -v docker >/dev/null || { echo "docker is not on PATH" >&2; exit 1; }

sha="$(scripts/status-go-pin.sh)"
image="statusgo-peer-${sha:0:12}"

# The client that drives the peer lives in status-go's tree, so a checkout is
# needed either way; it goes where core/status_go_tf.py looks for it.
src="$(scripts/status-go-checkout.sh "${WORKSPACE_TMP:-${root}}/.statusgo-src")"

if docker image inspect "${image}" >/dev/null 2>&1; then
  echo "peer image ${image} is already on this agent" >&2
else
  echo "building ${image} from status-go ${sha}" >&2
  docker build "${src}" --tag "${image}" >&2
fi

docker network inspect "${project}_default" >/dev/null 2>&1 \
  || docker network create "${project}_default" >&2

echo "${image}"
