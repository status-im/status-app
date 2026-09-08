#!/usr/bin/env bash
# Build the status-go image the messaging tests pair a phone with, tagged with
# the vendored commit so an unmoved pin reuses the agent's image, and create
# the network the client attaches it to. Only the tag goes to stdout.
set -euo pipefail

project="${1:?usage: peer_image.sh <docker-project-name>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${root}"

command -v docker >/dev/null || { echo "docker is not on PATH" >&2; exit 1; }

sha="$(git ls-tree HEAD vendor/status-go | awk '{print $3}')"
if [ -z "${sha}" ]; then
  echo "vendor/status-go is not a submodule of this tree" >&2
  exit 1
fi
image="statusgo-peer-${sha:0:12}"

# The client that drives the peer lives in the submodule, so the checkout is
# needed whether or not the image has to be built; it is fetched only when it
# is absent or at another commit.
if [ "$(git -C vendor/status-go rev-parse HEAD 2>/dev/null)" != "${sha}" ]; then
  git submodule update --init --depth 1 vendor/status-go >&2
fi

if docker image inspect "${image}" >/dev/null 2>&1; then
  echo "peer image ${image} is already on this agent" >&2
else
  echo "building ${image} from status-go ${sha}" >&2
  docker build vendor/status-go --tag "${image}" >&2
fi

docker network inspect "${project}_default" >/dev/null 2>&1 \
  || docker network create "${project}_default" >&2

echo "${image}"
