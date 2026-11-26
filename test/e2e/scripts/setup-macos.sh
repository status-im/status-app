#!/bin/bash
export SETUP_PLATFORM=macos
exec "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/lib/setup-unix.sh" "$@"