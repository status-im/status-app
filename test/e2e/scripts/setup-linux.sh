#!/bin/bash
export SETUP_PLATFORM=linux
exec "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/lib/setup-unix.sh" "$@"