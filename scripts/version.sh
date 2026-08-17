#!/usr/bin/env bash
set -e

if [[ -n "${DESKTOP_VERSION_OVERRIDE:-}" ]]; then
  echo "${DESKTOP_VERSION_OVERRIDE}"
  exit 0
fi

git fetch origin --tags --force --no-recurse-submodules
git describe --tags
