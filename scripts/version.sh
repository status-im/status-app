#!/usr/bin/env bash
set -e
git fetch origin --tags --force --no-recurse-submodules
# STATUS_APP_VERSION_COMMIT names the commit to describe when it is not HEAD.
git describe --tags ${STATUS_APP_VERSION_COMMIT:+"$STATUS_APP_VERSION_COMMIT"}
