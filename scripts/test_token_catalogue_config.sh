#!/usr/bin/env bash
# Called by make tests-nim-token-catalogue after compiling with the Qt toolchain.
set -euo pipefail
binary="${1:?Supply the compiled runtime configuration test}"
# Set these inside the runner: macOS can strip DYLD_* when invoking /bin/sh.
export DYLD_LIBRARY_PATH="${TKL_TEST_LIBRARY_PATH:-}:${DYLD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="${TKL_TEST_LIBRARY_PATH:-}:${LD_LIBRARY_PATH:-}"
unset STATUS_RUNTIME_TOKEN_LISTS_USE_NIM STATUS_RUNTIME_TOKEN_LISTS_SHADOW
unset TKL_TEST_EXPECT_NIM TKL_TEST_EXPECT_SHADOW

echo "Checking default catalogue configuration"
"$binary"
echo "Checking environment opt-in"
STATUS_RUNTIME_TOKEN_LISTS_USE_NIM=true STATUS_RUNTIME_TOKEN_LISTS_SHADOW=true \
  TKL_TEST_EXPECT_NIM=true TKL_TEST_EXPECT_SHADOW=true "$binary"
echo "Checking command-line opt-in"
TKL_TEST_EXPECT_NIM=true TKL_TEST_EXPECT_SHADOW=true \
  "$binary" --token-lists-use-nim=true --token-lists-shadow=true
echo "Checking explicit rollback overrides enabled environment options"
STATUS_RUNTIME_TOKEN_LISTS_USE_NIM=true STATUS_RUNTIME_TOKEN_LISTS_SHADOW=true \
  "$binary" --token-lists-use-nim=false --token-lists-shadow=false
