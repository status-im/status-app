#!/usr/bin/env bash
# Host tests for the Android status-go IPC transport (C++ codec + pure-Java helpers).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${IPC_TEST_OUT:-$(mktemp -d)}"
# Not plain clang++: the mobile Makefile puts the NDK toolchain first on PATH.
CXX_HOST="${CXX_HOST:-/usr/bin/c++}"

for src in "$HERE"/*_test.cpp; do
  bin="$OUT/$(basename "${src%.cpp}")"
  "$CXX_HOST" -std=c++17 -Wall -Wextra -Werror -O1 -fsanitize=address,undefined -I"$HERE/.." "$src" -o "$bin"
  "$bin"
done
